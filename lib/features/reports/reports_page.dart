import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_controller.dart';
import '../../core/utils/csv_exporter.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/admin_shell.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../data/repositories/mock_repository.dart';
import '../../models/app_models.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  static const _viewedReportsPreference = 'reports_viewed_new_badges';
  final search = TextEditingController();
  final tableScrollController = ScrollController();
  String status = 'All Statuses';
  String stallCategory = 'All Categories';
  String targetType = 'All Types';
  bool history = false;
  int page = 0;
  late Set<String> _viewedReportIds;

  @override
  void initState() {
    super.initState();
    _viewedReportIds = ref
            .read(sharedPreferencesProvider)
            .getStringList(_viewedReportsPreference)
            ?.toSet() ??
        <String>{};
  }

  void _markReportViewed(String id) {
    if (!_viewedReportIds.add(id)) return;
    setState(() {});
    ref.read(sharedPreferencesProvider).setStringList(
          _viewedReportsPreference,
          _viewedReportIds.toList(),
        );
  }

  String? _newestReportId(List<Report> values) {
    final pending =
        values.where((item) => item.status == ReportStatus.pending).toList();
    if (pending.isEmpty) {
      final active =
          values.where((item) => item.status != ReportStatus.resolved).toList();
      if (active.isEmpty) return null;
      var newest = active.first;
      for (final item in active.skip(1)) {
        if (item.date.isAfter(newest.date)) newest = item;
      }
      return newest.id;
    }
    var newest = pending.first;
    for (final item in pending.skip(1)) {
      if (item.date.isAfter(newest.date)) newest = item;
    }
    return newest.id;
  }

  bool _isStallHolderReport(Report item) =>
      item.type == 'Stall Holder' || item.type == 'Vendor';

  bool _isCustomerReport(Report item) => item.type == 'Customer';

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
    final appData = ref.watch(
      appDataProvider.select(
        (s) => (reports: s.reports, vendors: s.vendors, customers: s.customers),
      ),
    );
    final reports = appData.reports;
    final selectedCategory = stallCategory;
    final categories = <String>{
      'All Categories',
      ...reports.map((item) => item.category ?? 'FRUITS'),
    }.toList()
      ..sort();
    categories
      ..remove('All Categories')
      ..insert(0, 'All Categories');
    final values = reports
        .where(
          (item) =>
              (history
                  ? item.status == ReportStatus.resolved
                  : item.status != ReportStatus.resolved) &&
              (targetType == 'All Types' ||
                  (targetType == 'Stall Holders' &&
                      _isStallHolderReport(item)) ||
                  (targetType == 'Customers' && _isCustomerReport(item))) &&
              (search.text.trim().isEmpty ||
                  '${item.id} ${item.accountIssue} ${item.submittedBy} ${item.reason}'
                      .toLowerCase()
                      .contains(search.text.trim().toLowerCase())) &&
              (status == 'All Statuses' || enumLabel(item.status) == status) &&
              (selectedCategory == 'All Categories' ||
                  (item.category ?? 'FRUITS') == selectedCategory),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final now = DateTime.now();
    final todayReports = reports.where(
      (item) =>
          item.status != ReportStatus.resolved &&
          item.date.year == now.year &&
          item.date.month == now.month &&
          item.date.day == now.day,
    );
    final todayPending = todayReports.where(
      (item) => item.status == ReportStatus.pending,
    );
    final Set<String> newReportIds;
    if (todayPending.isNotEmpty) {
      newReportIds = todayPending
          .map((item) => item.id)
          .where((id) => !_viewedReportIds.contains(id))
          .toSet();
    } else if (todayReports.isNotEmpty) {
      newReportIds = todayReports
          .map((item) => item.id)
          .where((id) => !_viewedReportIds.contains(id))
          .toSet();
    } else {
      final newestId = _newestReportId(reports);
      newReportIds = newestId != null && !_viewedReportIds.contains(newestId)
          ? {newestId}
          : <String>{};
    }
    final int totalPages = (values.length / 10).ceil();
    final int safePage = totalPages == 0 ? 0 : page.clamp(0, totalPages - 1);

    final filteredForMetrics = targetType == 'All Types'
        ? reports
        : targetType == 'Stall Holders'
            ? reports.where(_isStallHolderReport).toList()
            : reports.where(_isCustomerReport).toList();

    final blockedCount = targetType == 'All Types'
        ? appData.vendors
                .where((item) => item.status == AccountStatus.blocked)
                .length +
            appData.customers
                .where((item) => item.status == AccountStatus.blocked)
                .length
        : targetType == 'Stall Holders'
            ? appData.vendors
                .where((item) => item.status == AccountStatus.blocked)
                .length
            : appData.customers
                .where((item) => item.status == AccountStatus.blocked)
                .length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageHeader(
          title: 'Reports Management',
          subtitle:
              'Review and manage customer reports, stall holder violations, and application support requests submitted from the PalengkeGo mobile application.',
          tabs: _ReportTabs(
            selected: targetType,
            onChanged: (value) {
              setState(() => targetType = value);
              _resetTable();
            },
          ),
          metrics: [
            MetricCardData(
              value:
                  '${filteredForMetrics.where((item) => item.status == ReportStatus.pending).length}',
              label: 'Pending Reports',
              icon: Icons.folder_copy_outlined,
              accent: const Color(0xFFEF4444),
            ),
            MetricCardData(
              value:
                  '${filteredForMetrics.where((item) => item.status == ReportStatus.underReview).length}',
              label: 'Under Review',
              icon: Icons.visibility_outlined,
              accent: const Color(0xFF3B82F6),
            ),
            MetricCardData(
              value:
                  '${filteredForMetrics.where((item) => item.status == ReportStatus.resolved).length}',
              label: 'Resolved',
              icon: Icons.check_circle_outline_rounded,
              accent: const Color(0xFF10B981),
            ),
            MetricCardData(
              value: '$blockedCount',
              label: targetType == 'Stall Holders'
                  ? 'Blocked Stall Holders'
                  : targetType == 'Customers'
                      ? 'Blocked Customers'
                      : 'Blocked Accounts',
              icon: Icons.block_outlined,
              accent: const Color(0xFFEF4444),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 26, 36, 36),
          child: DataPanel(
            title: history ? 'Resolved Report History' : 'Review Reports',
            headerAction: _ReportViewToggle(
              history: history,
              onChanged: (value) {
                setState(() {
                  history = value;
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
                    targetType = 'All Types';
                    history = false;
                    _resetTable();
                  },
                  trailing: [
                    _filter(
                      targetType == 'All Types' ? 'Account Type' : targetType,
                      const [
                        'All Types',
                        'Stall Holders',
                        'Customers',
                      ],
                      (value) {
                        setState(() => targetType = value);
                        _resetTable();
                      },
                    ),
                    _filter(status, [
                      'All Statuses',
                      'Pending',
                      'Under Review',
                      'Resolved',
                    ], (value) {
                      status = value;
                      if (value == 'Resolved') history = true;
                      if (value != 'Resolved') history = false;
                      _resetTable();
                    }),
                    _filter(
                        selectedCategory == 'All Categories'
                            ? 'Stall Category'
                            : selectedCategory,
                        categories, (value) {
                      stallCategory = value;
                      _resetTable();
                    }),
                    FilterButton(
                      label: 'Export',
                      icon: Icons.download_outlined,
                      onTap: () => _export(values),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      child: child,
                    ),
                  ),
                  child: _ReportTable(
                    key: ValueKey(
                      '$history-$targetType-${values.map((item) => item.id).join(',')}',
                    ),
                    history: history,
                    values: values.skip(safePage * 10).take(10).toList(),
                    newReportIds: newReportIds,
                    verticalController: tableScrollController,
                    onOpen: (item) {
                      _markReportViewed(item.id);
                      showBlurredDialog(
                        context,
                        (context) => ReportReviewDialog(report: item),
                      );
                    },
                  ),
                ),
                if (values.isNotEmpty)
                  PaginationBar(
                    total: values.length,
                    start: safePage * 10 + 1,
                    end: ((safePage + 1) * 10).clamp(0, values.length),
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

  void _export(List<Report> values) {
    final csv = buildCsv([
      [
        'Type',
        'Account / Issue',
        'Submitted By',
        'Reason',
        'Category',
        'Date',
        'Status',
        'Priority'
      ],
      ...values.map(
        (item) => [
          item.type == 'Vendor' ? 'Stall Holder' : item.type,
          item.accountIssue,
          item.submittedBy,
          item.reason,
          item.category ?? 'FRUITS',
          item.date.toIso8601String(),
          enumLabel(item.status),
          enumLabel(item.priority),
        ],
      ),
    ]);
    final filename = targetType == 'Stall Holders'
        ? 'palengkego-stall-holder-reports.csv'
        : targetType == 'Customers'
            ? 'palengkego-customer-reports.csv'
            : 'palengkego-reports.csv';
    downloadCsv(csv, filename);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reports CSV downloaded.')),
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({
    super.key,
    required this.history,
    required this.values,
    required this.newReportIds,
    required this.verticalController,
    required this.onOpen,
  });
  final bool history;
  final List<Report> values;
  final Set<String> newReportIds;
  final ScrollController verticalController;
  final ValueChanged<Report> onOpen;
  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final rows = values.map(
      (item) {
        final isNew = !history && newReportIds.contains(item.id);
        return DataRow(
          color: isNew
              ? WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return colors.info.withValues(alpha: 0.13);
                  }
                  return colors.info.withValues(alpha: 0.07);
                })
              : null,
          onSelectChanged: (_) => onOpen(item),
          cells: history
              ? [
                  DataCell(
                      Text(item.type == 'Vendor' ? 'Stall Holder' : item.type)),
                  DataCell(Text(item.id)),
                  DataCell(
                    Text(
                      item.accountIssue,
                      style: TextStyle(
                        color: colors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  DataCell(Text(item.reason)),
                  DataCell(
                    StatusBadge(
                      label: item.decision ?? 'Resolved',
                      kind: item.decision == 'No Violation'
                          ? BadgeKind.neutral
                          : item.decision == 'Account Blocked'
                              ? BadgeKind.danger
                              : BadgeKind.warning,
                    ),
                  ),
                  DataCell(Text(item.actionTaken ?? 'Resolved')),
                  DataCell(
                    Text(
                      item.resolvedAt == null
                          ? '—'
                          : longDate.format(item.resolvedAt!),
                    ),
                  ),
                  DataCell(Text(item.resolvedBy ?? 'Administrator')),
                ]
              : [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isNew)
                          Container(
                            width: 3.5,
                            height: 24,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: colors.info,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        Flexible(
                          child: Text(
                            item.type == 'Vendor' ? 'Stall Holder' : item.type,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Wrap(
                      spacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.accountIssue,
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isNew)
                          const StatusBadge(
                            label: 'NEW',
                            kind: BadgeKind.info,
                          ),
                      ],
                    ),
                  ),
                  DataCell(Text(item.submittedBy)),
                  DataCell(Text(item.reason)),
                  DataCell(
                    CategoryBadge(
                      category: item.category ?? 'FRUITS',
                    ),
                  ),
                  DataCell(
                    Text(
                      '${item.date.month.toString().padLeft(2, '0')}/${item.date.day.toString().padLeft(2, '0')}/${item.date.year}',
                    ),
                  ),
                  DataCell(
                    StatusBadge(
                      label: enumLabel(item.status),
                      kind: item.status == ReportStatus.resolved
                          ? BadgeKind.success
                          : item.status == ReportStatus.underReview
                              ? BadgeKind.info
                              : BadgeKind.danger,
                    ),
                  ),
                  DataCell(
                    Text(
                      enumLabel(item.priority),
                      style: TextStyle(
                        color: item.priority == Priority.high
                            ? colors.danger
                            : item.priority == Priority.medium
                                ? colors.warning
                                : colors.mutedText,
                      ),
                    ),
                  ),
                ],
        );
      },
    ).toList();
    return ScrollableDataTable(
      verticalController: verticalController,
      minWidth: history ? 1450 : 1350,
      columnSpacing: 18,
      columns: history
          ? const [
              DataColumn(
                columnWidth: FixedColumnWidth(130),
                label: Text('TYPE'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.15),
                label: Text('REPORT ID'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.35),
                label: Text('REPORTED USER'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.25),
                label: Text('REASON'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.3),
                label: Text('DECISION'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.25),
                label: Text('ACTION TAKEN'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.35),
                label: Text('RESOLVED DATE'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.15),
                label: Text('RESOLVED BY'),
              ),
            ]
          : const [
              DataColumn(
                columnWidth: FixedColumnWidth(130),
                label: Text('TYPE'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.4),
                label: Text('ACCOUNT / ISSUE'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.2),
                label: Text('SUBMITTED BY'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.4),
                label: Text('REASON'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.1),
                label: Text('CATEGORY'),
              ),
              DataColumn(
                columnWidth: FixedColumnWidth(130),
                label: Text('DATE'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.1),
                label: Text('STATUS'),
              ),
              DataColumn(
                columnWidth: FixedColumnWidth(150),
                label: Text('PRIORITY'),
              ),
            ],
      rows: rows,
    );
  }
}

class _ReportViewToggle extends StatelessWidget {
  const _ReportViewToggle({required this.history, required this.onChanged});

  final bool history;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(
            value: false,
            label: Text('Review'),
            icon: Icon(Icons.inbox_outlined, size: 15),
          ),
          ButtonSegment<bool>(
            value: true,
            label: Text('Resolved'),
            icon: Icon(Icons.history_rounded, size: 15),
          ),
        ],
        selected: {history},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
      );
}

class _ReportTabs extends StatelessWidget {
  const _ReportTabs({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tab(context, 'All Complaints', selected == 'All Types'),
            const SizedBox(width: 8),
            _tab(context, 'Stall Holders', selected == 'Stall Holders'),
            const SizedBox(width: 8),
            _tab(context, 'Customers', selected == 'Customers'),
          ],
        ),
      );

  Widget _tab(BuildContext context, String label, bool active) => Material(
        color: active
            ? semanticColors(context).activeNavigation
            : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () {
            if (label == 'All Complaints') {
              onChanged('All Types');
            } else {
              onChanged(label);
            }
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                color: active
                    ? semanticColors(context).heroBackground
                    : semanticColors(context).heroMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
}

class _ReportedAccount {
  const _ReportedAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
  });

  final String id;
  final String name;
  final String type;
  final AccountStatus status;
}

class ReportReviewDialog extends ConsumerStatefulWidget {
  const ReportReviewDialog({super.key, required this.report});
  final Report report;
  @override
  ConsumerState<ReportReviewDialog> createState() => _ReportReviewDialogState();
}

class _ReportReviewDialogState extends ConsumerState<ReportReviewDialog> {
  late final notes = TextEditingController(text: widget.report.notes);
  bool processing = false;
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  _ReportedAccount? _reportedAccount(AppDataState data) {
    final issue = widget.report.accountIssue.trim().toLowerCase();
    final vendorName = widget.report.vendorName.trim().toLowerCase();

    if (widget.report.type == 'Vendor' ||
        widget.report.type == 'Stall Holder') {
      for (final vendor in data.vendors) {
        final name = vendor.name.trim().toLowerCase();
        if (name == issue || name == vendorName) {
          return _ReportedAccount(
            id: vendor.id,
            name: vendor.name,
            type: 'Stall Holder',
            status: vendor.status,
          );
        }
      }
    }
    if (widget.report.type == 'Customer') {
      for (final customer in data.customers) {
        if (customer.name.trim().toLowerCase() == issue) {
          return _ReportedAccount(
            id: customer.id,
            name: customer.name,
            type: 'Customer',
            status: customer.status,
          );
        }
      }
      for (final vendor in data.vendors) {
        if (vendor.name.trim().toLowerCase() == vendorName) {
          return _ReportedAccount(
            id: vendor.id,
            name: vendor.name,
            type: 'Stall Holder',
            status: vendor.status,
          );
        }
      }
    }
    return null;
  }

  String _reportedAccountTypeLabel() {
    final account = _reportedAccount(ref.watch(appDataProvider));
    if (account == null) {
      return (widget.report.type == 'Vendor' ||
              widget.report.type == 'Stall Holder')
          ? 'STALL HOLDER'
          : widget.report.type.toUpperCase();
    }
    return (account.type.contains('Stall Holder') ||
            account.type.startsWith('Vendor'))
        ? 'STALL HOLDER'
        : 'CUSTOMER';
  }

  String _reportedAccountName() {
    final account = _reportedAccount(ref.watch(appDataProvider));
    if (account != null && account.name.isNotEmpty) return account.name;
    return widget.report.type == 'Customer'
        ? widget.report.accountIssue
        : widget.report.vendorName;
  }

  String _reportedAccountSubtitle() {
    final account = _reportedAccount(ref.watch(appDataProvider));
    final isCustomer =
        widget.report.type == 'Customer' || account?.type == 'Customer';
    return isCustomer
        ? 'Customer Account'
        : 'Stall Holder: ${widget.report.owner.isNotEmpty ? widget.report.owner : widget.report.vendorName}';
  }

  Future<void> _dismissReport({bool markResolved = false}) async {
    final resolutionNote = TextEditingController();
    final title = markResolved ? 'Mark Report as Resolved?' : 'Dismiss Report?';
    final confirmation = markResolved
        ? 'This will mark the report as resolved without changing the account '
            'status.'
        : 'This will dismiss the report without changing the account status.';
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report: #${widget.report.id}'),
                const SizedBox(height: 7),
                Text('Reported User: ${widget.report.accountIssue}'),
                const SizedBox(height: 14),
                Text(confirmation),
                const SizedBox(height: 14),
                TextField(
                  controller: resolutionNote,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Optional Resolution Note',
                    hintText: 'Enter a note for the resolved report',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child:
                  Text(markResolved ? 'Mark as Resolved' : 'Confirm Dismiss'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => processing = true);
      final error = markResolved
          ? await ref.read(appDataProvider.notifier).resolveReport(
                reportId: widget.report.id,
                note: resolutionNote.text,
              )
          : await ref.read(appDataProvider.notifier).dismissReport(
                reportId: widget.report.id,
                note: resolutionNote.text,
              );
      if (!mounted) return;
      if (error != null) {
        setState(() => processing = false);
        _showError(error);
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            markResolved
                ? 'Report resolved successfully. Moved to Resolved Reports.'
                : 'Report dismissed successfully. Moved to Resolved Reports.',
          ),
        ),
      );
    } finally {
      resolutionNote.dispose();
    }
  }

  Future<void> _blockAccount(_ReportedAccount? account) async {
    if (account == null || processing) return;
    final reason = TextEditingController();
    String? validationError;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Block Account?'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reported User: ${account.name}'),
                  const SizedBox(height: 6),
                  Text('Account Type: ${account.type}'),
                  const SizedBox(height: 6),
                  Text('Related Report: #${widget.report.id}'),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reason,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) {
                      if (validationError != null) {
                        setDialogState(() => validationError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Blocking Reason *',
                      hintText: 'Enter the reason for blocking',
                      errorText: validationError,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: semanticColors(context).danger,
                ),
                onPressed: () {
                  if (reason.text.trim().isEmpty) {
                    setDialogState(
                      () => validationError = 'A blocking reason is required.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                icon: const Icon(Icons.block_outlined, size: 17),
                label: const Text('Block Account'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => processing = true);
      final error =
          await ref.read(appDataProvider.notifier).blockAccountFromReport(
                reportId: widget.report.id,
                reason: reason.text,
              );
      if (!mounted) return;
      if (error != null) {
        setState(() => processing = false);
        _showError(error);
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Account blocked successfully. Report moved to Resolved.'),
        ),
      );
      if (mounted) {
        context.go(
          '/accounts?accountId=${Uri.encodeComponent(account.id)}&open=1',
        );
      }
    } finally {
      reason.dispose();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> action(String title, ReportStatus value) async {
    final input = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: input,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add a reason or message...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input.text.trim()),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (result == null || result.isEmpty || !mounted) return;
      setState(() => processing = true);
      await ref
          .read(appDataProvider.notifier)
          .updateReport(widget.report.id, value, result);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title completed.')));
      }
    } finally {
      input.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolved = widget.report.status == ReportStatus.resolved;
    final account = _reportedAccount(ref.watch(appDataProvider));
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: screenHeight * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _info(context),
                      const SizedBox(height: 16),
                      Text(
                        'REASON: ${widget.report.reason.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: semanticColors(context)
                              .infoContainer
                              .withValues(alpha: .6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.report.description,
                          style: const TextStyle(fontSize: 11, height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'EVIDENCE ATTACHED (2 IMAGES)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          _evidence(
                            'assets/images/spoiled_produce.png',
                            'Spoiled produce',
                          ),
                          const SizedBox(width: 10),
                          _evidence(
                            'assets/images/mobile_conversation.png',
                            'Mobile conversation',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ACCOUNT HISTORY HIGHLIGHTS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _history(context),
                      const SizedBox(height: 16),
                      const Text(
                        'INVESTIGATION FINDINGS & NOTES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: notes,
                        minLines: 3,
                        maxLines: 5,
                        readOnly: resolved,
                        decoration: const InputDecoration(
                          hintText: 'Add investigation findings...',
                        ),
                      ),
                      if (widget.report.decision != null) ...[
                        const SizedBox(height: 14),
                        _decisionSummary(context),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (!resolved) ...[
              const Divider(height: 1),
              _footer(context, account),
            ] else ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: semanticColors(context).heroBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final cleanId = widget.report.id.startsWith('#')
        ? widget.report.id
        : '#${widget.report.id}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 14, 16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  'Report Review: $cleanId',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 9),
                StatusBadge(
                  label: enumLabel(widget.report.status),
                  kind: widget.report.status == ReportStatus.resolved
                      ? BadgeKind.success
                      : widget.report.status == ReportStatus.underReview
                          ? BadgeKind.info
                          : BadgeKind.danger,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, _ReportedAccount? account) {
    final outlineStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
    final warningStyle = outlineStyle.copyWith(
      foregroundColor: WidgetStatePropertyAll(
        semanticColors(context).warning,
      ),
      side: WidgetStatePropertyAll(
        BorderSide(color: semanticColors(context).warning),
      ),
    );
    final resolvedStyle = FilledButton.styleFrom(
      backgroundColor: semanticColors(context).heroBackground,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
    final dangerStyle = FilledButton.styleFrom(
      backgroundColor: semanticColors(context).danger,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );

    final warningBtn = OutlinedButton.icon(
      onPressed: processing
          ? null
          : () => action(
                'Send warning',
                ReportStatus.underReview,
              ),
      style: warningStyle,
      icon: const Icon(Icons.warning_amber_outlined, size: 16),
      label: const Text('Send Warning', style: TextStyle(fontSize: 11.5)),
    );

    final dismissBtn = OutlinedButton(
      onPressed: processing ? null : _dismissReport,
      style: outlineStyle,
      child: const Text('Dismiss Report', style: TextStyle(fontSize: 11.5)),
    );

    final resolveBtn = FilledButton.icon(
      onPressed: processing ? null : () => _dismissReport(markResolved: true),
      style: resolvedStyle,
      icon: const Icon(Icons.check_circle_outline, size: 16),
      label: const Text('Mark as Resolved', style: TextStyle(fontSize: 11.5)),
    );

    final blockBtn = FilledButton.icon(
      onPressed:
          processing || account == null ? null : () => _blockAccount(account),
      style: dangerStyle,
      icon: const Icon(Icons.block_outlined, size: 16),
      label: const Text('Block Account', style: TextStyle(fontSize: 11.5)),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).dialogTheme.backgroundColor ??
            Theme.of(context).cardColor,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 650) {
            return Row(
              children: [
                Expanded(child: warningBtn),
                const SizedBox(width: 10),
                Expanded(child: dismissBtn),
                const SizedBox(width: 10),
                Expanded(child: resolveBtn),
                const SizedBox(width: 10),
                Expanded(child: blockBtn),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: warningBtn),
                  const SizedBox(width: 10),
                  Expanded(child: dismissBtn),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: resolveBtn),
                  const SizedBox(width: 10),
                  Expanded(child: blockBtn),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _decisionSummary(BuildContext context) {
    final isDismissed = widget.report.decision == 'No Violation';
    final color = isDismissed
        ? semanticColors(context).mutedText
        : widget.report.decision == 'Account Blocked'
            ? semanticColors(context).danger
            : semanticColors(context).warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FINAL DECISION',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(widget.report.decision ?? 'Resolved'),
          if (widget.report.actionTaken != null)
            Text('Action taken: ${widget.report.actionTaken}'),
          if (widget.report.resolutionNote != null &&
              widget.report.resolutionNote!.isNotEmpty)
            Text('Note: ${widget.report.resolutionNote}'),
          if (widget.report.resolvedBy != null)
            Text('Resolved by: ${widget.report.resolvedBy}'),
          if (widget.report.resolvedAt != null)
            Text('Resolved on: ${longDate.format(widget.report.resolvedAt!)}'),
        ],
      ),
    );
  }

  Widget _info(BuildContext context) {
    final account = _reportedAccount(ref.watch(appDataProvider));
    final isCustomer =
        widget.report.type == 'Customer' || account?.type == 'Customer';
    final reporterName = widget.report.submittedBy.trim().isNotEmpty
        ? widget.report.submittedBy
        : 'Unknown Reporter';
    final reportedName = _reportedAccountName();
    final reportedSubtitle = _reportedAccountSubtitle();
    final reportedDetail = isCustomer
        ? (account != null ? 'Customer ID: ${account.id}' : 'Customer Account')
        : 'Stall No: ${widget.report.stallNumber.isNotEmpty ? widget.report.stallNumber : '—'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _infoHeading(context, 'REPORTER INFORMATION')),
            const SizedBox(width: 24),
            Expanded(
              child: _infoHeading(
                context,
                'REPORTED ACCOUNT (${_reportedAccountTypeLabel()})',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AvatarCircle(name: reporterName, size: 34),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reporterName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (widget.report.reporterEmail.isNotEmpty)
                          Text(
                            widget.report.reporterEmail,
                            style: const TextStyle(fontSize: 9),
                          ),
                        const SizedBox(height: 11),
                        if (widget.report.phone.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 15),
                              const SizedBox(width: 6),
                              Text(
                                widget.report.phone,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: semanticColors(context).infoContainer,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      isCustomer
                          ? Icons.person_rounded
                          : Icons.storefront_outlined,
                      color: semanticColors(context).info,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reportedName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          reportedSubtitle,
                          style: const TextStyle(fontSize: 9),
                        ),
                        const SizedBox(height: 11),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                reportedDetail,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            StatusBadge(
                              label: widget.report.previousViolations > 0
                                  ? '${widget.report.previousViolations} PREVIOUS VIOLATION${widget.report.previousViolations == 1 ? '' : 'S'}'
                                  : 'NO PREVIOUS VIOLATIONS',
                              kind: widget.report.previousViolations > 0
                                  ? BadgeKind.danger
                                  : BadgeKind.neutral,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoHeading(BuildContext context, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Theme.of(context).dividerColor),
        ],
      );

  Widget _evidence(String asset, String label) => Expanded(
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: InteractiveViewer(
                child: Image.asset(
                  asset,
                  errorBuilder: (context, error, stackTrace) =>
                      _missingEvidence(context),
                ),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 2.1,
                  child: Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _missingEvidence(context),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );

  Widget _missingEvidence(BuildContext context) {
    final colors = semanticColors(context);
    return Container(
      color: colors.inputSurface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: colors.mutedText),
          const SizedBox(height: 7),
          Text(
            'Evidence unavailable',
            style: TextStyle(
              color: colors.secondaryText,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'The attached image could not be loaded.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.mutedText, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _history(BuildContext context) {
    if (widget.report.previousViolations == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: semanticColors(context).inputSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: semanticColors(context).subtleBorder),
        ),
        child: Center(
          child: Text(
            'No previous violations recorded for this account.',
            style: TextStyle(
              fontSize: 11,
              color: semanticColors(context).mutedText,
            ),
          ),
        ),
      );
    }

    final account = _reportedAccount(ref.watch(appDataProvider));
    final isCustomer =
        widget.report.type == 'Customer' || account?.type == 'Customer';

    final rows = <TableRow>[
      TableRow(
        decoration: BoxDecoration(
          color: semanticColors(context).inputSurface.withValues(alpha: .5),
        ),
        children: [
          _cell('Date', isHeader: true),
          _cell('Violation Type', isHeader: true),
          _cell('Action Taken', isHeader: true),
          _cell('Status', isHeader: true),
        ],
      ),
      TableRow(children: [
        _cell('Sep 15, 2023'),
        _cell(isCustomer ? 'Dispute with Stall Holder' : 'Late Delivery'),
        _cell('Warning Issued'),
        _cell('Closed'),
      ]),
    ];

    if (widget.report.previousViolations >= 2) {
      rows.add(
        TableRow(children: [
          _cell('Aug 02, 2023'),
          _cell(isCustomer ? 'Abusive Messaging' : 'Incorrect Pricing'),
          _cell('System Flag'),
          _cell('Closed'),
        ]),
      );
    }

    return Table(
      border: TableBorder.all(color: semanticColors(context).subtleBorder),
      children: rows,
    );
  }

  Widget _cell(String value, {bool isHeader = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isHeader ? FontWeight.w800 : FontWeight.normal,
          ),
        ),
      );
}
