import '../../core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/admin_widgets.dart';
import '../../data/repositories/admin_messaging_repository.dart';
import '../../models/chat_conversation.dart';
import '../../models/chat_message.dart';

enum MessageFilter { all, unread }

class MessagesPanel extends ConsumerStatefulWidget {
  const MessagesPanel({
    super.key,
    required this.onClose,
    this.initialConversationId,
  });

  final VoidCallback onClose;
  final String? initialConversationId;

  @override
  ConsumerState<MessagesPanel> createState() => _MessagesPanelState();
}

class _MessagesPanelState extends ConsumerState<MessagesPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 180),
  )..forward();
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  MessageFilter _filter = MessageFilter.all;
  String _search = '';
  ChatConversation? _selectedConversation;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _close() {
    _controller.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  void _selectConversation(ChatConversation conv) {
    setState(() => _selectedConversation = conv);
    ref.read(adminMessagingRepositoryProvider).markAsRead(conv.id);
  }

  void _backToList() {
    setState(() => _selectedConversation = null);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedConversation == null) return;
    final convId = _selectedConversation!.id;
    _messageController.clear();

    await ref.read(adminMessagingRepositoryProvider).sendMessage(
          conversationId: convId,
          text: text,
          senderRole: 'admin',
          senderName: 'PalengkeGo Admin',
        );

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final conversationsAsync = ref.watch(adminConversationsProvider);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        child: FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: .96, end: 1).animate(_animation),
            child: Material(
              color: colors.elevatedSurface,
              elevation: 18,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.subtleBorder),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _selectedConversation != null
                    ? _buildChatView(context, colors)
                    : _buildListView(context, colors, conversationsAsync),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Conversation List View ──────────────────────────────────────────────────

  Widget _buildListView(
    BuildContext context,
    AppSemanticColors colors,
    AsyncValue<List<ChatConversation>> conversationsAsync,
  ) {
    final unreadCount = ref.watch(adminUnreadMessagesCountProvider);

    return Column(
      children: [
        _header(context, colors, unreadCount),
        _searchBar(context, colors),
        _filters(context, colors),
        Divider(height: 1, color: colors.subtleBorder),
        Expanded(
          child: conversationsAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Could not load messages: $err',
                  style: TextStyle(color: colors.mutedText, fontSize: 12),
                ),
              ),
            ),
            data: (allConversations) {
              final filtered = _filterConversations(allConversations);
              if (filtered.isEmpty) {
                return _emptyState(context, colors);
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, indent: 64, color: colors.subtleBorder.withValues(alpha: .5)),
                itemBuilder: (context, index) {
                  final conv = filtered[index];
                  return _ConversationTile(
                    conversation: conv,
                    onTap: () => _selectConversation(conv),
                  );
                },
              );
            },
          ),
        ),
        _footer(context, colors),
      ],
    );
  }

  List<ChatConversation> _filterConversations(List<ChatConversation> list) {
    return list.where((c) {
      if (_filter == MessageFilter.unread && !c.hasUnreadForAdmin) return false;

      if (_search.isNotEmpty) {
        final matchStall = c.stallName.toLowerCase().contains(_search);
        final matchSnippet = c.lastMessageText.toLowerCase().contains(_search);
        final matchType = c.inquiryType.toLowerCase().contains(_search);
        if (!matchStall && !matchSnippet && !matchType) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _header(BuildContext context, AppSemanticColors colors, int unread) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 20, color: colors.accent),
          const SizedBox(width: 8),
          Text(
            'Messages',
            style: TextStyle(
              color: colors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: colors.dangerContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unread new',
                style: TextStyle(
                  color: colors.danger,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            tooltip: 'Open full messages page',
            icon: Icon(Icons.open_in_new_rounded, size: 18, color: colors.secondaryText),
            onPressed: () {
              widget.onClose();
              context.go('/messages');
            },
          ),
          IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.close_rounded, size: 19, color: colors.secondaryText),
            onPressed: _close,
          ),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context, AppSemanticColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: TextField(
        controller: _searchController,
        style: TextStyle(fontSize: 12.5, color: colors.primaryText),
        decoration: InputDecoration(
          hintText: 'Search conversations or messages...',
          hintStyle: TextStyle(fontSize: 12, color: colors.mutedText),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: colors.mutedText),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          filled: true,
          fillColor: colors.inputSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.subtleBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.subtleBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.accent, width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _filters(BuildContext context, AppSemanticColors colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          _filterChip(colors, 'All', MessageFilter.all),
          const SizedBox(width: 6),
          _filterChip(colors, 'Unread', MessageFilter.unread),
        ],
      ),
    );
  }

  Widget _filterChip(AppSemanticColors colors, String label, MessageFilter filter) {
    final selected = _filter == filter;
    return InkWell(
      onTap: () => setState(() => _filter = filter),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? colors.accent.withValues(alpha: .12) : colors.inputSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.accent : colors.subtleBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.accent : colors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, AppSemanticColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 40, color: colors.mutedText.withValues(alpha: .6)),
            const SizedBox(height: 10),
            Text(
              'No messages found',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: colors.primaryText),
            ),
            const SizedBox(height: 4),
            Text(
              'Vendor conversations will appear here in real-time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.mutedText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, AppSemanticColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: colors.inputSurface,
        border: Border(top: BorderSide(color: colors.subtleBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Connected to PalengkeGoApp Live Chat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: colors.mutedText, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              widget.onClose();
              context.go('/messages');
            },
            child: Text(
              'View All →',
              style: TextStyle(fontSize: 11, color: colors.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Integrated Chat View ────────────────────────────────────────────────────

  Widget _buildChatView(BuildContext context, AppSemanticColors colors) {
    final conv = _selectedConversation!;
    final messagesAsync = ref.watch(adminConversationMessagesProvider(conv.id));

    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: colors.inputSurface,
            border: Border(bottom: BorderSide(color: colors.subtleBorder)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: _backToList,
                tooltip: 'Back to conversations',
              ),
              const SizedBox(width: 4),
              _AvatarSmall(name: conv.stallName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conv.stallName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: colors.primaryText,
                      ),
                    ),
                    Text(
                      'Stall Holder • ID: ${conv.stallId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.mutedText),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: colors.secondaryText),
                onPressed: _close,
                tooltip: 'Close',
              ),
            ],
          ),
        ),

        // Message Stream
        Expanded(
          child: messagesAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err', style: TextStyle(fontSize: 11, color: colors.danger)),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet in this conversation.',
                    style: TextStyle(fontSize: 11, color: colors.mutedText),
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final prevMsg = index > 0 ? messages[index - 1] : null;
                  final isNewDay = prevMsg == null ||
                      msg.timestamp.year != prevMsg.timestamp.year ||
                      msg.timestamp.month != prevMsg.timestamp.month ||
                      msg.timestamp.day != prevMsg.timestamp.day;

                  final isRight = msg.isFromAdmin;

                  return Column(
                    children: [
                      if (isNewDay) _PanelDateDivider(date: msg.timestamp),
                      _ChatBubble(
                        message: msg,
                        isRight: isRight,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),

        // Message Composer
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: colors.elevatedSurface,
            border: Border(top: BorderSide(color: colors.subtleBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(fontSize: 12.5, color: colors.primaryText),
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Type admin message as Market Master...',
                    hintStyle: TextStyle(fontSize: 11.5, color: colors.mutedText),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: colors.inputSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: colors.subtleBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: colors.subtleBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: colors.accent, width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: colors.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sendMessage,
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Components: Conversation Tile, Chat Bubble, Badges ───────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0 && now.day == dt.day) {
      return DateFormat('h:mm a').format(dt);
    } else if (now.difference(dt).inDays < 2) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final hasUnread = conversation.hasUnreadForAdmin;

    return InkWell(
      onTap: onTap,
      hoverColor: colors.inputSurface.withValues(alpha: .7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvatarSmall(name: conversation.stallName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.stallName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                            color: colors.primaryText,
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(conversation.lastMessageTimestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: hasUnread ? colors.accent : colors.mutedText,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '🏪 Stall: ${conversation.stallId}',
                    style: TextStyle(fontSize: 10.5, color: colors.secondaryText, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessageText.isEmpty
                              ? 'No messages yet'
                              : conversation.lastMessageText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: hasUnread ? colors.primaryText : colors.mutedText,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelDateDivider extends StatelessWidget {
  const _PanelDateDivider({required this.date});

  final DateTime date;

  String _format(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today • ${DateFormat('MMM d, yyyy').format(dt)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'Yesterday • ${DateFormat('MMM d, yyyy').format(dt)}';
    }
    return DateFormat('EEE, MMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: colors.inputSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.subtleBorder),
          ),
          child: Text(
            _format(date),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isRight,
  });

  final ChatMessage message;
  final bool isRight;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = message.isFromAdmin;
    final isVendor = message.isFromVendor;

    Color bg;
    Color fg;
    Border? border;

    if (isAdmin) {
      bg = colors.accent;
      fg = Colors.white;
    } else if (isVendor) {
      bg = isDark ? colors.cardBackground : const Color(0xFFF0FDF4);
      fg = colors.primaryText;
      border = Border.all(color: const Color(0xFF10B981).withValues(alpha: .4));
    } else {
      bg = colors.inputSurface;
      fg = colors.primaryText;
      border = Border.all(color: colors.subtleBorder);
    }

    final roleLabel = isAdmin
        ? 'PalengkeGo Admin'
        : (isVendor ? 'Stall Holder (${message.senderName})' : message.senderName);

    final dateStr = DateFormat('MMM d • h:mm a').format(message.timestamp);

    return Align(
      alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isRight ? 14 : 2),
            bottomRight: Radius.circular(isRight ? 2 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender and Date at top of message
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isRight) ...[
                  Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: colors.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: colors.mutedText,
                    ),
                  ),
                ] else ...[
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: isAdmin ? Colors.white.withValues(alpha: .8) : colors.mutedText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isAdmin ? Colors.white : (isDark ? colors.accent : const Color(0xFF047857)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message.text,
              style: TextStyle(fontSize: 12, color: fg, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarSmall extends StatelessWidget {
  const _AvatarSmall({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final initials = name.trim().isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase()
        : '?';

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: .15),
        shape: BoxShape.circle,
        border: Border.all(color: colors.accent.withValues(alpha: .3)),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: colors.accent,
          ),
        ),
      ),
    );
  }
}
