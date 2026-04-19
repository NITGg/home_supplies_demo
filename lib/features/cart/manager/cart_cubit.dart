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

  // ── Fetch ────────────────────────────────────────────────────────────────

  Future<void> fetchCart() async {
    emit(const CartLoading());
    try {
      final data = await _repository.getCart();
      emit(CartLoaded(data));
    } catch (e) {
      emit(CartError(extractErrorMessage(e)));
    }
  }

  // ── Add item ─────────────────────────────────────────────────────────────

  Future<void> addItem({required int spId, required int quantity}) async {
    try {
      await _repository.addItem(spId: spId, quantity: quantity);
      await fetchCart(); // refresh to get updated totals
    } catch (e) {
      log('[CartCubit] addItem error: $e');
      if (state is CartLoaded) {
        // preserve loaded state but surface error via snackbar upstream
        rethrow;
      }
      emit(CartError(extractErrorMessage(e)));
    }
  }

  // ── Increment ────────────────────────────────────────────────────────────

  Future<void> incrementItem(int cartItemId) async {
    await _updateItem(
      cartItemId: cartItemId,
      action: CartUpdateAction.increment,
      quantity: 1,
    );
  }

  // ── Decrement / remove ───────────────────────────────────────────────────

  Future<void> decrementItem(int cartItemId) async {
    final loaded = state as CartLoaded?;
    if (loaded == null) return;

    final item = loaded.data.cartItems.firstWhere((i) => i.spId == cartItemId);

    if (item.quantity <= 1) {
      // Removing last unit → optimistically remove item from list
      _applyOptimisticRemove(cartItemId);
      try {
        await _repository.updateItem(
          cartItemId: cartItemId,
          action: CartUpdateAction.decrement,
          quantity: 1,
        );
        await fetchCart(); // reconcile
      } catch (e) {
        log('[CartCubit] decrementItem error: $e');
        await fetchCart(); // rollback via refresh
        rethrow;
      }
    } else {
      await _updateItem(
        cartItemId: cartItemId,
        action: CartUpdateAction.decrement,
        quantity: 1,
      );
    }
  }

  // ── Set quantity ─────────────────────────────────────────────────────────

  Future<void> setItemQuantity(int cartItemId, int quantity) async {
    await _updateItem(
      cartItemId: cartItemId,
      action: CartUpdateAction.set,
      quantity: quantity,
    );
  }

  // ── Clear cart ───────────────────────────────────────────────────────────

  Future<void> clearCart() async {
    if (state is! CartLoaded) return;
    emit(const CartLoading());
    try {
      await _repository.clearCart();
      await fetchCart();
    } catch (e) {
      emit(CartError(extractErrorMessage(e)));
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _updateItem({
    required int cartItemId,
    required CartUpdateAction action,
    required int quantity,
  }) async {
    final loaded = state as CartLoaded?;
    if (loaded == null) return;

    // Mark item as busy
    emit(loaded.copyWith(busyItemIds: {...loaded.busyItemIds, cartItemId}));

    try {
      final updated = await _repository.updateItem(
        cartItemId: cartItemId,
        action: action,
        quantity: quantity,
      );

      if (updated == null) {
        // Item was removed from backend
        _applyOptimisticRemove(cartItemId);
      } else {
        _applyItemUpdate(updated);
      }
    } catch (e) {
      log('[CartCubit] updateItem error: $e');
      // Unmark busy, preserve state
      final current = state as CartLoaded?;
      if (current != null) {
        final busy = Set<int>.from(current.busyItemIds)..remove(cartItemId);
        emit(current.copyWith(busyItemIds: busy));
      }
      rethrow;
    }
  }

  Future<void> removeItem(int cartItemId) async {
    _applyOptimisticRemove(cartItemId);
    try {
      await _repository.updateItem(
        cartItemId: cartItemId,
        action: CartUpdateAction.set,
        quantity: 0,
      );
      await fetchCart();
    } catch (e) {
      await fetchCart();
      rethrow;
    }
  }

  void _applyItemUpdate(CartItemModel updated) {
    final loaded = state as CartLoaded?;
    if (loaded == null) return;

    final items = loaded.data.cartItems.map((item) {
      return item.spId == updated.spId ? updated : item;
    }).toList();

    final newTotal = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
    final newSummary = CartSummaryModel(
      itemCount: items.length,
      totalItems: items.fold(0, (sum, i) => sum + i.quantity),
      totalPrice: newTotal,
    );

    final busy = Set<int>.from(loaded.busyItemIds)..remove(updated.spId);
    emit(
      loaded.copyWith(
        data: loaded.data.copyWith(cartItems: items, summary: newSummary),
        busyItemIds: busy,
      ),
    );
  }

  void _applyOptimisticRemove(int cartItemId) {
    final loaded = state as CartLoaded?;
    if (loaded == null) return;

    final items = loaded.data.cartItems
        .where((i) => i.spId != cartItemId)
        .toList();
    final newTotal = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
    final newSummary = CartSummaryModel(
      itemCount: items.length,
      totalItems: items.fold(0, (sum, i) => sum + i.quantity),
      totalPrice: newTotal,
    );

    emit(
      loaded.copyWith(
        data: loaded.data.copyWith(cartItems: items, summary: newSummary),
      ),
    );
  }

}
