import 'dart:convert';
import 'dart:typed_data';

import '../../core/theme/theme_extensions.dart';
import 'package:file_picker/file_picker.dart';
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
      final text = c.lastMessageText.trim();
      if (text.isEmpty || text.toLowerCase() == 'no messages yet') {
        return false;
      }
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
                  onPressed: () => setState(() {
                    _selectedConversation = null;
                    _lastScrolledConversationId = null;
                    _lastScrolledMessageCount = 0;
                  }),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    key: ValueKey('msg_col_${msg.id}'),
                    children: [
                      if (isNewDay) _DateDivider(date: msg.timestamp.toLocal()),
                      _FullChatBubble(
                        key: ValueKey('bubble_${msg.id}'),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedImageBytes != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
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
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                        const SizedBox(width: 10),
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ready to send',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: colors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _clearSelectedImage,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
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
                  Tooltip(
                    message: 'Attach Photo',
                    child: Material(
                      color: colors.inputSurface,
                      shape: CircleBorder(
                        side: BorderSide(color: colors.subtleBorder),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isPickingImage ? null : _pickImage,
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 20,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(fontSize: 13, color: colors.primaryText),
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: _selectedImageBytes != null
                            ? 'Add a caption or press send...'
                            : 'Type response as PalengkeGo Market Admin...',
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
    super.key,
    required this.message,
    required this.isRight,
  });

  final ChatMessage message;
  final bool isRight;

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
      width: 220,
      height: 140,
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 32),
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
          maxHeight: 240,
          minHeight: 120,
          minWidth: 160,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
                  size: 15,
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

    final roleLabel = isAdmin
        ? 'PalengkeGo Market Admin'
        : (isVendor ? 'Stall Holder (${message.senderName})' : message.senderName);

    final timeStr = DateFormat('h:mm a').format(message.timestamp.toLocal());

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
                  const SizedBox(width: 5),
                  Icon(
                    message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 13,
                    color: message.isRead ? Colors.white : Colors.white70,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            if (message.hasAttachment) _buildAttachment(context),
            if (message.text.trim().isNotEmpty)
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
