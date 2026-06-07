import 'dart:async';

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

// ── Pending sync entry ────────────────────────────────────────────────────────

class _PendingSync {
  int targetQuantity;
  Timer debounce;

  _PendingSync({required this.targetQuantity, required this.debounce});
}

// ── CartCubit ─────────────────────────────────────────────────────────────────

class CartCubit extends Cubit<CartState> {
  final CartRepository _repository;

  static const _kDebounce = Duration(milliseconds: 600);

  final Map<int, _PendingSync> _pending = {};

  // Quantities currently being synced to the server (debounce fired but the
  // network call hasn't completed yet).  _silentRefresh must respect these
  // exactly like pending debounce entries so it doesn't overwrite in-flight
  // optimistic state.
  final Map<int, int> _inFlightQty = {};

  CartCubit({CartRepository? repository})
      : _repository = repository ?? CartRepositoryImpl(),
        super(const CartLoading());

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _safeEmit(CartState state) {
    if (isClosed) return;
    emit(state);
  }

  CartLoaded? get _loaded => state is CartLoaded ? state as CartLoaded : null;

  // ── Fetch ─────────────────────────────────────────────────────────────────

  void reset() {
    for (final p in _pending.values) {
      p.debounce.cancel();
    }
    _pending.clear();
    _inFlightQty.clear();
    _safeEmit(const CartLoading());
  }

  Future<void> fetchCart() async {
    _safeEmit(const CartLoading());
    try {
      final data = await _repository.getCart();
      _safeEmit(CartLoaded(_enrichSummary(data)));
      if (data.cartItems.isNotEmpty) {
        unawaited(_fetchPreviewSilently());
      }
    } catch (e) {
      _safeEmit(CartError(extractErrorMessage(e)));
    }
  }

  Future<void> refreshCart() => _silentRefresh();

  /// Full cart refresh from server — only used for address changes,
  /// post-order cleanup, and coupon application. Never called after
  /// an optimistic remove (that would re-insert the deleted item).
  Future<void> _silentRefresh({bool refetchPreview = true}) async {
    try {
      final data = await _repository.getCart();
      final currentPreview = _loaded?.preview;
      // Preserve any optimistic quantities that are still pending (debounce not
      // yet fired) OR in-flight (debounce fired, network call not yet complete).
      // Without this, a concurrent refresh overwrites the optimistic value and
      // causes a visible flicker back to the server's stale quantity.
      final mergedItems = data.cartItems.map((item) {
        final pendingQty = _pending[item.spId]?.targetQuantity ?? _inFlightQty[item.spId];
        return pendingQty != null ? item.copyWithQuantity(pendingQty) : item;
      }).toList();
      final merged = data.copyWith(cartItems: mergedItems);
      _safeEmit(CartLoaded(_enrichSummary(merged), preview: currentPreview));
      if (refetchPreview && merged.cartItems.isNotEmpty) {
        unawaited(_fetchPreviewSilently());
      }
    } catch (e) {
      dLog('[CartCubit] silentRefresh error: $e');
    }
  }

  CartResponseModel _enrichSummary(CartResponseModel data) =>
      data.copyWith(summary: _computeSummary(data.cartItems));

  // ── Add item ──────────────────────────────────────────────────────────────

  Future<void> addItem({required int spId, required int quantity}) async {
    final loaded = _loaded;
    if (loaded != null) {
      _safeEmit(loaded.copyWith(busyItemIds: {...loaded.busyItemIds, spId}));
    }

    try {
      final item = await _repository.addItem(spId: spId, quantity: quantity);
      if (_loaded != null) {
        final current = _loaded!;
        final busy = Set<int>.from(current.busyItemIds)..remove(spId);
        _safeEmit(current.copyWith(busyItemIds: busy));
        _applyItemAdd(item);
        unawaited(_fetchPreviewSilently());
      } else {
        await fetchCart();
      }
    } on MultipleSupplierException {
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
        final busy = Set<int>.from(current.busyItemIds)..remove(spId);
        _safeEmit(current.copyWith(busyItemIds: busy));
        rethrow;
      }
      _safeEmit(CartError(extractErrorMessage(e)));
    }
  }

  // ── Optimistic increment (debounced) ──────────────────────────────────────

  Future<void> incrementItem(int spId) async {
    final loaded = _loaded;
    if (loaded == null) return;

    final item =
        loaded.data.cartItems.where((i) => i.spId == spId).firstOrNull;
    if (item == null) return;

    final currentQty = _pending[spId]?.targetQuantity ?? item.quantity;
    final newQty = currentQty + 1;

    final maxQty = item.product.maxAmountForOneOrder;
    if (maxQty != null && newQty > maxQty) return;

    _applyOptimisticQuantity(spId, newQty);
    _scheduleSync(spId, newQty);
  }

  // ── Optimistic decrement (debounced) ──────────────────────────────────────

  Future<void> decrementItem(int spId) async {
    final loaded = _loaded;
    if (loaded == null) return;

    final item =
        loaded.data.cartItems.where((i) => i.spId == spId).firstOrNull;
    if (item == null) return;

    final currentQty = _pending[spId]?.targetQuantity ?? item.quantity;
    final newQty = currentQty - 1;

    if (newQty <= 0) {
      _cancelPending(spId);
      await removeItem(spId);
    } else {
      _applyOptimisticQuantity(spId, newQty);
      _scheduleSync(spId, newQty);
    }
  }

  // ── Set quantity ──────────────────────────────────────────────────────────

  Future<void> setItemQuantity(int spId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(spId);
      return;
    }
    _applyOptimisticQuantity(spId, quantity);
    _scheduleSync(spId, quantity);
  }

  // ── Remove item ───────────────────────────────────────────────────────────

  Future<void> removeItem(int spId) async {
    // Cancel any pending debounced sync for this item first.
    _cancelPending(spId);

    // Remove from local state immediately — this is the only state change.
    // We deliberately do NOT call _silentRefresh after success because the
    // server may return the item at qty 0 before its own cleanup finishes,
    // which would re-insert it into the UI.
    _applyOptimisticRemove(spId);

    try {
      await _repository.updateItem(
        cartItemId: spId,
        action: CartUpdateAction.set,
        quantity: 0,
      );
      // Only refresh the delivery/fee preview — not the item list.
      unawaited(_fetchPreviewSilently());
    } catch (e) {
      dLog('[CartCubit] removeItem error: $e');
      // Server rejected the remove — restore truth from server.
      await fetchCart();
      rethrow;
    }
  }

  // ── Clear cart ────────────────────────────────────────────────────────────

  Future<void> clearCart() async {
    final loaded = _loaded;
    if (loaded == null) return;

    for (final p in _pending.values) {
      p.debounce.cancel();
    }
    _pending.clear();

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
    } catch (e) {
      dLog('[CartCubit] clearCart error: $e');
      await fetchCart();
      if (_loaded == null) {
        _safeEmit(CartError(extractErrorMessage(e)));
      }
    }
  }

  // ── Clear & add (supplier conflict) ──────────────────────────────────────

  Future<void> clearAndAddItem({
    required int spId,
    required int quantity,
  }) async {
    final loaded = _loaded;

    for (final p in _pending.values) {
      p.debounce.cancel();
    }
    _pending.clear();

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
      await fetchCart();
      rethrow;
    }
  }

  // ── Preview ───────────────────────────────────────────────────────────────

  Future<void> _fetchPreviewSilently({String? couponCode}) async {
    try {
      final preview =
      await _repository.getOrderPreview(couponCode: couponCode);
      final loaded = _loaded;
      if (loaded != null) {
        _safeEmit(loaded.copyWith(preview: preview));
      }
    } catch (e) {
      dLog('[CartCubit] fetchPreview error: $e');
    }
  }

  Future<void> refreshPreview({String? couponCode}) async {
    if (_loaded == null) return;
    unawaited(_fetchPreviewSilently(couponCode: couponCode));
  }

  // ── Debounce / sync helpers ───────────────────────────────────────────────

  void _scheduleSync(int spId, int targetQty) {
    _pending[spId]?.debounce.cancel();
    final timer = Timer(_kDebounce, () => _flushSync(spId));
    _pending[spId] = _PendingSync(targetQuantity: targetQty, debounce: timer);
  }

  Future<void> _flushSync(int spId) async {
    final entry = _pending.remove(spId);
    if (entry == null) return;

    final targetQty = entry.targetQuantity;
    dLog('[CartCubit] flush sync spId=$spId qty=$targetQty');

    // Keep the quantity visible to _silentRefresh while the request is in flight
    // so a concurrent refresh doesn't overwrite the optimistic value.
    _inFlightQty[spId] = targetQty;

    try {
      final updated = await _repository.updateItem(
        cartItemId: spId,
        action: CartUpdateAction.set,
        quantity: targetQty,
      );

      _inFlightQty.remove(spId);

      if (updated == null) {
        // Server treated qty as a remove — ensure item is gone locally.
        _applyOptimisticRemove(spId);
        // Only refresh preview, not the item list.
        unawaited(_fetchPreviewSilently());
      } else {
        // Reconcile with server (handles server-side clamping).
        _applyItemUpdate(updated);
        unawaited(_fetchPreviewSilently());
      }
    } catch (e) {
      _inFlightQty.remove(spId);
      dLog('[CartCubit] flushSync error spId=$spId: $e');
      // Network error — restore from server.
      await _silentRefresh();
    }
  }

  void _cancelPending(int spId) {
    _pending[spId]?.debounce.cancel();
    _pending.remove(spId);
  }

  // ── Optimistic UI mutations ───────────────────────────────────────────────

  void _applyOptimisticQuantity(int spId, int newQty) {
    final loaded = _loaded;
    if (loaded == null) return;

    final items = loaded.data.cartItems.map((i) {
      if (i.spId != spId) return i;
      return i.copyWithQuantity(newQty);
    }).toList();

    _safeEmit(loaded.copyWith(
      data: loaded.data.copyWith(
        cartItems: items,
        summary: _computeSummary(items),
      ),
    ));
  }

  void _applyItemAdd(CartItemModel newItem) {
    final loaded = _loaded;
    if (loaded == null) return;

    final exists =
    loaded.data.cartItems.any((i) => i.spId == newItem.spId);
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

    final items =
    loaded.data.cartItems.where((i) => i.spId != spId).toList();

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

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    for (final entry in _pending.entries) {
      entry.value.debounce.cancel();
      _repository
          .updateItem(
        cartItemId: entry.key,
        action: CartUpdateAction.set,
        quantity: entry.value.targetQuantity,
      )
          .catchError((e) => dLog('[CartCubit] close flush error: $e'));
    }
    _pending.clear();
    _inFlightQty.clear();
    return super.close();
  }
}