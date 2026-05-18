import 'package:flutter/material.dart';
import 'package:tawreedat_go/core/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/api_client.dart';
import '../data/data_source/chat_remote_datasource.dart';
import '../data/repo/chat_repository.dart';
import '../data/repo/chat_repository_impl.dart';
import '../manager/chat_cubit.dart';
import '../manager/chat_state.dart';
import '../manager/inbox_cubit.dart';
import '../presentation/chat_screen.dart';
import 'chat_socket_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 1: Boot the chat module once the main socket is connected.
/// ─────────────────────────────────────────────────────────────────────────────
///
/// Call this after [SocketService.connect] succeeds — typically right after
/// a successful login when the shared socket is already live:
///
/// ```dart
/// // After SocketService().connect(...) is called:
/// ChatModule.init(currentUserId: profile.id);
/// ```
///
/// [ChatSocketService] will borrow the shared socket automatically.
/// No token, no URL — the socket is already connected.
class ChatModule {
  ChatModule._();

  static ChatRepository? _repository;
  static int? _currentUserId;

  /// Initialises the chat module and attaches chat listeners to the shared
  /// [SocketService] socket.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  static void init({required int currentUserId}) {
    if (_repository != null) return;

    _currentUserId = currentUserId;

    // Attach chat listeners to the already-connected shared socket.
    ChatSocketService().attach();

    final remote = ChatRemoteDataSourceImpl(
      dio: ApiClient.instance.dio,
      currentUserId: currentUserId,
    );

    _repository = ChatRepositoryImpl(
      remote: remote,
      socket: ChatSocketService(),
    );

    dLog('🟢 [ChatModule] Initialised — currentUserId: $currentUserId');
  }

  /// True after [init] has been called and before [dispose] is called.
  static bool get isInitialized => _repository != null;

  static ChatRepository get repository {
    assert(
    _repository != null,
    'ChatModule.init() must be called before accessing the repository.',
    );
    return _repository!;
  }

  static int get currentUserId {
    assert(
    _currentUserId != null,
    'ChatModule.init() must be called before accessing currentUserId.',
    );
    return _currentUserId!;
  }

  /// Ensures the chat socket is attached every time [ChatScreen] is opened.
  ///
  /// Covers two scenarios that [init] alone cannot handle:
  ///
  /// 1. **Detached after dispose** — [ChatSocketService] was detached (e.g. on
  ///    a previous logout/re-login cycle) but [init] was not called again.
  ///
  /// 2. **Stale socket reference** — [SocketService] reconnected and produced a
  ///    new [IO.Socket] instance; [ChatSocketService] is holding the old one.
  ///    [ChatSocketService.attach] detects the mismatch and re-attaches.
  ///
  /// Safe to call on every navigation — it is a no-op when the socket is
  /// already attached to the current [SocketService] instance.
  static void ensureAttached() {
    if (!ChatSocketService().isAttached) {
      dLog('🔁 [ChatModule] ensureAttached — socket detached, re-attaching');
      ChatSocketService().attach();
    } else {
      // Delegate to attach() anyway so it can detect a stale socket reference.
      // attach() will no-op if the stored reference matches the current one.
      ChatSocketService().attach();
    }
  }

  /// Tears down the chat module.
  ///
  /// Removes chat-specific listeners from the shared socket and leaves all
  /// active chat rooms. The shared socket itself stays connected — order and
  /// offer events are completely unaffected.
  static void dispose() {
    ChatSocketService().detach();
    _repository = null;
    _currentUserId = null;
    dLog('🔌 [ChatModule] Disposed');
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 2: Provide InboxCubit at the top of your authenticated widget tree.
/// ─────────────────────────────────────────────────────────────────────────────
///
/// Wrap your home/shell widget with this so InboxCubit stays alive and reacts
/// to background messages while the user browses other screens.
///
/// ```dart
/// child: ChatInboxProvider(child: MyHomeScreen()),
/// ```
class ChatInboxProvider extends StatelessWidget {
  final Widget child;

  const ChatInboxProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboxCubit(
        repo: ChatModule.repository,
        currentUserId: ChatModule.currentUserId,
      )..init(),
      child: child,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 3: Push to ChatScreen — handles both new and existing chats.
/// ─────────────────────────────────────────────────────────────────────────────
///
/// Usage A — open an existing chat from the inbox:
/// ```dart
/// ChatNavigator.openExistingChat(context, chatId: chat.id);
/// ```
///
/// Usage B — start / resume a chat from the order screen:
/// ```dart
/// ChatNavigator.openChatWithUser(context, targetUserId: order.customerId);
/// ```
class ChatNavigator {
  ChatNavigator._();

  /// Open a chat whose [chatId] is already known (from the inbox).
  static Future<void> openExistingChat(
      BuildContext context, {
        required int chatId,
        String? chatTitle,
        String? chatAvatarUrl,
      }) {
    return _push(
      context,
      onCreated: (cubit) => cubit.joinExistingChat(chatId),
      chatTitle: chatTitle,
      chatAvatarUrl: chatAvatarUrl,
    );
  }

  /// Create (or resume) a 1:1 chat with any user by their ID.
  /// Typically called from an order screen.
  static Future<void> openChatWithUser(
      BuildContext context, {
        required int targetUserId,
        String? chatTitle,
        String? chatAvatarUrl,
      }) {
    return _push(
      context,
      onCreated: (cubit) => cubit.openChat(targetUserId),
      chatTitle: chatTitle,
      chatAvatarUrl: chatAvatarUrl,
    );
  }

  static Future<void> _push(
      BuildContext context, {
        required void Function(ChatCubit) onCreated,
        String? chatTitle,
        String? chatAvatarUrl,
      }) async {
    // Guarantee the chat socket is attached (and pointing at the current
    // SocketService instance) before the screen mounts. This is the single
    // choke-point for every ChatScreen navigation, so one call here covers
    // both openExistingChat and openChatWithUser.
    ChatModule.ensureAttached();

    // We don't know chatId yet for new chats, but ChatCubit will resolve it.
    // We hook into the cubit's state to grab the chatId once loaded.
    final inboxCubit = context.read<InboxCubit>();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (ctx) {
            final cubit = ChatCubit(
              repo: ChatModule.repository,
              currentUserId: ChatModule.currentUserId,
            );
            onCreated(cubit);

            // Once the cubit resolves to ChatLoaded, tell InboxCubit.
            cubit.stream.firstWhere((s) => s is ChatLoaded).then((s) {
              final chatId = (s as ChatLoaded).chat.id;
              inboxCubit.setActiveChat(chatId);
            });

            return cubit;
          },
          child: ChatScreen(
            currentUserId: ChatModule.currentUserId,
            chatTitle: chatTitle,
            chatAvatarUrl: chatAvatarUrl,
          ),
        ),
      ),
    );

    // User popped the screen — clear active chat.
    inboxCubit.setActiveChat(null);
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 4: Close the chat when the order is confirmed.
/// ─────────────────────────────────────────────────────────────────────────────
///
/// Call this from your OrderCubit / order confirmed handler:
///
/// ```dart
/// ChatModule.onOrderConfirmed(context: context, chatId: order.chatId);
/// ```
extension ChatOrderLifecycle on ChatModule {
  static void onOrderConfirmed(
      BuildContext context, {
        int? chatId,
      }) {
    // 1. Lock the inbox row.
    if (chatId != null) {
      try {
        context.read<InboxCubit>().closeChat(chatId);
      } catch (_) {
        // InboxCubit not in scope — ignore.
      }
    }

    // 2. Lock the open chat screen (if currently mounted).
    try {
      context.read<ChatCubit>().closeChatForOrder();
    } catch (_) {
      // ChatCubit not in scope — ignore.
    }
  }
}