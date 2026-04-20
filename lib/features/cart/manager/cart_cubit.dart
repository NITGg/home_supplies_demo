import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/extract_error_message.dart';
import '../data/data_source/cart_remote_data_source.dart';
import '../data/models/cart_item_model.dart';
import '../data/models/cart_response_model.dart';
import '../data/models/cart_summary_model.dart';
import '../data/repo/cart_repo.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  final CartRepository _repository;

  CartCubit({CartRepository? repository})
      : _repository = repository ?? CartRepositoryImpl(),
        super(const CartInitial());

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Emits safely, skipping if the cubit has already been closed.
  void _safeEmit(CartState state) {
    if (isClosed) return;
    emit(state);
  }

  CartLoaded? get _loaded => state is CartLoaded ? state as CartLoaded : null;

  // ── Fetch ────────────────────────────────────────────────────────────────

  Future<void> fetchCart() async {
    _safeEmit(const CartLoading());
    try {
      final data = await _repository.getCart();
      _safeEmit(CartLoaded(data));
    } catch (e) {
      _safeEmit(CartError(extractErrorMessage(e)));
    }
  }

  /// Refreshes cart data in the background without emitting [CartLoading],
  /// preserving the current visible state during network round-trips.
  Future<void> _silentRefresh() async {
    try {
      final data = await _repository.getCart();
      _safeEmit(CartLoaded(data));
    } catch (e) {
      log('[CartCubit] silentRefresh error: $e');
      // Silent failure – the optimistic state remains until user manually refreshes.
    }
  }

  // ── Add item ─────────────────────────────────────────────────────────────

  /// Adds an item and optimistically updates the UI so there is no full-page
  /// loading flash. Falls back to [fetchCart] if the state is not yet loaded.
  Future<void> addItem({required int spId, required int quantity}) async {
    try {
      final item = await _repository.addItem(spId: spId, quantity: quantity);

      if (_loaded != null) {
        // Optimistic: merge the returned item into the current cart snapshot.
        _applyItemAdd(item);
        // Background reconcile – server is the source of truth for totals.
        unawaited(_silentRefresh());
      } else {
        // Cart was never loaded – bootstrap from server.
        await fetchCart();
      }
    } catch (e) {
      log('[CartCubit] addItem error: $e');
      if (_loaded != null) {
        rethrow; // Caller will surface a SnackBar; keep loaded state intact.
      }
      _safeEmit(CartError(extractErrorMessage(e)));
    }
  }

  // ── Increment ────────────────────────────────────────────────────────────

  Future<void> incrementItem(int spId) async {
    await _updateItem(
      cartItemId: spId,
      action: CartUpdateAction.increment,
      quantity: 1,
    );
  }

  // ── Decrement / remove ───────────────────────────────────────────────────

  Future<void> decrementItem(int spId) async {
    final loaded = _loaded;
    if (loaded == null) return;

    final CartItemModel? item =
        loaded.data.cartItems.where((i) => i.spId == spId).firstOrNull;
    if (item == null) return;

    if (item.quantity <= 1) {
      // Last unit – remove immediately in the UI, then reconcile with server.
      _applyOptimisticRemove(spId);
      try {
        await _repository.updateItem(
          cartItemId: spId,
          action: CartUpdateAction.decrement,
          quantity: 1,
        );
        await _silentRefresh();
      } catch (e) {
        log('[CartCubit] decrementItem(remove) error: $e');
        await fetchCart(); // rollback via full refresh
        rethrow;
      }
    } else {
      await _updateItem(
        cartItemId: spId,
        action: CartUpdateAction.decrement,
        quantity: 1,
      );
    }
  }

  // ── Set quantity ─────────────────────────────────────────────────────────

  Future<void> setItemQuantity(int spId, int quantity) async {
    await _updateItem(
      cartItemId: spId,
      action: CartUpdateAction.set,
      quantity: quantity,
    );
  }

  // ── Remove item ──────────────────────────────────────────────────────────

  Future<void> removeItem(int spId) async {
    _applyOptimisticRemove(spId);
    try {
      await _repository.updateItem(
        cartItemId: spId,
        action: CartUpdateAction.set,
        quantity: 0,
      );
      await _silentRefresh();
    } catch (e) {
      log('[CartCubit] removeItem error: $e');
      await fetchCart(); // rollback
      rethrow;
    }
  }

  // ── Clear cart ───────────────────────────────────────────────────────────

  Future<void> clearCart() async {
    final loaded = _loaded;
    if (loaded == null) return;

    // Optimistic: show empty cart immediately.
    final emptyResponse = CartResponseModel(
      cart: loaded.data.cart,
      cartItems: const [],
      summary: const CartSummaryModel(
        itemCount: 0,
        totalItems: 0,
        totalPrice: 0,
      ),
    );
    _safeEmit(CartLoaded(emptyResponse));

    try {
      await _repository.clearCart();
      // Confirm with server to keep IDs / totals accurate.
      await _silentRefresh();
    } catch (e) {
      log('[CartCubit] clearCart error: $e');
      await fetchCart(); // rollback to real state
      _safeEmit(CartError(extractErrorMessage(e)));
    }
  }

  // ── Private: generic update ───────────────────────────────────────────────

  Future<void> _updateItem({
    required int cartItemId,
    required CartUpdateAction action,
    required int quantity,
  }) async {
    final loaded = _loaded;
    if (loaded == null) return;

    // Mark item as busy so its tile shows a spinner.
    _safeEmit(
      loaded.copyWith(busyItemIds: {...loaded.busyItemIds, cartItemId}),
    );

    try {
      final updated = await _repository.updateItem(
        cartItemId: cartItemId,
        action: action,
        quantity: quantity,
      );

      if (updated == null) {
        _applyOptimisticRemove(cartItemId);
      } else {
        _applyItemUpdate(updated);
      }
    } catch (e) {
      log('[CartCubit] _updateItem error: $e');
      // Unmark busy, keep rest of state intact.
      final current = _loaded;
      if (current != null) {
        final busy = Set<int>.from(current.busyItemIds)..remove(cartItemId);
        _safeEmit(current.copyWith(busyItemIds: busy));
      }
      rethrow;
    }
  }

  // ── Private: state mutations ──────────────────────────────────────────────

  /// Merges [newItem] into the cart – updates if already present, appends otherwise.
  void _applyItemAdd(CartItemModel newItem) {
    final loaded = _loaded;
    if (loaded == null) return;

    final exists = loaded.data.cartItems.any((i) => i.spId == newItem.spId);
    final items = exists
        ? loaded.data.cartItems
        .map((i) => i.spId == newItem.spId ? newItem : i)
        .toList()
        : [...loaded.data.cartItems, newItem];

    _safeEmit(
      loaded.copyWith(
        data: loaded.data.copyWith(
          cartItems: items,
          summary: _computeSummary(items),
        ),
      ),
    );
  }

  void _applyItemUpdate(CartItemModel updated) {
    final loaded = _loaded;
    if (loaded == null) return;

    final items = loaded.data.cartItems
        .map((i) => i.spId == updated.spId ? updated : i)
        .toList();

    final busy = Set<int>.from(loaded.busyItemIds)..remove(updated.spId);
    _safeEmit(
      loaded.copyWith(
        data: loaded.data.copyWith(
          cartItems: items,
          summary: _computeSummary(items),
        ),
        busyItemIds: busy,
      ),
    );
  }

  void _applyOptimisticRemove(int spId) {
    final loaded = _loaded;
    if (loaded == null) return;

    final items =
    loaded.data.cartItems.where((i) => i.spId != spId).toList();

    _safeEmit(
      loaded.copyWith(
        data: loaded.data.copyWith(
          cartItems: items,
          summary: _computeSummary(items),
        ),
      ),
    );
  }

  CartSummaryModel _computeSummary(List<CartItemModel> items) {
    return CartSummaryModel(
      itemCount: items.length,
      totalItems: items.fold(0, (sum, i) => sum + i.quantity),
      totalPrice: items.fold(0.0, (sum, i) => sum + i.lineTotal),
    );
  }
}

/// Discards the Future from [_silentRefresh] without lint warnings.
void unawaited(Future<void> future) {}