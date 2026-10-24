import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/admin_widgets.dart';
import '../../data/repositories/notification_repository.dart';
import '../../models/admin_notification.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = semanticColors(context);
    final notifications = [...ref.watch(notificationProvider)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final controller = ref.read(notificationProvider.notifier);
    return Column(
      children: [
        const PageHeader(
          title: 'Notifications',
          subtitle: 'Review system updates and account activity.',
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.horizontalPadding(context),
              20,
              Responsive.horizontalPadding(context),
              28,
            ),
            child: DataPanel(
              title: 'All Notifications',
              headerAction: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: notifications.any((item) => !item.isRead)
                        ? controller.markAllRead
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.secondaryText,
                      backgroundColor: colors.hoverSurface,
                      side: BorderSide(color: colors.subtleBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.done_all_rounded, size: 15),
                    label: const Text(
                      'Mark all as read',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: notifications.any((item) => item.isRead)
                        ? controller.clearRead
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.secondaryText,
                      backgroundColor: colors.hoverSurface,
                      side: BorderSide(color: colors.subtleBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.clear_all_rounded, size: 15),
                    label: const Text(
                      'Clear read',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              child: Expanded(
                child: notifications.isEmpty
                    ? Center(
                        child: Text(
                          'You\'re all caught up',
                          style: TextStyle(color: colors.secondaryText),
                        ),
                      )
                    : Scrollbar(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = notifications[index];
                            final typeColor = _typeColor(context, item.type);
                            return Material(
                              color: item.isRead
                                  ? colors.elevatedSurface
                                  : colors.selectedSurface,
                              borderRadius: BorderRadius.circular(10),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: colors.subtleBorder),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      typeColor.withValues(alpha: .13),
                                  foregroundColor: typeColor,
                                  child: Icon(_typeIcon(item.type), size: 18),
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    color: colors.primaryText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  item.message,
                                  style: TextStyle(color: colors.secondaryText),
                                ),
                                trailing: Wrap(
                                  spacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (!item.isRead)
                                      TableActionIconButton(
                                        tooltip: 'Mark as read',
                                        icon: Icons.done_rounded,
                                        onPressed: () =>
                                            controller.markRead(item.id),
                                      ),
                                    TableActionIconButton(
                                      tooltip: 'Dismiss notification',
                                      icon: Icons.close_rounded,
                                      onPressed: () =>
                                          controller.dismiss(item.id),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  controller.markRead(item.id);
                                  if (item.destination != null) {
                                    context.go(item.destination!);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _typeIcon(NotificationType type) {
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

  Color _typeColor(BuildContext context, NotificationType type) {
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
}
