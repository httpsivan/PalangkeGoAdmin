import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/export/admin_export_service.dart';
import '../../core/utils/export/module_export_data_builders.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/admin_shell.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../data/repositories/mock_repository.dart';
import '../../models/app_models.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({
    super.key,
    this.selectedReportId,
    this.openDetailsOnLoad = false,
  });

  final String? selectedReportId;
  final bool openDetailsOnLoad;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final search = TextEditingController();
  final tableScrollController = ScrollController();
  String status = 'All Statuses';
  String stallCategory = 'All Categories';
  String targetType = 'All Types';
  String dateOrder = 'Newest to Oldest';
  bool history = false;
  int page = 0;
  bool _selectedReportOpened = false;
  bool _isStallHolderReport(Report item) =>
      item.type == 'Stall Holder' || item.type == 'Vendor';

  bool _isCustomerReport(Report item) => item.type == 'Customer';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSelectedReport());
  }

  @override
  void didUpdateWidget(covariant ReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedReportId != oldWidget.selectedReportId ||
        widget.openDetailsOnLoad != oldWidget.openDetailsOnLoad) {
      _selectedReportOpened = false;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openSelectedReport(),
      );
    }
  }

  Future<void> _openSelectedReport() async {
    if (!mounted ||
        _selectedReportOpened ||
        !widget.openDetailsOnLoad ||
        widget.selectedReportId == null) {
      return;
    }
    Report? selected;
    for (final item in ref.read(appDataProvider).reports) {
      if (item.id == widget.selectedReportId) {
        selected = item;
        break;
      }
    }
    if (selected == null) return;
    _selectedReportOpened = true;
    await _openReport(selected);
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

  Future<void> _openReport(Report report) async {
    if (report.status == ReportStatus.pending) {
      final error = await ref.read(appDataProvider.notifier).updateReport(
            report.id,
            ReportStatus.underReview,
            'Review started by administrator.',
          );
      if (error != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }
    if (!mounted) return;
    final current = ref
        .read(appDataProvider)
        .reports
        .firstWhere((item) => item.id == report.id, orElse: () => report);
    showBlurredDialog(
      context,
      (context) => ReportReviewDialog(report: current),
    );
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
      ..sort((a, b) {
        final aDate = history ? a.resolvedAt ?? a.date : a.date;
        final bDate = history ? b.resolvedAt ?? b.date : b.date;
        return dateOrder == 'Oldest to Newest'
            ? aDate.compareTo(bDate)
            : bDate.compareTo(aDate);
      });
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
              onTap: () {
                setState(() {
                  history = false;
                  status = 'Pending';
                });
                _resetTable();
              },
            ),
            MetricCardData(
              value:
                  '${filteredForMetrics.where((item) => item.status == ReportStatus.underReview).length}',
              label: 'Under Review',
              icon: Icons.visibility_outlined,
              accent: const Color(0xFF3B82F6),
              onTap: () {
                setState(() {
                  history = false;
                  status = 'Under Review';
                });
                _resetTable();
              },
            ),
            MetricCardData(
              value:
                  '${filteredForMetrics.where((item) => item.status == ReportStatus.resolved).length}',
              label: 'Resolved',
              icon: Icons.check_circle_outline_rounded,
              accent: const Color(0xFF10B981),
              onTap: () {
                setState(() {
                  history = true;
                  status = 'All Statuses';
                });
                _resetTable();
              },
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
              onTap: () => context.go('/accounts'),
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
                  emphasized: true,
                  onChanged: (_) => _resetTable(),
                  onClear: () {
                    search.clear();
                    status = 'All Statuses';
                    stallCategory = 'All Categories';
                    targetType = 'All Types';
                    dateOrder = 'Newest to Oldest';
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
                    _filter(
                      dateOrder,
                      const ['Newest to Oldest', 'Oldest to Newest'],
                      (value) {
                        setState(() => dateOrder = value);
                        _resetTable();
                      },
                    ),
                    ExportButton(
                      onExportPdf: () => _exportReports(
                        allReports: reports,
                        filteredReports: values,
                        format: ExportFormat.pdf,
                      ),
                      onExportExcel: () => _exportReports(
                        allReports: reports,
                        filteredReports: values,
                        format: ExportFormat.excel,
                      ),
                    ),
                  ],
                ),
                _ReportTable(
                  history: history,
                  values: values.skip(safePage * 10).take(10).toList(),
                  verticalController: tableScrollController,
                  onOpen: _openReport,
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
        alwaysActive: true,
      );

  Future<void> _exportReports({
    required List<Report> allReports,
    required List<Report> filteredReports,
    required ExportFormat format,
  }) async {
    final filters = <String>[
      history ? 'Resolved Reports' : 'Review Reports',
      if (targetType != 'All Types') 'Account Type: $targetType',
      if (status != 'All Statuses') 'Status: $status',
      if (stallCategory != 'All Categories') 'Stall Category: $stallCategory',
      if (dateOrder != 'Newest to Oldest') 'Sort: $dateOrder',
      if (search.text.trim().isNotEmpty) 'Search: "${search.text.trim()}"',
    ];
    final doc = ComplaintExportData.build(
      allReports: allReports,
      filteredReports: filteredReports,
      activeFilters: filters.join(' | '),
      accountType: targetType,
    );
    await AdminExportService.export(
      context: context,
      ref: ref,
      doc: doc,
      format: format,
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({
    required this.history,
    required this.values,
    required this.verticalController,
    required this.onOpen,
  });
  final bool history;
  final List<Report> values;
  final ScrollController verticalController;
  final ValueChanged<Report> onOpen;
  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final rows = values.map(
      (item) {
        return DataRow(
          color: item.isUnread
              ? WidgetStatePropertyAll(
                  colors.infoContainer.withValues(alpha: .45))
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
                ]
              : [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        if (item.isUnread)
                          const StatusBadge(label: 'New', kind: BadgeKind.info),
                        Text(
                          item.accountIssue,
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w800,
                          ),
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
                      shortDate.format(item.date),
                    ),
                  ),
                  DataCell(
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: StatusBadge(
                        label: enumLabel(item.status),
                        kind: item.status == ReportStatus.resolved
                            ? BadgeKind.success
                            : item.status == ReportStatus.underReview
                                ? BadgeKind.info
                                : BadgeKind.danger,
                      ),
                    ),
                  ),
                ],
        );
      },
    ).toList();
    return ScrollableDataTable(
      verticalController: verticalController,
      minWidth: 1300,
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
                label: Text('VIOLATION TYPE'),
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
                label: Text('VIOLATION TYPE'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.1),
                label: Text('CATEGORY'),
              ),
              DataColumn(
                columnWidth: FixedColumnWidth(170),
                label: Text('DATE'),
              ),
              DataColumn(
                columnWidth: FlexColumnWidth(1.1),
                label: Padding(
                  padding: EdgeInsets.only(left: 32),
                  child: Text('STATUS'),
                ),
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

  String _reporterTypeLabel() =>
      _reportedAccountTypeLabel() == 'CUSTOMER' ? 'STALL HOLDER' : 'CUSTOMER';

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
    return isCustomer ? 'Customer Account' : 'Stall Holder Account';
  }

  Future<void> _resolveReport() async {
    final resolutionNote = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Mark Report as Resolved?'),
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
                const Text(
                  'This will mark the report as resolved without changing the account status.',
                ),
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
              child: const Text('Mark as Resolved'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => processing = true);
      final error = await ref.read(appDataProvider.notifier).resolveReport(
            reportId: widget.report.id,
            note: resolutionNote.text,
          );
      if (!mounted) return;
      if (error != null) {
        setState(() => processing = false);
        _showError(error);
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content:
              Text('Report resolved successfully. Moved to Resolved Reports.'),
        ),
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 300), () {
        resolutionNote.dispose();
      });
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
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content:
              Text('Account blocked successfully. Report moved to Resolved.'),
        ),
      );
      router.go(
        '/accounts?accountId=${Uri.encodeComponent(account.id)}&open=1',
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 300), () {
        reason.dispose();
      });
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
      final error = await ref
          .read(appDataProvider.notifier)
          .updateReport(widget.report.id, value, result);
      if (error != null && mounted) {
        setState(() => processing = false);
        _showError(error);
        return;
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text('$title completed.')));
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 300), () {
        input.dispose();
      });
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
                        'VIOLATION TYPE: ${widget.report.reason.toUpperCase()}',
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
                      Text(
                        'EVIDENCE ATTACHED (${widget.report.evidenceUrls.length} IMAGES)',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 9),
                      if (widget.report.evidenceUrls.isEmpty)
                        const Text('No evidence images attached.')
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (var i = 0;
                                i < widget.report.evidenceUrls.length;
                                i++)
                              _evidence(widget.report.evidenceUrls[i],
                                  'Evidence ${i + 1}'),
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
    final warningStyle = FilledButton.styleFrom(
      backgroundColor: semanticColors(context).warning,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
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

    final warningBtn = FilledButton.icon(
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

    final resolveBtn = FilledButton.icon(
      onPressed: processing ? null : _resolveReport,
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
                Expanded(child: blockBtn),
                const SizedBox(width: 10),
                Expanded(child: resolveBtn),
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
                  Expanded(child: blockBtn),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: resolveBtn,
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
            Expanded(
              child: _infoHeading(
                context,
                'COMPLAINT FROM (${_reporterTypeLabel()})',
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _infoHeading(
                context,
                'RELATED ${_reportedAccountTypeLabel()}',
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

  Widget _evidence(String asset, String label) => SizedBox(
        width: 280,
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _EvidenceViewerDialog(
              initialAsset: asset,
              evidence: [
                for (var i = 0; i < widget.report.evidenceUrls.length; i++)
                  _EvidenceItem(
                    asset: widget.report.evidenceUrls[i],
                    label: 'Evidence ${i + 1}',
                    filename: Uri.parse(widget.report.evidenceUrls[i])
                        .pathSegments
                        .last,
                  ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 2.1,
                  child: Image.network(
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
        _cell(isCustomer ? 'Customer Conflict' : 'Delivery Problem'),
        _cell('Warning Issued'),
        _cell('Closed'),
      ]),
    ];

    if (widget.report.previousViolations >= 2) {
      rows.add(
        TableRow(children: [
          _cell('Aug 02, 2023'),
          _cell(isCustomer ? 'Order Management' : 'Payment Problem'),
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

class _EvidenceItem {
  const _EvidenceItem({
    required this.asset,
    required this.label,
    required this.filename,
  });

  final String asset;
  final String label;
  final String filename;
}

class _EvidenceViewerDialog extends StatefulWidget {
  const _EvidenceViewerDialog({
    required this.evidence,
    required this.initialAsset,
  });

  final List<_EvidenceItem> evidence;
  final String initialAsset;

  @override
  State<_EvidenceViewerDialog> createState() => _EvidenceViewerDialogState();
}

class _EvidenceViewerDialogState extends State<_EvidenceViewerDialog> {
  static const _zoomSteps = [1.0, 1.25, 1.5, 1.75, 2.0];
  final _transformController = TransformationController();
  int _index = 0;
  int _zoomIndex = 0;
  int _reloadToken = 0;
  bool _isDragging = false;
  bool _fullView = false;

  _EvidenceItem get _item => widget.evidence[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.evidence.indexWhere(
      (item) => item.asset == widget.initialAsset,
    );
    if (_index < 0) _index = 0;
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _setZoom(int index) {
    setState(() => _zoomIndex = index.clamp(0, _zoomSteps.length - 1));
    final zoom = _zoomSteps[_zoomIndex];
    _transformController.value = Matrix4.diagonal3Values(zoom, zoom, 1.0);
  }

  void _changeEvidence(int direction) {
    final next = _index + direction;
    if (next < 0 || next >= widget.evidence.length) return;
    setState(() {
      _index = next;
      _zoomIndex = 0;
      _isDragging = false;
      _reloadToken++;
    });
    _transformController.value = Matrix4.identity();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _changeEvidence(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _changeEvidence(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _download() async {
    try {
      final response = await http.get(Uri.parse(_item.asset));
      if (response.statusCode != 200) {
        throw StateError('Evidence download failed');
      }
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save evidence',
        fileName: _item.filename,
        bytes: response.bodyBytes,
        type: FileType.image,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to download the evidence file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final screenSize = MediaQuery.sizeOf(context);
    final viewerHeight = _fullView
        ? screenSize.height
        : (screenSize.height * .72).clamp(420.0, 620.0).toDouble();
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Dialog(
        insetPadding: _fullView
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        backgroundColor: colors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: _fullView ? screenSize.width : 720,
          height: viewerHeight,
          child: Column(
            children: [
              _header(colors),
              Expanded(child: _imageArea(colors)),
              _thumbnails(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppSemanticColors colors) => Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          border: Border(bottom: BorderSide(color: colors.subtleBorder)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.heroBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.image_outlined,
                  color: colors.heroForeground, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evidence Viewer',
                    style: TextStyle(
                      color: colors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _item.label,
                    style: TextStyle(color: colors.secondaryText, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              '${_index + 1} of ${widget.evidence.length}',
              style: TextStyle(
                color: colors.primaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 18),
            _toolbarButton(
              colors: colors,
              tooltip: 'Zoom in',
              semanticLabel: 'Zoom in',
              icon: Icons.zoom_in_outlined,
              onPressed: _zoomIndex < _zoomSteps.length - 1
                  ? () => _setZoom(_zoomIndex + 1)
                  : null,
            ),
            const SizedBox(width: 6),
            _toolbarButton(
              colors: colors,
              tooltip: 'Zoom out',
              semanticLabel: 'Zoom out',
              icon: Icons.zoom_out_outlined,
              onPressed: _zoomIndex > 0 ? () => _setZoom(_zoomIndex - 1) : null,
            ),
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: colors.subtleBorder,
            ),
            _toolbarButton(
              colors: colors,
              tooltip: 'Download evidence',
              semanticLabel: 'Download evidence',
              icon: Icons.download_outlined,
              onPressed: _download,
            ),
            const SizedBox(width: 6),
            _toolbarButton(
              colors: colors,
              tooltip: 'Open full view',
              semanticLabel: 'Open evidence in full view',
              icon: _fullView
                  ? Icons.fullscreen_exit_outlined
                  : Icons.open_in_full_outlined,
              onPressed: () => setState(() => _fullView = !_fullView),
            ),
            const SizedBox(width: 10),
            _toolbarButton(
              colors: colors,
              tooltip: 'Close',
              semanticLabel: 'Close evidence viewer',
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
              close: true,
            ),
          ],
        ),
      );

  Widget _toolbarButton({
    required AppSemanticColors colors,
    required String tooltip,
    required String semanticLabel,
    required IconData icon,
    required VoidCallback? onPressed,
    bool close = false,
  }) =>
      Semantics(
        button: true,
        label: semanticLabel,
        child: Tooltip(
          message: tooltip,
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, size: 21),
            style: IconButton.styleFrom(
              minimumSize: const Size(42, 42),
              maximumSize: const Size(42, 42),
              foregroundColor:
                  close ? colors.heroBackground : colors.primaryText,
              disabledForegroundColor: colors.disabledText,
              backgroundColor: close
                  ? colors.heroBackground.withValues(alpha: 0.12)
                  : colors.tableHeader,
              side: close
                  ? BorderSide.none
                  : BorderSide(color: colors.subtleBorder),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      );

  Widget _imageArea(AppSemanticColors colors) => Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 12, 48, 12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              MouseRegion(
                cursor: _zoomIndex > 0
                    ? (_isDragging
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab)
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  onDoubleTap: () => _setZoom(_zoomIndex == 0 ? 2 : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 1,
                      maxScale: 2,
                      panEnabled: _zoomIndex > 0,
                      scaleEnabled: false,
                      boundaryMargin: const EdgeInsets.all(28),
                      onInteractionStart: (_) {
                        if (_zoomIndex > 0) setState(() => _isDragging = true);
                      },
                      onInteractionEnd: (_) {
                        if (_isDragging) setState(() => _isDragging = false);
                      },
                      child: Image.network(
                        _item.asset,
                        key: ValueKey('${_item.asset}-$_reloadToken'),
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            _errorState(colors),
                      ),
                    ),
                  ),
                ),
              ),
              if (_index > 0)
                _arrowButton(colors, Icons.chevron_left_rounded,
                    () => _changeEvidence(-1), Alignment.centerLeft),
              if (_index < widget.evidence.length - 1)
                _arrowButton(colors, Icons.chevron_right_rounded,
                    () => _changeEvidence(1), Alignment.centerRight),
            ],
          ),
        ),
      );

  Widget _arrowButton(AppSemanticColors colors, IconData icon,
          VoidCallback onPressed, Alignment alignment) =>
      Align(
        alignment: alignment,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            tooltip: icon == Icons.chevron_left_rounded
                ? 'Previous evidence'
                : 'Next evidence',
            onPressed: onPressed,
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              backgroundColor: colors.cardBackground.withValues(alpha: 0.95),
              foregroundColor: colors.primaryText,
              side: BorderSide(color: colors.subtleBorder),
            ),
            icon: Icon(icon),
          ),
        ),
      );

  Widget _errorState(AppSemanticColors colors) => ColoredBox(
        color: colors.tableHeader,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined,
                  color: colors.warning, size: 34),
              const SizedBox(height: 10),
              Text(
                'Unable to load evidence',
                style: TextStyle(
                  color: colors.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'The evidence file could not be displayed. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.secondaryText, fontSize: 12),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => setState(() => _reloadToken++),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _thumbnails(AppSemanticColors colors) => Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          border: Border(top: BorderSide(color: colors.subtleBorder)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.evidence.length, (index) {
            final item = widget.evidence[index];
            final selected = index == _index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Semantics(
                button: true,
                label: 'View evidence ${index + 1}: ${item.label}',
                child: InkWell(
                  onTap: () => _changeEvidence(index - _index),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 62,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? colors.heroBackground
                                : colors.subtleBorder,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.network(item.asset, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${index + 1}. ${item.label}',
                        style: TextStyle(
                          color: selected
                              ? colors.heroBackground
                              : colors.secondaryText,
                          fontSize: 9,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      );
}
