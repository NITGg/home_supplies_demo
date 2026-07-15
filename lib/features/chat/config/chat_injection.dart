//courier


import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/features/chat/data/repo/chat_repository_impl.dart';

import '../../../core/utils/api_client.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/socket_service.dart';
import '../data/data_source/chat_remote_datasource.dart';
import '../data/repo/chat_repository.dart';
import '../manager/chat_cubit.dart';
import '../manager/chat_state.dart';
import '../manager/inbox_cubit.dart';
import '../presentation/chat_screen.dart';
import 'chat_socket_service.dart';


/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 1: Boot the chat module when an active order is loaded.
/// ─────────────────────────────────────────────────────────────────────────────
///
/// **Courier app — dedicated chat socket (different server/path):**
/// ```dart
/// ChatModule.init(
///   currentUserId: profileCubit.currentProfile!.id,
///   accessToken: token,
///   baseUrl: 'https://tawreedat.nitg-eg.com',
///   socketPath: '/courier_apis/socket.io',
/// );
/// ```
/// This opens a **second** socket exclusively for chat while [SocketService]
/// maintains the existing orders socket.  The two sockets are fully
/// independent.
///
/// **Borrow mode (no accessToken) — reuses the [SocketService] socket:**
/// ```dart
/// ChatModule.init(currentUserId: user.id, baseUrl: '...');
/// ```
class ChatModule {
  ChatModule._();

  static ChatRepository? _repository;
  static int? _currentUserId;

  /// Initialises the chat module.
  ///
  /// ### Mode A – Dedicated socket (recommended for courier app)
  /// Pass [accessToken].  [ChatSocketService] opens its own socket to
  /// [baseUrl]/[socketPath], completely separate from [SocketService].
  /// Two sockets, two servers, zero interference.
  ///
  /// ### Mode B – Borrowed socket
  /// Omit [accessToken].  Chat events are delivered over the already-connected
  /// [SocketService] direct socket (iOS / Android direct mode) or routed
  /// through its task-isolate channel (Android background mode).
  static void init({
    required int currentUserId,
    String? accessToken,          // provide to open a dedicated chat socket
    required String baseUrl,
    String socketPath = '/socket.io',
  }) {
    if (_repository != null) return;

    _currentUserId = currentUserId;

    final remote = ChatRemoteDataSourceImpl(
      dio: ApiClient.instance.dio,
      currentUserId: currentUserId,
    );

    if (accessToken != null) {
      // ── MODE A: Dedicated socket ──────────────────────────────────────────
      // ChatSocketService owns this connection entirely.
      // SocketService (orders socket) is not touched at all.
      dLog('🔌 [ChatModule] Opening dedicated chat socket → $baseUrl$socketPath');
      ChatSocketService().connect(
        baseUrl: baseUrl,
        accessToken: accessToken,
        socketPath: socketPath,
      );
    } else {
      // ── MODE B: Reuse the SocketService socket ────────────────────────────
      final rawSocket = SocketService().rawSocket;
      if (rawSocket != null) {
        // iOS / Android direct-socket: borrow the live socket.
        ChatSocketService().borrowSocket(rawSocket);
        dLog('🔗 [ChatModule] Chat borrowed existing SocketService socket');
      } else {
        // Android task-isolate: route emits + receives through SocketService.
        ChatSocketService().useSocketServiceTransport();
        SocketService().setChatEventDelegate(
          ChatSocketService().dispatchIncomingEvent,
        );
        dLog('📡 [ChatModule] Chat wired to SocketService task-isolate transport');
      }

      // Re-borrow whenever SocketService creates a fresh direct socket
      // (e.g. after a token refresh).
      SocketService().setNewSocketCallback((newSocket) {
        dLog('🔄 [ChatModule] Re-borrowing new socket after token refresh');
        ChatSocketService().borrowSocket(newSocket);
      });
    }

    _repository = ChatRepositoryImpl(
      remote: remote,
      socket: ChatSocketService(),
    );
  }

  /// True after [init] has been called and before [dispose] is called.
  static bool get isInitialized => _repository != null;

  static ChatRepository get repository {
    assert(_repository != null,
    'ChatModule.init() must be called before accessing the repository.');
    return _repository!;
  }

  static int get currentUserId {
    assert(_currentUserId != null,
    'ChatModule.init() must be called before accessing currentUserId.');
    return _currentUserId!;
  }

  /// Tears down the chat module when the active order ends.
  ///
  /// In **dedicated** mode [ChatSocketService.disconnect] closes and disposes
  /// the owned socket.
  /// In **borrowed** mode [ChatSocketService.detach] removes listeners only —
  /// the shared [SocketService] socket is left completely untouched.
  static void dispose() {
    ChatSocketService().disconnect();            // safe in all modes
    SocketService().setChatEventDelegate(null);  // clear isolate delegate
    SocketService().setNewSocketCallback(null);  // clear re-borrow callback
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
  static Future<void> openChatWithUser(
      BuildContext context, {
        required int targetUserId,
        int? orderId,
        String? chatTitle,
        String? chatAvatarUrl,
      }) {
    return _push(
      context,
      onCreated: (cubit) => cubit.openChat(targetUserId, orderId: orderId),
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
    InboxCubit? inboxCubit;
    try {
      inboxCubit = context.read<InboxCubit>();
    } catch (_) {}

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (ctx) {
            final cubit = ChatCubit(
              repo: ChatModule.repository,
              currentUserId: ChatModule.currentUserId,
            );
            onCreated(cubit);

            cubit.stream
                .firstWhere((s) => s is ChatLoaded)
                .then((s) {
              final chatId = (s as ChatLoaded).chat.id;
              inboxCubit?.setActiveChat(chatId);
            }).ignore();

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

    inboxCubit?.setActiveChat(null);
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 4: Close the chat when the order is confirmed.
/// ─────────────────────────────────────────────────────────────────────────────
extension ChatOrderLifecycle on ChatModule {
  static void onOrderConfirmed(
      BuildContext context, {
        int? chatId,
      }) {
    if (chatId != null) {
      try {
        context.read<InboxCubit>().closeChat(chatId);
      } catch (_) {}
    }

    try {
      context.read<ChatCubit>().closeChatForOrder();
    } catch (_) {}
  }
}