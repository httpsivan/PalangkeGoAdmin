import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_messaging_repository.dart';
import '../../features/messages/messages_panel.dart';
import '../animations/app_motion.dart';
import 'admin_widgets.dart';

class MessagesBell extends ConsumerStatefulWidget {
  const MessagesBell({super.key});

  @override
  ConsumerState<MessagesBell> createState() => _MessagesBellState();
}

class _MessagesBellState extends ConsumerState<MessagesBell> {
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  void _toggle() {
    if (isOpen) return;
    _open();
  }

  void _open() {
    if (_isOpen) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final screen = MediaQuery.sizeOf(context);
    final anchor = renderObject.localToGlobal(Offset.zero);
    final width = screen.width < 600 ? screen.width - 24 : 440.0;
    final height = (screen.height * (screen.width < 600 ? .78 : .72))
        .clamp(360.0, 560.0)
        .toDouble();
    final right = (screen.width - (anchor.dx + renderObject.size.width))
        .clamp(12.0, screen.width - width - 12)
        .toDouble();

    setState(() => _isOpen = true);
    showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Close messages',
      barrierColor: Colors.transparent,
      transitionDuration: AppMotion.duration(context, AppMotion.menu),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SizedBox.expand(
          child: Stack(
            children: [
              Positioned(
                top: anchor.dy + renderObject.size.height + 10,
                right: right,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: MessagesPanel(
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.easeOut,
        );
        if (AppMotion.reducedMotion(context)) {
          return FadeTransition(opacity: curved, child: child);
        }
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: .96, end: 1).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -.015),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _isOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(adminUnreadMessagesCountProvider);
    final colors = semanticColors(context);

    return Tooltip(
      message: unread > 0 ? 'Messages ($unread new)' : 'Messages',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: isOpen ? colors.navigationHover : colors.navigationControl,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _toggle,
              hoverColor: colors.navigationHover,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 38,
                height: 38,
                child: AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.component),
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: AppMotion.easeOut,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: .86, end: 1).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    key: ValueKey('msg-bell-$unread'),
                    Icons.chat_bubble_outline_rounded,
                    size: 19,
                    color: colors.heroForeground,
                  ),
                ),
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              right: -1,
              top: -1,
              child: AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.component),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Container(
                  key: ValueKey('badge-$unread'),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.danger,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colors.heroBackground,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
