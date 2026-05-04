import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/extract_error_message.dart';
import '../data/data_source/cart_remote_data_source.dart';
import '../data/models/cart_item_model.dart';
import '../data/models/cart_response_model.dart';
import '../data/models/cart_summary_model.dart';
import '../data/models/multiple_supplier_exception.dart';
import '../data/repo/cart_repo.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  final CartRepository _repository;

  CartCubit({CartRepository? repository})
      : _repository = repository ?? CartRepositoryImpl(),
        super(const CartInitial());

  // ── Helpers ───────────────────────────────────────────────────────────────

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
      _safeEmit(CartLoaded(_enrichSummary(data)));
      if (data.cartItems.isNotEmpty) {
        unawaited(_fetchPreviewSilently()); // coupon unknown at fetch time
      }
    } catch (e) {
      _safeEmit(CartError(extractErrorMessage(e)));
    }
  }

  /// Refreshes cart data in the background without a loading flash.
  Future<void> _silentRefresh() async {
    try {
      final data = await _repository.getCart();
      final currentPreview = _loaded?.preview; // ← preserve so UI doesn't flicker
      _safeEmit(CartLoaded(_enrichSummary(data), preview: currentPreview));
      if (data.cartItems.isNotEmpty) {
        unawaited(_fetchPreviewSilently()); // ← re-fetch fees after every mutation
      }
    } catch (e) {
      log('[CartCubit] silentRefresh error: $e');
    }
  }

  /// Replaces the server-provided summary with one computed from the items.
  CartResponseModel _enrichSummary(CartResponseModel data) {
    return data.copyWith(summary: _computeSummary(data.cartItems));
  }

  // ── Add item ─────────────────────────────────────────────────────────────

  /// Adds an item to the cart.
  ///
  /// Throws [MultipleSupplierException] if the backend rejects the request
  /// due to a supplier conflict — callers are expected to catch this and
  /// show the resolution dialog.
  Future<void> addItem({required int spId, required int quantity}) async {
    try {
      final item = await _repository.addItem(spId: spId, quantity: quantity);

      if (_loaded != null) {
        _applyItemAdd(item);
        unawaited(_silentRefresh());
      } else {
        await fetchCart();
      }
    } on MultipleSupplierException {
      // Let the UI handle the supplier-conflict dialog — don't swallow it.
      rethrow;
    } catch (e) {
      log('[CartCubit] addItem error: $e');
      if (_loaded != null) rethrow;
      _safeEmit(CartError(extractErrorMessage(e)));
    }
  }

  Future<void> _fetchPreviewSilently({String? couponCode}) async {
    try {
      final preview = await _repository.getOrderPreview(couponCode: couponCode);
      final loaded = _loaded;
      if (loaded != null) {
        _safeEmit(loaded.copyWith(preview: preview));
      }
    } catch (e) {
      log('[CartCubit] fetchPreview error: $e');
      // non-fatal — summary still shows product totals
    }
  }

  /// Re-fetches the order preview with an optional coupon code.
  /// Call this whenever a coupon is applied or removed so that
  /// [preview.discountAmount] reflects the server-computed (cap-aware) value.
  Future<void> refreshPreview({String? couponCode}) async {
    if (_loaded == null) return;
    unawaited(_fetchPreviewSilently(couponCode: couponCode));
  }

  /// Clears the current cart and immediately adds [spId] with [quantity].
  ///
  /// Used by the supplier-conflict dialog's "Clear & add" action.
  /// Emits an optimistic empty-cart state before the network calls so the
  /// UI feels instant.
  Future<void> clearAndAddItem({
    required int spId,
    required int quantity,
  }) async {
    final loaded = _loaded;

    // Optimistically wipe the cart so the UI updates immediately.
    if (loaded != null) {
      _safeEmit(CartLoaded(CartResponseModel(
        cart: loaded.data.cart,
        cartItems: const [],
        summary: const CartSummaryModel(
          itemCount: 0,
          totalItems: 0,
          originalTotal: 0,
          totalDiscount: 0,
          subtotal: 0,
        ),
      )));
    }

    try {
      await _repository.clearCart();
      await addItem(spId: spId, quantity: quantity);
    } catch (e) {
      log('[CartCubit] clearAndAddItem error: $e');
      // Restore cart state from server if anything fails.
      await fetchCart();
      rethrow;
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
        await fetchCart();
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
      await fetchCart();
      rethrow;
    }
  }

  // ── Clear cart ───────────────────────────────────────────────────────────

  Future<void> clearCart() async {
    final loaded = _loaded;
    if (loaded == null) return;

    _safeEmit(CartLoaded(CartResponseModel(
      cart: loaded.data.cart,
      cartItems: const [],
      summary: const CartSummaryModel(
        itemCount: 0,
        totalItems: 0,
        originalTotal: 0,
        totalDiscount: 0,
        subtotal: 0,
      ),
    )));

    try {
      await _repository.clearCart();
      await _silentRefresh();
    } catch (e) {
      log('[CartCubit] clearCart error: $e');
      await fetchCart();
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
      final current = _loaded;
      if (current != null) {
        final busy = Set<int>.from(current.busyItemIds)..remove(cartItemId);
        _safeEmit(current.copyWith(busyItemIds: busy));
      }
      rethrow;
    }
  }

  // ── Private: state mutations ──────────────────────────────────────────────

  void _applyItemAdd(CartItemModel newItem) {
    final loaded = _loaded;
    if (loaded == null) return;

    final exists = loaded.data.cartItems.any((i) => i.spId == newItem.spId);
    final items = exists
        ? loaded.data.cartItems
        .map((i) => i.spId == newItem.spId ? newItem : i)
        .toList()
        : [...loaded.data.cartItems, newItem];

    _safeEmit(loaded.copyWith(
      data: loaded.data.copyWith(
        cartItems: items,
        summary: _computeSummary(items),
      ),
    ));
  }

  void _applyItemUpdate(CartItemModel updated) {
    final loaded = _loaded;
    if (loaded == null) return;

    final items = loaded.data.cartItems
        .map((i) => i.spId == updated.spId ? updated : i)
        .toList();

    final busy = Set<int>.from(loaded.busyItemIds)..remove(updated.spId);
    _safeEmit(loaded.copyWith(
      data: loaded.data.copyWith(
        cartItems: items,
        summary: _computeSummary(items),
      ),
      busyItemIds: busy,
    ));
  }

  void _applyOptimisticRemove(int spId) {
    final loaded = _loaded;
    if (loaded == null) return;

    final items = loaded.data.cartItems.where((i) => i.spId != spId).toList();

    _safeEmit(loaded.copyWith(
      data: loaded.data.copyWith(
        cartItems: items,
        summary: _computeSummary(items),
      ),
    ));
  }

  // ── Summary computation ───────────────────────────────────────────────────

  CartSummaryModel _computeSummary(List<CartItemModel> items) {
    final originalTotal =
    items.fold(0.0, (sum, i) => sum + i.originalLineTotal);
    final subtotal = items.fold(0.0, (sum, i) => sum + i.lineTotal);

    return CartSummaryModel(
      itemCount: items.length,
      totalItems: items.fold(0, (sum, i) => sum + i.quantity),
      originalTotal: originalTotal,
      totalDiscount: originalTotal - subtotal,
      subtotal: subtotal,
    );
  }
}

/// Discards a Future without lint warnings.
void unawaited(Future<void> future) {}