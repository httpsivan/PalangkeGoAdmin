import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/notification_repository.dart';
import '../../models/admin_notification.dart';
import '../animations/app_motion.dart';
import 'admin_widgets.dart';

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  @override
  void dispose() {
    super.dispose();
  }

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
    final width = screen.width < 600 ? screen.width - 24 : 400.0;
    final height = (screen.height * (screen.width < 600 ? .78 : .72))
        .clamp(320.0, 520.0)
        .toDouble();
    final right = (screen.width - (anchor.dx + renderObject.size.width))
        .clamp(12.0, screen.width - width - 12)
        .toDouble();

    setState(() => _isOpen = true);
    showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Close notifications',
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
                  child: _NotificationPanel(
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
    final unread =
        ref.watch(notificationProvider).where((item) => !item.isRead).length;
    final colors = semanticColors(context);
    return Stack(
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
                  key: ValueKey('bell-$unread'),
                  Icons.notifications_none_rounded,
                  size: 20,
                  color: colors.heroForeground,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: -1,
          top: -1,
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.component),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: unread <= 0
                ? const SizedBox.shrink(key: ValueKey('no-unread'))
                : Container(
                    key: ValueKey('unread-$unread'),
                    constraints:
                        const BoxConstraints(minWidth: 8, minHeight: 8),
                    padding: unread > 9
                        ? const EdgeInsets.symmetric(horizontal: 3, vertical: 1)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: colors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.heroBackground,
                        width: 1.5,
                      ),
                    ),
                    child: unread > 9
                        ? Text(
                            unread > 99 ? '99+' : '$unread',
                            style: TextStyle(
                              color: colors.heroForeground,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
          ),
        ),
      ],
    );
  }
}

class _NotificationPanel extends ConsumerStatefulWidget {
  const _NotificationPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends ConsumerState<_NotificationPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 180),
  )..forward();
  NotificationFilter filter = NotificationFilter.all;
  bool closing = false;

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void close() {
    if (closing) return;
    closing = true;
    _animation.reverse().whenCompleteOrCancel(widget.onClose);
  }

  void _navigate(AdminNotification item) {
    ref.read(notificationProvider.notifier).markRead(item.id);
    close();
    if (item.destination != null) context.go(item.destination!);
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final notifications = ref.watch(notificationProvider);
    final visible = notifications
        .where((item) => filter == NotificationFilter.all || !item.isRead)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final unread = notifications.where((item) => !item.isRead).length;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        SingleActivator(LogicalKeyboardKey.escape): close,
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
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.subtleBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _header(context, unread),
                    _filters(context),
                    Divider(height: 1, color: colors.subtleBorder),
                    Expanded(
                      child: visible.isEmpty
                          ? _emptyState(context)
                          : Builder(
                              builder: (context) {
                                final items = _groupedItems(context, visible);
                                return ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) => items[index],
                                );
                              },
                            ),
                    ),
                    _footer(context, notifications),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, int unread) {
    final colors = semanticColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 7),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  color: colors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.dangerContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$unread unread',
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
                tooltip: 'Close notifications',
                onPressed: close,
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                unread == 0
                    ? 'You are all caught up'
                    : '$unread unread notifications',
                style: TextStyle(fontSize: 11, color: colors.secondaryText),
              ),
              const Spacer(),
              TextButton(
                onPressed: unread == 0
                    ? null
                    : () =>
                        ref.read(notificationProvider.notifier).markAllRead(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 28),
                ),
                child: const Text('Mark all as read',
                    style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 1, 16, 9),
        child: Row(
          children: [
            _filterTab(context, 'All', NotificationFilter.all),
            const SizedBox(width: 7),
            _filterTab(context, 'Unread', NotificationFilter.unread),
          ],
        ),
      );

  Widget _filterTab(
    BuildContext context,
    String label,
    NotificationFilter value,
  ) {
    final selected = filter == value;
    final colors = semanticColors(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.accentDark : colors.hoverSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colors.heroForeground : colors.secondaryText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  List<Widget> _groupedItems(
    BuildContext context,
    List<AdminNotification> items,
  ) {
    final today = <AdminNotification>[];
    final earlier = <AdminNotification>[];
    final now = DateTime.now();
    for (final item in items) {
      final isToday = item.createdAt.year == now.year &&
          item.createdAt.month == now.month &&
          item.createdAt.day == now.day;
      (isToday ? today : earlier).add(item);
    }
    return [
      if (today.isNotEmpty) ...[
        _groupLabel('TODAY'),
        for (final item in today) _item(context, item),
      ],
      if (earlier.isNotEmpty) ...[
        _groupLabel('EARLIER'),
        for (final item in earlier) _item(context, item),
      ],
    ];
  }

  Widget _groupLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 7),
        child: Text(
          label,
          style: TextStyle(
            color: semanticColors(context).secondaryText,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
      );

  Widget _item(BuildContext context, AdminNotification item) {
    final colors = semanticColors(context);
    final icon = _icon(item.type);
    final color = _iconColor(context, item.type);
    return _HoverCard(
      margin: const EdgeInsets.only(bottom: 7),
      color: item.isRead ? Colors.transparent : colors.selectedSurface,
      borderColor: item.isRead ? colors.subtleBorder : Colors.transparent,
      onTap: () => _navigate(item),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: colors.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(top: 4, left: 6),
                          decoration: BoxDecoration(
                            color: colors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.secondaryText,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        _relativeTime(item.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.secondaryText,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Dismiss notification',
                        onPressed: () => ref
                            .read(notificationProvider.notifier)
                            .dismiss(item.id),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 24, minHeight: 24),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: colors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  if (item.actionLabel != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _navigate(item),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.only(top: 2, right: 6),
                          minimumSize: const Size(0, 26),
                        ),
                        child: Text(
                          item.actionLabel!,
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final unread = filter == NotificationFilter.unread;
    final colors = semanticColors(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              unread
                  ? Icons.mark_email_read_outlined
                  : Icons.notifications_none_rounded,
              size: 42,
              color: colors.secondaryText,
            ),
            const SizedBox(height: 10),
            Text(
              unread ? 'No unread notifications' : 'You\'re all caught up',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              'There are no new notifications right now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, List<AdminNotification> items) {
    final hasRead = items.any((item) => item.isRead);
    final colors = semanticColors(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.subtleBorder)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: hasRead
                ? () => ref.read(notificationProvider.notifier).clearRead()
                : null,
            child: const Text('Clear read', style: TextStyle(fontSize: 11)),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () {
              close();
              context.go('/notifications');
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              backgroundColor: colors.accentDark,
              foregroundColor: colors.heroForeground,
            ),
            child: const Text(
              'View All Notifications',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(NotificationType type) {
    switch (type) {
      case NotificationType.vendorApplication:
        return Icons.assignment_turned_in_outlined;
      case NotificationType.accountUpdate:
        return Icons.gpp_bad_outlined;
      case NotificationType.renewal:
        return Icons.autorenew_rounded;
      case NotificationType.customer:
        return Icons.person_add_alt_1_outlined;
      case NotificationType.report:
        return Icons.bar_chart_rounded;
      case NotificationType.system:
        return Icons.info_outline_rounded;
    }
  }

  Color _iconColor(BuildContext context, NotificationType type) {
    final colors = semanticColors(context);
    switch (type) {
      case NotificationType.vendorApplication:
        return colors.success;
      case NotificationType.accountUpdate:
        return colors.danger;
      case NotificationType.renewal:
        return colors.warning;
      case NotificationType.customer:
        return colors.info;
      case NotificationType.report:
        return const Color(0xFF8B5CF6);
      case NotificationType.system:
        return colors.mutedText;
    }
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} minutes ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays == 1) return 'Yesterday';
    return '${difference.inDays} days ago';
  }
}

enum NotificationFilter { all, unread }

class _HoverCard extends StatefulWidget {
  const _HoverCard({
    required this.child,
    required this.onTap,
    required this.color,
    required this.borderColor,
    this.margin,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final Color borderColor;
  final EdgeInsets? margin;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) => Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          color: hovering ? semanticColors(context).hoverSurface : widget.color,
          border: Border.all(color: widget.borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: MouseRegion(
          onEnter: (_) => setState(() => hovering = true),
          onExit: (_) => setState(() => hovering = false),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: widget.child,
          ),
        ),
      );
}
