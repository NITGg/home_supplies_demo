import 'dart:async'; // ✅ Fix #6: real unawaited from dart:async

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
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
  // ✅ Start in CartLoading so the skeleton renders immediately on first
  // build — before fetchCart() is even called. This eliminates the
  // CartInitial → CartLoading flash that caused a double skeleton render.
        super(const CartLoading());

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _safeEmit(CartState state) {
    if (isClosed) return;
    emit(state);
  }

  CartLoaded? get _loaded => state is CartLoaded ? state as CartLoaded : null;

  // ── Fetch ────────────────────────────────────────────────────────────────

  /// Resets the cubit to [CartLoading] synchronously.
  ///
  /// Call this at the top of [initState] (before the first frame) so the
  /// screen never renders stale cached data when navigating back to the cart.
  void reset() => _safeEmit(const CartLoading());

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

  /// Public silent refresh — skips the loading flash.
  /// Use this for all background refreshes (coupon, address change, post-order).
  Future<void> refreshCart() => _silentRefresh();

  /// Refreshes cart data in the background without a loading flash.
  Future<void> _silentRefresh({bool refetchPreview = true}) async {
    try {
      final data = await _repository.getCart();
      final currentPreview = _loaded?.preview;
      _safeEmit(CartLoaded(_enrichSummary(data), preview: currentPreview));
      if (refetchPreview && data.cartItems.isNotEmpty) {
        unawaited(_fetchPreviewSilently());
      }
    } catch (e) {
      dLog('[CartCubit] silentRefresh error: $e');
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
    // Mark the item as busy before the network call
    final loaded = _loaded;
    if (loaded != null) {
      _safeEmit(loaded.copyWith(busyItemIds: {...loaded.busyItemIds, spId}));
    }

    try {
      final item = await _repository.addItem(spId: spId, quantity: quantity);

      if (_loaded != null) {
        // Clear busy flag, then apply the add
        final current = _loaded!;
        final busy = Set<int>.from(current.busyItemIds)..remove(spId);
        _safeEmit(current.copyWith(busyItemIds: busy));

        _applyItemAdd(item);
        unawaited(_silentRefresh());
      } else {
        await fetchCart();
      }
    } on MultipleSupplierException {
      // Clear busy flag before rethrowing
      final current = _loaded;
      if (current != null) {
        final busy = Set<int>.from(current.busyItemIds)..remove(spId);
        _safeEmit(current.copyWith(busyItemIds: busy));
      }
      rethrow;
    } catch (e) {
      dLog('[CartCubit] addItem error: $e');
      final current = _loaded;
      if (current != null) {
        // ✅ Fix #7: clear busy flag and rethrow — clearly structured
        final busy = Set<int>.from(current.busyItemIds)..remove(spId);
        _safeEmit(current.copyWith(busyItemIds: busy));
        rethrow;
      }
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
      dLog('[CartCubit] fetchPreview error: $e');
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
      dLog('[CartCubit] clearAndAddItem error: $e');
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
      refetchPreview: false,
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
        dLog('[CartCubit] decrementItem(remove) error: $e');
        await fetchCart();
        rethrow;
      }
    } else {
      await _updateItem(
        cartItemId: spId,
        action: CartUpdateAction.decrement,
        quantity: 1,
        refetchPreview: false,
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
      dLog('[CartCubit] removeItem error: $e');
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
      // ✅ Fix #9: removed the unconditional CartError emit after fetchCart —
      // if _silentRefresh succeeds the loaded state is already emitted;
      // if it fails _silentRefresh logs and keeps last state.
    } catch (e) {
      dLog('[CartCubit] clearCart error: $e');
      // Refetch to restore accurate server state, then surface the error.
      await fetchCart();
      // Only emit error if we're still in a non-loaded state after refetch.
      if (_loaded == null) {
        _safeEmit(CartError(extractErrorMessage(e)));
      }
    }
  }

  // ── Private: generic update ───────────────────────────────────────────────

  Future<void> _updateItem({
    required int cartItemId,
    required CartUpdateAction action,
    required int quantity,
    bool refetchPreview = true,
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
        unawaited(_silentRefresh(refetchPreview: refetchPreview));
      } else {
        _applyItemUpdate(updated);
        if (refetchPreview) unawaited(_silentRefresh(refetchPreview: true));
      }
    } catch (e) {
      dLog('[CartCubit] _updateItem error: $e');
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

// ✅ Fix #6: removed the local no-op unawaited stub.
// dart:async's unawaited() is now imported at the top of the file.