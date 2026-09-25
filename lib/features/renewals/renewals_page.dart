import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_controller.dart';
import '../../core/utils/export/admin_export_service.dart';
import '../../core/utils/export/module_export_data_builders.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/admin_shell.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../data/repositories/vendor_repository.dart';
import '../vendor_applications/verification_dialog.dart';

class RenewalsPage extends ConsumerStatefulWidget {
  const RenewalsPage({super.key});
  @override
  ConsumerState<RenewalsPage> createState() => _RenewalsPageState();
}

class _RenewalsPageState extends ConsumerState<RenewalsPage> {
  static const _viewedRenewalsPreference = 'renewals_viewed_new_badges';
  final search = TextEditingController();
  final tableScrollController = ScrollController();
  String status = 'All Statuses';
  String stallCategory = 'All Categories';
  bool history = false;
  bool _userSelectedTab = false;
  int page = 0;
  late Set<String> _viewedRenewalIds;

  @override
  void initState() {
    super.initState();
    _viewedRenewalIds = ref
            .read(sharedPreferencesProvider)
            .getStringList(_viewedRenewalsPreference)
            ?.toSet() ??
        <String>{};
  }

  void _markRenewalViewed(String id) {
    if (!_viewedRenewalIds.add(id)) return;
    setState(() {});
    ref.read(sharedPreferencesProvider).setStringList(
          _viewedRenewalsPreference,
          _viewedRenewalIds.toList(),
        );
  }

  @override
  void dispose() {
    search.dispose();
    tableScrollController.dispose();
    super.dispose();
  }

  void _resetTable() {
    setState(() => page = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && tableScrollController.hasClients) {
        tableScrollController.jumpTo(0);
      }
    });
  }

  void _goToPage(int value) {
    setState(() => page = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && tableScrollController.hasClients) {
        tableScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final renewals = ref.watch(renewalsProvider);
    final pendingCount = renewals
        .where((item) => item.status == RenewalStatus.reviewing)
        .length;
    final historyCount = renewals
        .where((item) => item.status != RenewalStatus.reviewing)
        .length;

    if (!_userSelectedTab && pendingCount == 0 && historyCount > 0) {
      history = true;
    }

    final categories = <String>{
      'All Categories',
      ...renewals.map((item) => item.category),
    }.toList()
      ..sort();
    categories
      ..remove('All Categories')
      ..insert(0, 'All Categories');
    final now = DateTime.now();
    final todayRenewals = renewals.where((item) {
      final date = item.submittedAt;
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    });
    final todayReviewing = todayRenewals.where(
      (item) => item.status == RenewalStatus.reviewing,
    );
    final Set<String> newRenewalIds;
    if (todayReviewing.isNotEmpty) {
      newRenewalIds = todayReviewing
          .map((item) => item.id)
          .where((id) => !_viewedRenewalIds.contains(id))
          .toSet();
    } else {
      final newestId = _newestRenewalId(renewals);
      newRenewalIds = newestId != null && !_viewedRenewalIds.contains(newestId)
          ? {newestId}
          : <String>{};
    }

    final values = renewals
        .where(
          (v) =>
              (search.text.trim().isEmpty ||
                  '${v.id} ${v.applicant} ${v.stallName}'
                      .toLowerCase()
                      .contains(search.text.trim().toLowerCase())) &&
              (status == 'All Statuses' || _status(v.status) == status) &&
              (stallCategory == 'All Categories' ||
                  v.category == stallCategory) &&
              (!history
                  ? v.status == RenewalStatus.reviewing
                  : v.status != RenewalStatus.reviewing),
        )
        .toList()
      ..sort((a, b) {
        final aDate = a.submittedAt ?? a.expiryDate;
        final bDate = b.submittedAt ?? b.expiryDate;
        return bDate.compareTo(aDate);
      });
    final int totalPages = (values.length / 10).ceil();
    final int safePage = totalPages == 0 ? 0 : page.clamp(0, totalPages - 1);
    final totalApproved = renewals
        .where((v) => v.status == RenewalStatus.approved)
        .length;
    final expiring = renewals.where((v) {
      final days = v.expiryDate.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 7;
    }).length;
    final expired = renewals
        .where((v) =>
            v.status == RenewalStatus.expired ||
            v.expiryDate.isBefore(DateTime.now()))
        .length;
    final hasActiveFilters = search.text.trim().isNotEmpty ||
        status != 'All Statuses' ||
        stallCategory != 'All Categories';

    final Widget emptyStateWidget;
    if (hasActiveFilters) {
      emptyStateWidget = const EmptyState(
        message: 'No results found',
        description: 'Try changing your search or filter selection.',
        icon: Icons.search_off_rounded,
      );
    } else if (!history) {
      emptyStateWidget = EmptyState(
        message: 'No pending renewal requests',
        description:
            'All renewal requests have been processed. Check Renewal History for past records.',
        icon: Icons.task_alt_rounded,
        action: OutlinedButton.icon(
          onPressed: () {
            setState(() {
              history = true;
              _userSelectedTab = true;
              status = 'All Statuses';
            });
            _resetTable();
          },
          icon: const Icon(Icons.history_rounded, size: 16),
          label: const Text('View Renewal History'),
          style: OutlinedButton.styleFrom(
            foregroundColor: semanticColors(context).accent,
            side: BorderSide(color: semanticColors(context).accent),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    } else {
      emptyStateWidget = const EmptyState(
        message: 'No renewal history found',
        description: 'No processed renewal requests recorded yet.',
        icon: Icons.history_rounded,
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageHeader(
          title: 'Renewal Management',
          subtitle:
              'Review and process annual stall renewal requests (Conducting every 1st week of January annually).',
          metrics: [
            MetricCardData(
              value: '${renewals.length}',
              label: 'Total Request',
              icon: Icons.assignment_outlined,
              accent: const Color(0xFF10B981),
              onTap: () {
                setState(() {
                  history = false;
                  _userSelectedTab = true;
                  status = 'All Statuses';
                });
                _resetTable();
              },
            ),
            MetricCardData(
              value: '$totalApproved',
              label: 'Approved Renewals',
              icon: Icons.verified_outlined,
              accent: const Color(0xFF6B7280),
              onTap: () {
                setState(() {
                  history = true;
                  _userSelectedTab = true;
                  status = 'Approved';
                });
                _resetTable();
              },
            ),
            MetricCardData(
              value: '$expiring',
              label: 'Expiring 7D',
              icon: Icons.alarm_outlined,
              accent: const Color(0xFFF59E0B),
              onTap: () {
                setState(() {
                  history = false;
                  _userSelectedTab = true;
                  status = 'Reviewing';
                });
                _resetTable();
              },
            ),
            MetricCardData(
              value: '$expired',
              label: 'Expired',
              icon: Icons.event_busy_outlined,
              accent: const Color(0xFFEF4444),
              onTap: () {
                setState(() {
                  history = true;
                  _userSelectedTab = true;
                  status = 'Expired';
                });
                _resetTable();
              },
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
            title: history ? 'Renewal History' : 'Renewal Requests',
            headerAction: _RenewalViewToggle(
              history: history,
              requestsCount: renewals
                  .where((item) => item.status == RenewalStatus.reviewing)
                  .length,
              historyCount: renewals
                  .where((item) => item.status != RenewalStatus.reviewing)
                  .length,
              onChanged: (value) {
                setState(() {
                  history = value;
                  _userSelectedTab = true;
                  status = 'All Statuses';
                });
                _resetTable();
              },
            ),
            child: Column(
              children: [
                Toolbar(
                  controller: search,
                  onChanged: (_) => _resetTable(),
                  onClear: () {
                    search.clear();
                    status = 'All Statuses';
                    stallCategory = 'All Categories';
                    history = false;
                    _resetTable();
                  },
                  trailing: [
                    _filter(
                      status,
                      const [
                        'All Statuses',
                        'Reviewing',
                        'Approved',
                        'Expired',
                      ],
                      (v) {
                        setState(() {
                          status = v;
                          if (v == 'Approved' || v == 'Expired') {
                            history = true;
                            _userSelectedTab = true;
                          } else if (v == 'Reviewing') {
                            history = false;
                            _userSelectedTab = true;
                          }
                        });
                        _resetTable();
                      },
                    ),
                    _filter(
                        stallCategory == 'All Categories'
                            ? 'Stall Category'
                            : stallCategory,
                        categories, (value) {
                      stallCategory = value;
                      _resetTable();
                    }),
                    ExportButton(
                      onExportPdf: () => _exportRenewals(
                        allRenewals: renewals,
                        filteredRenewals: values,
                        format: ExportFormat.pdf,
                      ),
                      onExportExcel: () => _exportRenewals(
                        allRenewals: renewals,
                        filteredRenewals: values,
                        format: ExportFormat.excel,
                      ),
                    ),
                  ],
                ),
                _Table(
                  history: history,
                  values: values.skip(safePage * 10).take(10).toList(),
                  newRenewalIds: newRenewalIds,
                  verticalController: tableScrollController,
                  emptyState: emptyStateWidget,
                  open: (v) {
                    _markRenewalViewed(v.id);
                    showBlurredDialog(
                      context,
                      (context) => VerificationDialog.renewal(v),
                    );
                  },
                ),
                if (values.isNotEmpty)
                  PaginationBar(
                    total: values.length,
                    start: safePage * 10 + 1,
                    end: ((safePage + 1) * 10).clamp(0, values.length).toInt(),
                    page: safePage,
                    pageCount: totalPages,
                    onPageChanged: _goToPage,
                    showSummary: search.text.trim().isNotEmpty,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filter(
    String label,
    List<String> values,
    ValueChanged<String> onChanged,
  ) =>
      FilterMenuButton(
        label: label,
        values: values,
        onSelected: onChanged,
      );

  Future<void> _exportRenewals({
    required List<RenewalRequest> allRenewals,
    required List<RenewalRequest> filteredRenewals,
    required ExportFormat format,
  }) async {
    final filterLabels = <String>[];
    if (search.text.trim().isNotEmpty) {
      filterLabels.add('Search: "${search.text.trim()}"');
    }
    filterLabels.add(status);
    filterLabels.add(stallCategory);

    final doc = RenewalExportData.build(
      allRenewals: allRenewals,
      filteredRenewals: filteredRenewals,
      activeFilters: filterLabels.join(' | '),
    );

    await AdminExportService.export(
      context: context,
      ref: ref,
      doc: doc,
      format: format,
    );
  }

  String _status(RenewalStatus value) => switch (value) {
        RenewalStatus.approved => 'Approved',
        RenewalStatus.reviewing => 'Reviewing',
        RenewalStatus.expired => 'Expired',
      };

  String? _newestRenewalId(List<RenewalRequest> values) {
    final reviewing = values
        .where((item) => item.status == RenewalStatus.reviewing)
        .toList();
    if (reviewing.isEmpty) return null;
    var newest = reviewing.first;
    for (final item in reviewing.skip(1)) {
      final itemDate = item.submittedAt ?? item.expiryDate;
      final newestDate = newest.submittedAt ?? newest.expiryDate;
      if (itemDate.isAfter(newestDate)) newest = item;
    }
    return newest.id;
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.history,
    required this.values,
    required this.newRenewalIds,
    required this.verticalController,
    required this.open,
    required this.emptyState,
  });
  final bool history;
  final List<RenewalRequest> values;
  final Set<String> newRenewalIds;
  final ScrollController verticalController;
  final ValueChanged<RenewalRequest> open;
  final Widget emptyState;
  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final rows = values.map((v) {
      final days = v.expiryDate.difference(DateTime.now()).inDays;
      return DataRow(
        onSelectChanged: (_) => open(v),
        cells: [
          DataCell(
            Text(
              v.id,
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          DataCell(
            Wrap(
              spacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AvatarCircle(name: v.applicant, size: 28),
                Text(v.applicant),
              ],
            ),
          ),
          DataCell(Text(v.stallName)),
          DataCell(CategoryBadge(category: v.category)),
          DataCell(
            history
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(shortDate.format(v.expiryDate)),
                      Text(
                        days < 0 ? 'Expired ${days.abs()}d ago' : '$days days left',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight:
                              (days <= 3 || days < 0) ? FontWeight.w800 : FontWeight.w500,
                          color: (days <= 3 || days < 0)
                              ? colors.danger
                              : days <= 7
                                  ? colors.warning
                                  : colors.mutedText,
                        ),
                      ),
                    ],
                  )
                : Text(shortDate.format(v.submittedAt ?? DateTime.now())),
          ),
          DataCell(
            StatusBadge(
              label: switch (v.status) {
                RenewalStatus.reviewing => 'Under Review',
                RenewalStatus.approved => 'Verified',
                RenewalStatus.expired => 'Expired',
              },
              kind: v.status == RenewalStatus.approved
                  ? BadgeKind.success
                  : v.status == RenewalStatus.reviewing
                      ? BadgeKind.info
                      : BadgeKind.danger,
            ),
          ),
          DataCell(
            TableActionReviewButton(
              label: history ? 'View Details' : 'Review',
              tooltip: history ? 'View renewal details' : 'Review renewal request',
              onPressed: () => open(v),
            ),
          ),
        ],
      );
    }).toList();

    return ScrollableDataTable(
      verticalController: verticalController,
      minWidth: 1500,
      columnSpacing: 18,
      emptyState: emptyState,
      columns: [
        const DataColumn(
          columnWidth: FlexColumnWidth(1.25),
          label: Text('RENEWAL ID'),
        ),
        const DataColumn(
          columnWidth: FlexColumnWidth(1.25),
          label: Text('STALL HOLDER'),
        ),
        const DataColumn(
          columnWidth: FlexColumnWidth(1.35),
          label: Text('STALL NAME'),
        ),
        const DataColumn(
          columnWidth: FlexColumnWidth(0.95),
          label: Text('CATEGORY'),
        ),
        DataColumn(
          columnWidth: const FlexColumnWidth(1.25),
          label: Text(history ? 'EXPIRY DATE' : 'DATE SUBMITTED'),
        ),
        const DataColumn(
          columnWidth: FlexColumnWidth(1.75),
          label: Text('RENEWAL STATUS'),
        ),
        const DataColumn(
          columnWidth: FlexColumnWidth(0.8),
          label: Text('ACTIONS'),
        ),
      ],
      rows: rows,
    );
  }
}

class _RenewalViewToggle extends StatelessWidget {
  const _RenewalViewToggle({
    required this.history,
    required this.requestsCount,
    required this.historyCount,
    required this.onChanged,
  });

  final bool history;
  final int requestsCount;
  final int historyCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    return SegmentedButton<bool>(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFD1FAE5);
          }
          if (states.contains(WidgetState.hovered)) {
            return colors.hoverSurface;
          }
          return colors.cardBackground;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF065F46);
          }
          return colors.secondaryText;
        }),
        textStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF065F46);
          }
          return colors.secondaryText;
        }),
        side: WidgetStatePropertyAll(
          BorderSide(color: colors.subtleBorder),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        elevation: const WidgetStatePropertyAll(0),
        mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
      ),
      segments: [
        ButtonSegment<bool>(
          value: false,
          label: Text('Requests ($requestsCount)'),
          icon: const Icon(Icons.assignment_outlined, size: 15),
        ),
        ButtonSegment<bool>(
          value: true,
          label: Text('Renewal History ($historyCount)'),
          icon: const Icon(Icons.history_rounded, size: 15),
        ),
      ],
      selected: {history},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
