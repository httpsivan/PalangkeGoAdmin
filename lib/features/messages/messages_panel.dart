import 'dart:convert';

import '../../core/theme/theme_extensions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/admin_widgets.dart';
import '../../data/repositories/admin_messaging_repository.dart';
import '../../models/chat_conversation.dart';
import '../../models/chat_message.dart';

/// Filter options for conversations in the messaging overlay panel.
enum MessageFilter { all, unread }

/// Slide-over drawer panel providing fast access to vendor messaging from anywhere
/// in the PalengkeGo Admin interface.
class MessagesPanel extends ConsumerStatefulWidget {
  const MessagesPanel({
    super.key,
    required this.onClose,
    this.initialConversationId,
  });

  /// Callback executed when the panel close button or overlay backdrop is pressed.
  final VoidCallback onClose;

  /// Optional initial conversation to display directly when the panel opens.
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
  String? _lastScrolledConversationId;
  int _lastScrolledMessageCount = 0;

  String? _selectedImageDataUri;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isPickingImage = false;

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

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      if (animated) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(maxScroll);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients &&
              _scrollController.offset < _scrollController.position.maxScrollExtent) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    });
  }

  void _close() {
    _controller.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  void _selectConversation(ChatConversation conv) {
    setState(() {
      _selectedConversation = conv;
      _lastScrolledConversationId = null;
      _lastScrolledMessageCount = 0;
      _selectedImageDataUri = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
    ref.read(adminMessagingRepositoryProvider).markAsRead(conv.id);
  }

  void _backToList() {
    setState(() {
      _selectedConversation = null;
      _lastScrolledConversationId = null;
      _lastScrolledMessageCount = 0;
      _selectedImageDataUri = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null && bytes.isNotEmpty) {
          final ext = (file.extension ?? 'jpeg').toLowerCase();
          final mime = ext == 'png'
              ? 'png'
              : ext == 'gif'
                  ? 'gif'
                  : ext == 'webp'
                      ? 'webp'
                      : 'jpeg';
          final dataUri = 'data:image/$mime;base64,${base64Encode(bytes)}';
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageDataUri = dataUri;
            _selectedImageName = file.name;
          });
        }
      }
    } catch (_) {
      // Ignore picker cancellation or platform error
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImageDataUri = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final attachment = _selectedImageDataUri;
    if ((text.isEmpty && (attachment == null || attachment.isEmpty)) ||
        _selectedConversation == null) {
      return;
    }
    final convId = _selectedConversation!.id;
    _messageController.clear();
    _clearSelectedImage();

    await ref.read(adminMessagingRepositoryProvider).sendMessage(
          conversationId: convId,
          text: text,
          senderRole: 'admin',
          senderName: 'PalengkeGo Admin',
          attachmentUrl: attachment,
          attachmentType: attachment != null ? 'image' : null,
        );

    _scrollToBottom(animated: true);
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
      final text = c.lastMessageText.trim();
      if (text.isEmpty || text.toLowerCase() == 'no messages yet') {
        return false;
      }
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
              _AvatarSmall(name: conv.displayStallName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conv.displayStallName,
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

              if (_lastScrolledConversationId != conv.id) {
                _lastScrolledConversationId = conv.id;
                _lastScrolledMessageCount = messages.length;
                _scrollToBottom(animated: false);
              } else if (_lastScrolledMessageCount != messages.length) {
                _lastScrolledMessageCount = messages.length;
                _scrollToBottom(animated: true);
              }

              final sortedMessages = List<ChatMessage>.from(messages)
                ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: sortedMessages.length,
                itemBuilder: (context, index) {
                  final msg = sortedMessages[index];
                  final prevMsg = index > 0 ? sortedMessages[index - 1] : null;
                  final isNewDay = prevMsg == null ||
                      msg.timestamp.toLocal().year != prevMsg.timestamp.toLocal().year ||
                      msg.timestamp.toLocal().month != prevMsg.timestamp.toLocal().month ||
                      msg.timestamp.toLocal().day != prevMsg.timestamp.toLocal().day;

                  final isRight = msg.isFromAdmin;

                  return Column(
                    key: ValueKey('panel_msg_col_${msg.id}'),
                    children: [
                      if (isNewDay) _PanelDateDivider(date: msg.timestamp.toLocal()),
                      _ChatBubble(
                        key: ValueKey('panel_bubble_${msg.id}'),
                        message: msg,
                        isRight: isRight,
                        fallbackVendorName: conv.displayStallName,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedImageBytes != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.inputSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.subtleBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedImageBytes!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedImageName ?? 'Photo attached',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primaryText,
                                ),
                              ),
                              Text(
                                'Ready to send',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: colors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _clearSelectedImage,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: colors.mutedText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  // Paperclip attachment action button matching PalengkeGoApp composer
                  IconButton(
                    tooltip: 'Attach photo',
                    onPressed: _isPickingImage ? null : _pickImage,
                    icon: Icon(
                      Icons.attach_file_rounded,
                      size: 22,
                      color: colors.accent,
                    ),
                    splashRadius: 20,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(fontSize: 12.5, color: colors.primaryText),
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: _selectedImageBytes != null
                            ? 'Add a caption or press send...'
                            : 'Type admin message as Market Master...',
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
            _AvatarSmall(name: conversation.displayStallName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.displayStallName,
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
    super.key,
    required this.message,
    required this.isRight,
    this.fallbackVendorName,
  });

  final ChatMessage message;
  final bool isRight;
  final String? fallbackVendorName;

  /// Builds an attachment image using cached base64 bytes and gapless playback
  /// to prevent flickering when conversation streams rebuild.
  Widget _buildImageWidget(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('data:image')) {
      final bytes = ChatMessage.decodeBase64Image(url);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _brokenImagePlaceholder(),
        );
      }
      return _brokenImagePlaceholder();
    }
    return Image.network(
      url,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _brokenImagePlaceholder(),
    );
  }

  Widget _brokenImagePlaceholder() {
    return Container(
      width: 180,
      height: 120,
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 28),
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImageWidget(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachment(BuildContext context) {
    final url = message.attachmentUrl!;
    return GestureDetector(
      onTap: () => _openFullScreenImage(context, url),
      child: Container(
        margin: EdgeInsets.only(bottom: message.text.trim().isNotEmpty ? 6 : 2),
        constraints: const BoxConstraints(
          maxHeight: 200,
          minHeight: 100,
          minWidth: 140,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.black.withValues(alpha: .06),
        ),
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.passthrough,
          children: [
            _buildImageWidget(url, fit: BoxFit.cover),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.zoom_in_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

    // Display the vendor's store/sender name directly without a "Stall Holder (...)" wrapper
    final senderName = message.senderName.trim();
    final vendorLabel = (senderName.isNotEmpty &&
            senderName.toLowerCase() != 'stall holder')
        ? senderName
        : (fallbackVendorName?.trim().isNotEmpty == true
            ? fallbackVendorName!.trim()
            : 'Stall Holder');
    final roleLabel = isAdmin
        ? 'PalengkeGo Admin'
        : (isVendor ? vendorLabel : senderName);

    final timeStr = DateFormat('h:mm a').format(message.timestamp.toLocal());

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
            // Sender and Time at top of message
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isRight) ...[
                  Flexible(
                    child: Text(
                      roleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: colors.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: colors.mutedText,
                    ),
                  ),
                ] else ...[
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: isAdmin ? Colors.white.withValues(alpha: .8) : colors.mutedText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 12,
                    color: message.isRead ? Colors.white : Colors.white70,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            if (message.hasAttachment) _buildAttachment(context),
            if (message.text.trim().isNotEmpty)
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
