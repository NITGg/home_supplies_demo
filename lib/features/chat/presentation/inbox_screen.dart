import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../data/models/chat_model.dart';
import '../manager/inbox_cubit.dart';
import '../manager/inbox_state.dart';


/// Displays the list of all chats for the current user.
///
/// Requires [InboxCubit] to be provided above it in the tree.
/// Pass [currentUserId] so each row correctly resolves the "other" participant.
///
/// Navigation:
///   When a chat row is tapped, [onChatTap] is called with the [ChatModel].
///   Provide this callback to push to [ChatScreen] and set up [ChatCubit].
class InboxScreen extends StatelessWidget {
  final int currentUserId;
  final void Function(ChatModel chat) onChatTap;

  const InboxScreen({
    super.key,
    required this.currentUserId,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<InboxCubit>().loadChats(),
          ),
        ],
      ),
      body: BlocBuilder<InboxCubit, InboxState>(
        builder: (context, state) {
          if (state is InboxLoading || state is InboxInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InboxError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context.read<InboxCubit>().loadChats(),
            );
          }

          final chats = (state as InboxLoaded).chats;

          if (chats.isEmpty) {
            return const _EmptyInbox();
          }

          return RefreshIndicator(
            onRefresh: () => context.read<InboxCubit>().loadChats(),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: chats.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 72,
              ),
              itemBuilder: (context, index) {
                return _ChatTile(
                  chat: chats[index],
                  currentUserId: currentUserId,
                  onTap: () => onChatTap(chats[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─── Chat List Tile ───────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final int currentUserId;
  final VoidCallback onTap;

  const _ChatTile({
    required this.chat,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final other = chat.otherParticipant(currentUserId);
    final name = other?.name ?? 'Unknown';
    final avatarUrl = other?.avatarUrl;
    final lastMsg = chat.lastMessage;
    final hasUnread = chat.unreadCount > 0;
    final isClosed = chat.isClosed;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  )
                : null,
          ),
          if (isClosed)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: lastMsg != null
          ? Text(
              lastMsg.isMe ? 'You: ${lastMsg.content}' : lastMsg.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: hasUnread
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                fontWeight:
                    hasUnread ? FontWeight.w500 : FontWeight.normal,
              ),
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMsg != null)
            Text(
              _formatTime(lastMsg.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: hasUnread
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          const SizedBox(height: 4),
          if (hasUnread)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            )
          else if (isClosed)
            Text(
              'Closed',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat.jm().format(local);
    }
    return DateFormat.MMMd().format(local);
  }
}

// ─── Empty & Error ────────────────────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 16,
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a chat by messaging another user',
            style: TextStyle(
              fontSize: 13,
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
