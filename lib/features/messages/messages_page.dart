import '../../core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/admin_widgets.dart';
import '../../data/repositories/admin_messaging_repository.dart';
import '../../models/chat_conversation.dart';
import '../../models/chat_message.dart';

/// Full-page messaging dashboard allowing Market Admin to manage vendor conversations,
/// view real-time chat histories, search stall holders, and send responses.
class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({
    super.key,
    this.initialConversationId,
  });

  /// Optional initial conversation identifier to select immediately upon opening.
  final String? initialConversationId;

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String _filter = 'All';
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
    _searchController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectConversation(ChatConversation conv) {
    setState(() => _selectedConversation = conv);
    ref.read(adminMessagingRepositoryProvider).markAsRead(conv.id);
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top page header banner
            _buildPageHeader(context, colors),

            // Content body
            Expanded(
              child: conversationsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
                error: (err, _) => Center(
                  child: Text('Error loading conversations: $err', style: TextStyle(color: colors.danger)),
                ),
                data: (allConversations) {
                  // Handle initial conversation ID if passed via query param
                  if (_selectedConversation == null &&
                      widget.initialConversationId != null &&
                      widget.initialConversationId!.isNotEmpty) {
                    final match = allConversations
                        .where((c) => c.id == widget.initialConversationId)
                        .firstOrNull;
                    if (match != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _selectConversation(match);
                      });
                    }
                  }

                  final filtered = _filterConversations(allConversations);

                  if (isMobile) {
                    if (_selectedConversation != null) {
                      return _buildChatPane(context, colors, _selectedConversation!, showBackButton: true);
                    }
                    return _buildConversationsListPane(context, colors, filtered);
                  }

                  // Desktop two-pane split view
                  return Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.subtleBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        // Left Pane: Conversation list
                        SizedBox(
                          width: 380,
                          child: _buildConversationsListPane(context, colors, filtered),
                        ),
                        VerticalDivider(width: 1, thickness: 1, color: colors.subtleBorder),

                        // Right Pane: Active Chat
                        Expanded(
                          child: _selectedConversation != null
                              ? _buildChatPane(context, colors, _selectedConversation!)
                              : _buildNoConversationSelected(context, colors),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, AppSemanticColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      color: colors.heroBackground,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.forum_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'In-App Market Messaging',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Communicate directly with registered stall holders and vendors across the public market.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<ChatConversation> _filterConversations(List<ChatConversation> list) {
    return list.where((c) {
      if (_filter == 'Unread' && !c.hasUnreadForAdmin) return false;

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

  Widget _buildConversationsListPane(
    BuildContext context,
    AppSemanticColors colors,
    List<ChatConversation> filtered,
  ) {
    return Column(
      children: [
        // Search & Filters Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 13, color: colors.primaryText),
            decoration: InputDecoration(
              hintText: 'Search conversations...',
              hintStyle: TextStyle(fontSize: 12, color: colors.mutedText),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: colors.mutedText),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
        ),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              for (final f in ['All', 'Unread']) ...[
                _filterPill(colors, f),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: colors.subtleBorder),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No matching conversations', style: TextStyle(color: colors.mutedText, fontSize: 13)),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, indent: 64, color: colors.subtleBorder.withValues(alpha: .5)),
                  itemBuilder: (context, index) {
                    final conv = filtered[index];
                    final isSelected = _selectedConversation?.id == conv.id;
                    return InkWell(
                      onTap: () => _selectConversation(conv),
                      child: Container(
                        color: isSelected ? colors.accent.withValues(alpha: .08) : null,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _AvatarCircle(name: conv.displayStallName),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          conv.displayStallName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: conv.hasUnreadForAdmin ? FontWeight.w800 : FontWeight.w600,
                                            color: colors.primaryText,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        DateFormat('h:mm a').format(conv.lastMessageTimestamp),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: conv.hasUnreadForAdmin ? colors.accent : colors.mutedText,
                                          fontWeight: conv.hasUnreadForAdmin ? FontWeight.w700 : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '🏪 Stall: ${conv.stallId}',
                                    style: TextStyle(fontSize: 11, color: colors.secondaryText),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          conv.lastMessageText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: conv.hasUnreadForAdmin ? colors.primaryText : colors.mutedText,
                                            fontWeight: conv.hasUnreadForAdmin ? FontWeight.w600 : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      if (conv.hasUnreadForAdmin)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(left: 6),
                                          decoration: BoxDecoration(
                                            color: colors.success,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterPill(AppSemanticColors colors, String label) {
    final selected = _filter == label;
    return InkWell(
      onTap: () => setState(() => _filter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? colors.accent.withValues(alpha: .12) : colors.inputSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? colors.accent : colors.subtleBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.accent : colors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildChatPane(
    BuildContext context,
    AppSemanticColors colors,
    ChatConversation conv, {
    bool showBackButton = false,
  }) {
    final messagesAsync = ref.watch(adminConversationMessagesProvider(conv.id));

    return Column(
      children: [
        // Thread Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: colors.inputSurface,
            border: Border(bottom: BorderSide(color: colors.subtleBorder)),
          ),
          child: Row(
            children: [
              if (showBackButton) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => setState(() => _selectedConversation = null),
                ),
                const SizedBox(width: 8),
              ],
              _AvatarCircle(name: conv.displayStallName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conv.displayStallName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stall Holder • ID: ${conv.stallId}',
                      style: TextStyle(fontSize: 11.5, color: colors.mutedText),
                    ),
                  ],
                ),
              ),
              if (conv.relatedOrderId != null && conv.relatedOrderId!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Order #${conv.relatedOrderId}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.accent),
                  ),
                ),
            ],
          ),
        ),

        // Message List
        Expanded(
          child: messagesAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: colors.accent),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err', style: TextStyle(color: colors.danger)),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Text('No messages yet in this conversation.', style: TextStyle(color: colors.mutedText)),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                      if (isNewDay) _DateDivider(date: msg.timestamp),
                      _FullChatBubble(
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

        // Composer
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: colors.elevatedSurface,
            border: Border(top: BorderSide(color: colors.subtleBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(fontSize: 13, color: colors.primaryText),
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Type response as PalengkeGo Market Admin...',
                    hintStyle: TextStyle(fontSize: 12.5, color: colors.mutedText),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: colors.inputSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colors.subtleBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colors.subtleBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colors.accent, width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: colors.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sendMessage,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.send_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoConversationSelected(BuildContext context, AppSemanticColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 54, color: colors.mutedText.withValues(alpha: .5)),
          const SizedBox(height: 14),
          Text(
            'Select a conversation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a stall holder conversation from the left to view messages and reply.',
            style: TextStyle(fontSize: 12, color: colors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  String _format(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today • ${DateFormat('MMMM d, yyyy').format(dt)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'Yesterday • ${DateFormat('MMMM d, yyyy').format(dt)}';
    }
    return DateFormat('EEEE, MMMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: colors.inputSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.subtleBorder),
          ),
          child: Text(
            _format(date),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullChatBubble extends StatelessWidget {
  const _FullChatBubble({
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
        ? 'PalengkeGo Market Admin'
        : (isVendor ? 'Stall Holder (${message.senderName})' : message.senderName);

    final timeStr = DateFormat('h:mm a').format(message.timestamp);

    return Align(
      alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isRight ? 16 : 3),
            bottomRight: Radius.circular(isRight ? 3 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender and Time at the top of the message
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isRight) ...[
                  Flexible(
                    child: Text(
                      roleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: colors.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: colors.mutedText,
                    ),
                  ),
                ] else ...[
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: isAdmin ? Colors.white.withValues(alpha: .8) : colors.mutedText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      roleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isAdmin ? Colors.white : (isDark ? colors.accent : const Color(0xFF047857)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Text(
              message.text,
              style: TextStyle(fontSize: 13, color: fg, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final initials = name.trim().isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase()
        : '?';

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: .15),
        shape: BoxShape.circle,
        border: Border.all(color: colors.accent.withValues(alpha: .3)),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: colors.accent,
          ),
        ),
      ),
    );
  }
}
