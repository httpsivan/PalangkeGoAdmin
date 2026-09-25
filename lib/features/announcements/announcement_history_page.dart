import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/export/admin_export_service.dart';
import '../../core/utils/export/module_export_data_builders.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/admin_shell.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/widgets/formatted_text.dart';
import '../../data/repositories/announcements_repository.dart';
import 'announcement_dialog.dart';

class AnnouncementHistoryPage extends ConsumerStatefulWidget {
  const AnnouncementHistoryPage({super.key});

  @override
  ConsumerState<AnnouncementHistoryPage> createState() =>
      _AnnouncementHistoryPageState();
}

class _AnnouncementHistoryPageState
    extends ConsumerState<AnnouncementHistoryPage> {
  final search = TextEditingController();
  final scrollController = ScrollController();
  String selectedAudience = 'All Audiences';
  String selectedStatus = 'All Statuses';
  String selectedSort = 'Newest First';
  int page = 0;

  @override
  void dispose() {
    search.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _resetPagination() {
    setState(() => page = 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final announcements = ref.watch(announcementsProvider);

    // Metrics calculations
    final totalCount = announcements.length;
    final deliveredCount = announcements
        .where((a) => a.state == 'Sent' || (!a.isDraft && a.deliveredCount > 0))
        .length;
    final draftOrQueuedCount = announcements
        .where((a) => a.isDraft || a.state == 'Draft' || a.state == 'Queued locally')
        .length;

    // Filtered & sorted list
    final filtered = announcements.where((item) {
      final query = search.text.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          item.id.toLowerCase().contains(query) ||
          item.title.toLowerCase().contains(query) ||
          item.summary.toLowerCase().contains(query) ||
          item.createdBy.toLowerCase().contains(query);

      final matchesAudience = selectedAudience == 'All Audiences' ||
          item.audience.toLowerCase() == selectedAudience.toLowerCase() ||
          (selectedAudience == 'Stall Holders' &&
              item.audience.toLowerCase() == 'vendors');

      final matchesStatus = selectedStatus == 'All Statuses' ||
          (selectedStatus == 'Sent' &&
              (item.state == 'Sent' || (!item.isDraft && item.state != 'Draft'))) ||
          (selectedStatus == 'Draft' && (item.isDraft || item.state == 'Draft')) ||
          (selectedStatus == 'Queued' && item.state == 'Queued locally');

      return matchesQuery && matchesAudience && matchesStatus;
    }).toList();

    // Sort
    if (selectedSort == 'Oldest First') {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    const pageSize = 15;
    final totalPages = (filtered.length / pageSize).ceil();
    final safePage = totalPages == 0 ? 0 : page.clamp(0, totalPages - 1);
    final visible = filtered.skip(safePage * pageSize).take(pageSize).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageHeader(
          title: 'Announcement History',
          subtitle:
              'Review broadcast logs, delivery performance, audience reach, and scheduled notices.',
          trailing: FilledButton.icon(
            onPressed: () => showBlurredDialog(
              context,
              (_) => const AnnouncementDialog(),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'New Announcement',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F4A3C),
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          metrics: [
            MetricCardData(
              value: '$totalCount',
              label: 'Total Announcements',
              icon: Icons.campaign_outlined,
              accent: const Color(0xFF10B981),
            ),
            MetricCardData(
              value: '$deliveredCount',
              label: 'Delivered Notices',
              icon: Icons.mark_email_read_outlined,
              accent: const Color(0xFF3B82F6),
            ),
            MetricCardData(
              value: '$draftOrQueuedCount',
              label: 'Drafts & Queued',
              icon: Icons.edit_note_rounded,
              accent: const Color(0xFFF59E0B),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.horizontalPadding(context),
            26,
            Responsive.horizontalPadding(context),
            36,
          ),
          child: DataPanel(
            title: 'Broadcast Log',
            headerAction: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExportButton(
                  onExportPdf: () => _exportAnnouncements(
                    allAnnouncements: announcements,
                    filteredAnnouncements: filtered,
                    format: ExportFormat.pdf,
                  ),
                  onExportExcel: () => _exportAnnouncements(
                    allAnnouncements: announcements,
                    filteredAnnouncements: filtered,
                    format: ExportFormat.excel,
                  ),
                ),
              ],
            ),
            child: Column(
              children: [
                Toolbar(
                  controller: search,
                  searchHint: 'Search announcement title, body, or ID...',
                  onChanged: (_) => _resetPagination(),
                  onClear: () => setState(() {
                    search.clear();
                    selectedAudience = 'All Audiences';
                    selectedStatus = 'All Statuses';
                    selectedSort = 'Newest First';
                    _resetPagination();
                  }),
                  trailing: [
                    FilterMenuButton(
                      label: selectedAudience,
                      values: const [
                        'All Audiences',
                        'All Users',
                        'Stall Holders',
                        'Customers',
                      ],
                      onSelected: (value) {
                        setState(() => selectedAudience = value);
                        _resetPagination();
                      },
                    ),
                    FilterMenuButton(
                      label: selectedStatus,
                      values: const [
                        'All Statuses',
                        'Sent',
                        'Draft',
                        'Queued',
                      ],
                      onSelected: (value) {
                        setState(() => selectedStatus = value);
                        _resetPagination();
                      },
                    ),
                    FilterMenuButton(
                      label: selectedSort,
                      values: const [
                        'Newest First',
                        'Oldest First',
                      ],
                      onSelected: (value) {
                        setState(() => selectedSort = value);
                        _resetPagination();
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        search.clear();
                        selectedAudience = 'All Audiences';
                        selectedStatus = 'All Statuses';
                        selectedSort = 'Newest First';
                        _resetPagination();
                      }),
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: const Text(
                        'Clear Filters',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                ScrollableDataTable(
                  columns: const [
                    DataColumn(label: Text('DATE & TIME')),
                    DataColumn(label: Text('ANNOUNCEMENT')),
                    DataColumn(label: Text('AUDIENCE')),
                    DataColumn(label: Text('CHANNEL')),
                    DataColumn(label: Text('DURATION')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('ACTIONS')),
                  ],
                  rows: visible
                      .map(
                        (item) => DataRow(
                          onSelectChanged: (_) => _showDetails(item),
                          cells: [
                            // Date & Time
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    longDate.format(item.createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    relativeTime(item.createdAt),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: colors.mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Announcement Title & Excerpt
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 320),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    FormattedText(
                                      item.summary,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Audience
                            DataCell(
                              StatusBadge(
                                label: (item.audience.toLowerCase() == 'vendors' ||
                                        item.audience.toLowerCase() == 'stall holders')
                                    ? 'Stall Holders'
                                    : item.audience,
                                kind: switch (item.audience.toLowerCase()) {
                                  'vendors' || 'stall holders' => BadgeKind.info,
                                  'customers' => BadgeKind.warning,
                                  _ => BadgeKind.success,
                                },
                              ),
                            ),
                            // Channel
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.notificationType.contains('Push')
                                        ? Icons.notifications_active_outlined
                                        : Icons.chat_bubble_outline_rounded,
                                    size: 14,
                                    color: colors.mutedText,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.notificationType,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            // Duration
                            DataCell(
                              Text(
                                formatAnnouncementDuration(
                                  item.createdAt,
                                  item.expiresAt,
                                ),
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                            // Status
                            DataCell(
                              StatusBadge(
                                label: item.isDraft
                                    ? 'Draft'
                                    : (item.state.isEmpty ? 'Sent' : item.state),
                                kind: item.isDraft || item.state == 'Draft'
                                    ? BadgeKind.neutral
                                    : (item.state == 'Queued locally'
                                        ? BadgeKind.warning
                                        : BadgeKind.success),
                              ),
                            ),
                            // Actions
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TableActionIconButton(
                                    tooltip: 'View Details',
                                    icon: Icons.visibility_outlined,
                                    onPressed: () => _showDetails(item),
                                  ),
                                  const SizedBox(width: 4),
                                  TableActionIconButton(
                                    tooltip: 'Edit Announcement',
                                    icon: Icons.edit_outlined,
                                    onPressed: () => _editAnnouncement(item),
                                  ),
                                  const SizedBox(width: 4),
                                  TableActionIconButton(
                                    tooltip: 'Delete Announcement',
                                    icon: Icons.delete_outline_rounded,
                                    color: colors.danger,
                                    onPressed: () => _confirmDelete(item),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                  verticalController: scrollController,
                  minWidth: 1040,
                  emptyState: const EmptyState(
                    message: 'No announcements match the selected criteria.',
                  ),
                ),
                if (filtered.isNotEmpty)
                  PaginationBar(
                    total: filtered.length,
                    start: safePage * pageSize + 1,
                    end: ((safePage + 1) * pageSize).clamp(0, filtered.length),
                    page: safePage,
                    pageCount: totalPages,
                    onPageChanged: (value) => setState(() => page = value),
                    showSummary: search.text.trim().isNotEmpty,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDetails(Announcement item) async {
    final action = await showBlurredDialog<String>(
      context,
      (dialogCtx) => _AnnouncementDetailDialog(
        announcement: item,
        onEdit: () => Navigator.of(dialogCtx).pop('edit'),
        onDelete: () => Navigator.of(dialogCtx).pop('delete'),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      _editAnnouncement(item);
    } else if (action == 'delete') {
      _confirmDelete(item);
    }
  }

  void _editAnnouncement(Announcement item) {
    showBlurredDialog(
      context,
      (_) => AnnouncementDialog(
        announcementToEdit: item,
      ),
    );
  }

  void _confirmDelete(Announcement item) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text(
          'Are you sure you want to delete "${item.title}" from announcement history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        ref.read(announcementsRepositoryProvider).deleteAnnouncement(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Announcement "${item.title}" has been deleted.'),
          ),
        );
      }
    });
  }

  Future<void> _exportAnnouncements({
    required List<Announcement> allAnnouncements,
    required List<Announcement> filteredAnnouncements,
    required ExportFormat format,
  }) async {
    final filterLabels = <String>[];
    if (search.text.trim().isNotEmpty) {
      filterLabels.add('Search: "${search.text.trim()}"');
    }
    filterLabels.add(selectedAudience);
    filterLabels.add(selectedStatus);
    filterLabels.add(selectedSort);

    final doc = AnnouncementExportData.build(
      allAnnouncements: allAnnouncements,
      filteredAnnouncements: filteredAnnouncements,
      activeFilters: filterLabels.join(' | '),
    );

    await AdminExportService.export(
      context: context,
      ref: ref,
      doc: doc,
      format: format,
    );
  }
}

class _AnnouncementDetailDialog extends StatelessWidget {
  const _AnnouncementDetailDialog({
    required this.announcement,
    required this.onEdit,
    required this.onDelete,
  });

  final Announcement announcement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final isDraft =
        announcement.isDraft || announcement.state.toLowerCase() == 'draft';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.infoContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.info.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      color: colors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              announcement.id.isEmpty
                                  ? 'Announcement Details'
                                  : announcement.id,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(
                              label: isDraft ? 'Draft' : announcement.state,
                              kind: isDraft
                                  ? BadgeKind.neutral
                                  : (announcement.state == 'Queued locally'
                                      ? BadgeKind.warning
                                      : BadgeKind.success),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Created by ${announcement.createdBy.isEmpty ? "Admin" : announcement.createdBy} • ${longDate.format(announcement.createdAt)} (${relativeTime(announcement.createdAt)})',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 16),

              // Title
              Text(
                announcement.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),

              // Feature Image if present
              if (announcement.imageBytes != null ||
                  (announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty)) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.subtleBorder),
                    ),
                    child: announcement.imageBytes != null
                        ? Image.memory(
                            announcement.imageBytes!,
                            fit: BoxFit.cover,
                          )
                        : Image.asset(
                            announcement.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.network(
                              announcement.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.campaign_outlined,
                                size: 48,
                                color: colors.accent,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Metadata Cards Row
              Row(
                children: [
                  Expanded(
                    child: _metaCard(
                      context,
                      icon: Icons.people_alt_outlined,
                      label: 'Target Audience',
                      value: announcement.audience,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metaCard(
                      context,
                      icon: Icons.notifications_none_rounded,
                      label: 'Notification Channel',
                      value: announcement.notificationType,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Body Message
              const Text(
                'Message Content',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.tableHeader,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.subtleBorder),
                ),
                child: FormattedSelectableText(
                  announcement.summary,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Actions
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.danger,
                      side: BorderSide(
                        color: colors.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete'),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colors = semanticColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.tableHeader,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: colors.mutedText),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: colors.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String formatAnnouncementDuration(DateTime createdAt, DateTime? expiresAt) {
  if (expiresAt == null) return 'Permanent';
  final diff = expiresAt.difference(createdAt);
  final days = diff.inDays;
  if (days <= 1) return '1 Day';
  if (days <= 3) return '3 Days';
  if (days <= 7) return '7 Days';
  if (days <= 14) return '14 Days';
  if (days <= 30) return '30 Days';
  return '$days Days';
}
