import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/chat/presentation/widgets/chat_input.dart';
import 'package:tawreedat_go/features/chat/presentation/widgets/message_bubble.dart';
import 'package:tawreedat_go/features/chat/presentation/widgets/typing_indicator.dart';
import '../../../l10n/app_localizations.dart';
import '../config/chat_feature_config.dart';
import '../manager/chat_cubit.dart';
import '../manager/chat_state.dart';

class ChatScreen extends StatefulWidget {
  final int currentUserId;
  final String? chatTitle;
  final String? chatAvatarUrl;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    this.chatTitle,
    this.chatAvatarUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ChatCubit>().loadMoreMessages();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatCubit, ChatState>(
      listenWhen: (prev, curr) {
        if (prev is ChatLoaded && curr is ChatLoaded) {
          return curr.messages.length > prev.messages.length;
        }
        return false;
      },
      listener: (context, state) => _scrollToBottom(),
      builder: (context, state) {
        return Scaffold(
          appBar: _buildAppBar(context, state),
          body: Column(
            children: [
              if (state is ChatLoaded && state.isClosed) _ChatClosedBanner(),
              Expanded(child: _buildBody(context, state)),
              ChatInput(
                isEnabled: state is ChatLoaded && !state.isClosed,
                onSendText: (text) =>
                    context.read<ChatCubit>().sendTextMessage(text),
                onSendImage: (filePath) =>
                    context.read<ChatCubit>().sendImageMessage(filePath),
                onTyping: () => context.read<ChatCubit>().onUserTyping(),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ChatState state) {
    String title = widget.chatTitle ?? 'Chat';
    String? avatarUrl = widget.chatAvatarUrl;

    if (state is ChatLoaded) {
      final other = state.chat.otherParticipant(widget.currentUserId);
      title = widget.chatTitle ?? other?.name ?? 'Chat';
      avatarUrl = widget.chatAvatarUrl ?? other?.avatarUrl;
    }

    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    title.isNotEmpty ? title[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (state is ChatLoaded && state.typingUserIds.isNotEmpty)
                  Text(
                    AppLocalizations.of(context)!.typing,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ChatState state) {
    if (state is ChatLoading || state is ChatInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ChatError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final loaded = state is ChatLoaded
        ? state
        : (state as MessageSendFailed).currentState;

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount:
              loaded.messages.length +
              (loaded.typingUserIds.isNotEmpty ? 1 : 0) +
              (loaded.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            final totalCount =
                loaded.messages.length +
                (loaded.typingUserIds.isNotEmpty ? 1 : 0);
            if (index == totalCount && loaded.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (index == 0 && loaded.typingUserIds.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: TypingIndicator(),
              );
            }

            final msgIndex = loaded.typingUserIds.isNotEmpty
                ? loaded.messages.length - (index - 1) - 1
                : loaded.messages.length - index - 1;

            if (msgIndex < 0 || msgIndex >= loaded.messages.length) {
              return const SizedBox.shrink();
            }

            final message = loaded.messages[msgIndex];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: MessageBubble(
                message: message,
                onRetry: () =>
                    context.read<ChatCubit>().retryMessage(message.localId),
              ),
            );
          },
        ),
        if (state is MessageSendFailed)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ErrorBanner(
              message: state.error,
              onRetry: () => context.read<ChatCubit>().retryMessage(
                state.failedMessageLocalId,
              ),
            ),
          ),
      ],
    );
  }
}

class _ChatClosedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Text(
        ChatFeatureConfig.chatClosedMessage,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade700,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(
                AppLocalizations.of(context)!.retry,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
