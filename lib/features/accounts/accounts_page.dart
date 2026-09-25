import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/csv_exporter.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../data/repositories/mock_repository.dart';
import '../../models/admin_models.dart';
import '../../models/app_models.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({
    super.key,
    this.selectedAccountId,
    this.openDetailsOnLoad = false,
  });

  final String? selectedAccountId;
  final bool openDetailsOnLoad;

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  final search = TextEditingController();
  final tableScrollController = ScrollController();
  bool customers = false;
  String status = 'All Statuses';
  String stallCategory = 'All Categories';
  int page = 0;
  bool selectedAccountOpened = false;

  @override
  void didUpdateWidget(covariant AccountsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedAccountId != oldWidget.selectedAccountId ||
        widget.openDetailsOnLoad != oldWidget.openDetailsOnLoad) {
      selectedAccountOpened = false;
      _openSelectedAccount();
    }
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
    final data = ref.watch(
      appDataProvider.select(
        (s) => (
          vendors: s.vendors,
          customers: s.customers,
          suspensions: s.suspensions
        ),
      ),
    );
    _openSelectedAccount();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageHeader(
          title: 'Account Management',
          subtitle:
              'Oversee stall holders, customers, and active administrative reports.',
          metrics: [
            if (!customers)
              MetricCardData(
                value:
                    '${data.vendors.where((v) => v.status == AccountStatus.active).length}',
                label: 'Active Stall Holders',
                icon: Icons.storefront_rounded,
                accent: const Color(0xFF10B981),
              ),
            if (customers)
              MetricCardData(
                value:
                    '${data.customers.where((c) => c.status == AccountStatus.active).length}',
                label: 'Active Customers',
                icon: Icons.people_outline_rounded,
                accent: const Color(0xFF3B82F6),
              ),
            MetricCardData(
              value:
                  '${data.vendors.where((v) => v.status == AccountStatus.suspended).length + data.customers.where((c) => c.status == AccountStatus.suspended).length}',
              label: 'Suspended Accounts',
              icon: Icons.pause_circle_outline_rounded,
              accent: const Color(0xFFF59E0B),
            ),
            MetricCardData(
              value:
                  '${data.vendors.where((v) => v.status == AccountStatus.blocked).length + data.customers.where((c) => c.status == AccountStatus.blocked).length}',
              label: 'Blocked Accounts',
              icon: Icons.block_rounded,
              accent: const Color(0xFFEF4444),
            ),
          ],
          tabs: _Tabs(
            selected: customers,
            onChanged: (value) {
              customers = value;
              _resetTable();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 26, 36, 36),
          child: customers
              ? _customerPanel(data.customers)
              : _vendorPanel(data.vendors),
        ),
      ],
    );
  }

  void _openSelectedAccount() {
    if (selectedAccountOpened ||
        !widget.openDetailsOnLoad ||
        widget.selectedAccountId == null) {
      return;
    }
    selectedAccountOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = ref.read(appDataProvider);
      final vendor = latest.vendors.cast<Vendor?>().firstWhere(
            (item) => item?.id == widget.selectedAccountId,
            orElse: () => null,
          );
      if (vendor != null) {
        showAccountDialog(context, ref, vendor: vendor);
        return;
      }
      final customer = latest.customers.cast<Customer?>().firstWhere(
            (item) => item?.id == widget.selectedAccountId,
            orElse: () => null,
          );
      if (customer != null) {
        setState(() => customers = true);
        showAccountDialog(context, ref, customer: customer);
      }
    });
  }

  List<Vendor> get filteredVendors => ref
      .read(appDataProvider)
      .vendors
      .where(
        (v) =>
            (search.text.trim().isEmpty ||
                '${v.name} ${v.email} ${v.id} ${v.stallType}'
                    .toLowerCase()
                    .contains(search.text.trim().toLowerCase())) &&
            (status == 'All Statuses' || enumLabel(v.status) == status) &&
            (stallCategory == 'All Categories' || v.stallType == stallCategory),
      )
      .toList();
  List<Customer> get filteredCustomers => ref
      .read(appDataProvider)
      .customers
      .where(
        (v) =>
            (search.text.trim().isEmpty ||
                '${v.name} ${v.email} ${v.id}'.toLowerCase().contains(
                      search.text.trim().toLowerCase(),
                    )) &&
            (status == 'All Statuses' || enumLabel(v.status) == status),
      )
      .toList();

  Widget _vendorPanel(List<Vendor> values) {
    const categories = [
      'All Categories',
      'Fruits',
      'Vegetables',
      'Meat',
      'Fish',
    ];
    final visible = values
        .where(
          (v) =>
              (search.text.trim().isEmpty ||
                  '${v.name} ${v.email} ${v.id} ${v.stallType}'
                      .toLowerCase()
                      .contains(search.text.trim().toLowerCase())) &&
              (status == 'All Statuses' || enumLabel(v.status) == status) &&
              (stallCategory == 'All Categories' ||
                  v.stallType == stallCategory),
        )
        .toList()
      ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
    final int totalPages = (visible.length / 10).ceil();
    final int safePage = totalPages == 0 ? 0 : page.clamp(0, totalPages - 1);
    return DataPanel(
      title: 'Accounts',
      child: Column(
        children: [
          Toolbar(
            controller: search,
            onChanged: (_) => _resetTable(),
            onClear: () {
              search.clear();
              status = 'All Statuses';
              stallCategory = 'All Categories';
              _resetTable();
            },
            trailing: [
              _filter(status, [
                'All Statuses',
                'Active',
                'Offline',
                'Suspended',
                'Blocked',
              ], (v) {
                status = v;
                _resetTable();
              }),
              _filter(
                  stallCategory == 'All Categories'
                      ? 'Stall Category'
                      : stallCategory,
                  categories, (value) {
                stallCategory = value;
                _resetTable();
              }),
              FilterButton(
                label: 'Export',
                icon: Icons.download_outlined,
                onTap: () => _export(visible, 'vendors'),
              ),
            ],
          ),
          _VendorTable(
            values: visible.skip(safePage * 10).take(10).toList(),
            verticalController: tableScrollController,
            onOpen: (vendor) => showAccountDialog(context, ref, vendor: vendor),
          ),
          if (visible.isNotEmpty)
            PaginationBar(
              total: visible.length,
              start: safePage * 10 + 1,
              end: ((safePage + 1) * 10).clamp(0, visible.length),
              page: safePage,
              pageCount: totalPages,
              onPageChanged: _goToPage,
              showSummary: search.text.trim().isNotEmpty,
            ),
        ],
      ),
    );
  }

  Widget _customerPanel(List<Customer> values) {
    final visible = values
        .where(
          (v) =>
              (search.text.trim().isEmpty ||
                  '${v.name} ${v.email} ${v.id}'.toLowerCase().contains(
                        search.text.trim().toLowerCase(),
                      )) &&
              (status == 'All Statuses' || enumLabel(v.status) == status),
        )
        .toList()
      ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
    final int totalPages = (visible.length / 10).ceil();
    final int safePage = totalPages == 0 ? 0 : page.clamp(0, totalPages - 1);
    return DataPanel(
      title: 'Customer Directory',
      subtitle: 'Manage and monitor customer activity and status',
      child: Column(
        children: [
          Toolbar(
            controller: search,
            onChanged: (_) => _resetTable(),
            onClear: () {
              search.clear();
              status = 'All Statuses';
              _resetTable();
            },
            searchHint: 'Search by name, email, or ID...',
            trailing: [
              _filter(status, [
                'All Statuses',
                'Active',
                'Suspended',
                'Blocked',
              ], (v) {
                status = v;
                _resetTable();
              }),
              FilterButton(
                label: 'Export',
                icon: Icons.download_outlined,
                onTap: () => _export(visible, 'customers'),
              ),
            ],
          ),
          _CustomerTable(
            values: visible.skip(safePage * 10).take(10).toList(),
            verticalController: tableScrollController,
            onOpen: (customer) => showAccountDialog(
              context,
              ref,
              customer: customer,
            ),
          ),
          if (visible.isNotEmpty)
            PaginationBar(
              total: visible.length,
              start: safePage * 10 + 1,
              end: ((safePage + 1) * 10).clamp(0, visible.length),
              page: safePage,
              pageCount: totalPages,
              onPageChanged: _goToPage,
              showSummary: search.text.trim().isNotEmpty,
            ),
        ],
      ),
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

  void _export(List<dynamic> values, String name) {
    final csv = buildCsv([
      ['ID', 'Name', 'Email', 'Status'],
      ...values.map(
        (item) => [item.id, item.name, item.email, enumLabel(item.status)],
      ),
    ]);
    downloadCsv(csv, 'palengkego-$name.csv');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV export prepared.')));
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});
  final bool selected;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          _tab(context, 'Stall Holders', !selected),
          const SizedBox(width: 8),
          _tab(context, 'Customers', selected),
        ],
      );
  Widget _tab(BuildContext context, String label, bool active) => Material(
        color: active
            ? semanticColors(context).activeNavigation
            : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => onChanged(label == 'Customers'),
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

class _VendorTable extends StatelessWidget {
  const _VendorTable({
    required this.values,
    required this.verticalController,
    required this.onOpen,
  });
  final List<Vendor> values;
  final ScrollController verticalController;
  final ValueChanged<Vendor> onOpen;
  @override
  Widget build(BuildContext context) {
    final rows = values
        .map(
          (vendor) => DataRow(
            onSelectChanged: (_) => onOpen(vendor),
            cells: [
              DataCell(
                Row(
                  children: [
                    AvatarCircle(name: vendor.name, size: 32),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          vendor.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(vendor.email, style: const TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
              DataCell(Text(vendor.stallType)),
              DataCell(Text(shortDate.format(vendor.registeredAt))),
              DataCell(
                StatusBadge(
                  label: enumLabel(vendor.status),
                  kind: vendor.status == AccountStatus.active
                      ? BadgeKind.success
                      : vendor.status == AccountStatus.blocked
                          ? BadgeKind.danger
                          : BadgeKind.warning,
                ),
              ),
              DataCell(
                IconButton(
                  onPressed: () => onOpen(vendor),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                ),
              ),
            ],
          ),
        )
        .toList();
    const columns = [
      DataColumn(
        columnWidth: FlexColumnWidth(2.2),
        label: Text('TENANTS DETAILS'),
      ),
      DataColumn(
        columnWidth: FlexColumnWidth(1.25),
        label: Text('STALL TYPE'),
      ),
      DataColumn(
        columnWidth: FlexColumnWidth(1.25),
        label: Text('REGISTRATION'),
      ),
      DataColumn(
        columnWidth: FlexColumnWidth(1.35),
        label: Text('ACCOUNT STATUS'),
      ),
      DataColumn(
        columnWidth: FixedColumnWidth(130),
        label: Text('ACTIONS'),
      ),
    ];
    return ScrollableDataTable(
      verticalController: verticalController,
      minWidth: 1100,
      columnSpacing: 20,
      columns: columns,
      rows: rows,
    );
  }
}

class _CustomerTable extends StatelessWidget {
  const _CustomerTable({
    required this.values,
    required this.verticalController,
    required this.onOpen,
  });
  final List<Customer> values;
  final ScrollController verticalController;
  final ValueChanged<Customer> onOpen;
  @override
  Widget build(BuildContext context) {
    final rows = values
        .map(
          (customer) => DataRow(
            onSelectChanged: (_) => onOpen(customer),
            cells: [
              DataCell(
                Row(
                  children: [
                    AvatarCircle(name: customer.name, size: 32),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          customer.email,
                          style: const TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              DataCell(Text(shortDate.format(customer.registeredAt))),
              DataCell(
                Text(
                  '${customer.transactions}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              DataCell(
                StatusBadge(
                  label: enumLabel(customer.status),
                  kind: customer.status == AccountStatus.active
                      ? BadgeKind.success
                      : BadgeKind.danger,
                ),
              ),
              DataCell(
                IconButton(
                  onPressed: () => onOpen(customer),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  tooltip: 'Open account details',
                ),
              ),
            ],
          ),
        )
        .toList();
    return ScrollableDataTable(
      verticalController: verticalController,
      minWidth: 1100,
      columnSpacing: 20,
      columns: const [
        DataColumn(
          columnWidth: FlexColumnWidth(2.2),
          label: Text('CUSTOMER NAME'),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(1.35),
          label: Text('REGISTRATION DATE'),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(1),
          label: Text('TRANSACTIONS'),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(1.35),
          label: Text('ACCOUNT STATUS'),
        ),
        DataColumn(
          columnWidth: FixedColumnWidth(130),
          label: Text('ACTIONS'),
        ),
      ],
      rows: rows,
    );
  }
}

Suspension? _suspensionForAccount(
  Iterable<Suspension> suspensions,
  String accountId,
) {
  for (final suspension in suspensions) {
    if (suspension.accountId == accountId) return suspension;
  }
  return null;
}

Future<void> showAccountDialog(
  BuildContext context,
  WidgetRef ref, {
  Vendor? vendor,
  Customer? customer,
}) {
  assert((vendor == null) != (customer == null));
  final data = ref.read(appDataProvider);
  final account = vendor != null
      ? _AccountDetailsData.fromVendor(
          vendor,
          suspension: _suspensionForAccount(data.suspensions, vendor.id),
        )
      : _AccountDetailsData.fromCustomer(
          customer!,
          suspension: _suspensionForAccount(data.suspensions, customer.id),
        );

  Future<void> update(String notes, AccountStatus nextStatus) {
    if (vendor != null) {
      return ref.read(appDataProvider.notifier).updateVendorAccount(
            vendor.id,
            status: nextStatus,
            administrativeNotes: notes,
          );
    }
    return ref.read(appDataProvider.notifier).updateCustomerAccount(
          customer!.id,
          status: nextStatus,
          administrativeNotes: notes,
        );
  }

  final closeRequests = ValueNotifier<int>(0);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Account details',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final colors = semanticColors(context);
      return SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => closeRequests.value++,
                child: ColoredBox(
                  color: colors.overlayScrim,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 820;
                final width = narrow ? constraints.maxWidth * .94 : 760.0;
                final height = constraints.maxHeight * (narrow ? .9 : .88);
                return FocusScope(
                  autofocus: true,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: narrow ? 0 : 650,
                        maxWidth: 780,
                        maxHeight: height,
                      ),
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: _AccountDetailsDialog(
                          account: account,
                          closeRequests: closeRequests,
                          onSave: (notes) => update(notes, account.status),
                          onUnblock: account.status == AccountStatus.blocked
                              ? (notes) => update(notes, AccountStatus.active)
                              : null,
                          onLift: account.suspension != null &&
                                  account.suspension!.liftedAt == null
                              ? (_) => ref
                                  .read(appDataProvider.notifier)
                                  .liftSuspension(account.suspension!.id)
                              : null,
                          onSuspend: account.status != AccountStatus.blocked &&
                                  (account.suspension == null ||
                                      account.suspension!.liftedAt != null)
                              ? () => showSuspensionDialog(
                                    context,
                                    ref,
                                    accountId: account.id,
                                    accountName: account.name,
                                    accountType: account.accountType,
                                  )
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: .96, end: 1).animate(curve),
          child: child,
        ),
      );
    },
  ).whenComplete(closeRequests.dispose);
}

Future<bool?> showSuspensionDialog(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required String accountName,
  required String accountType,
}) async {
  final reason = TextEditingController();
  final note = TextEditingController();
  var startDate = DateTime.now();
  var endDate = DateTime.now().add(const Duration(days: 7));
  var notifyUser = true;
  var saving = false;

  Future<void> pickDate(
    BuildContext dialogContext,
    bool start,
    StateSetter setDialogState,
  ) async {
    final selected = await showDatePicker(
      context: dialogContext,
      initialDate: start ? startDate : endDate,
      firstDate: start ? DateTime.now() : startDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected == null) return;
    setDialogState(() {
      if (start) {
        startDate = selected;
        if (!endDate.isAfter(startDate)) {
          endDate = startDate.add(const Duration(days: 1));
        }
      } else {
        endDate = selected;
      }
    });
  }

  try {
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Temporarily suspend account'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    accountName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reason,
                    autofocus: true,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Reason *',
                      hintText: 'Policy violation, unpaid fees, etc.',
                    ),
                  ),
                  TextField(
                    controller: note,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Internal note',
                      hintText: 'Optional details for the audit trail',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _dateButton(
                          dialogContext,
                          'Starts',
                          startDate,
                          () => pickDate(dialogContext, true, setDialogState),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dateButton(
                          dialogContext,
                          'Ends',
                          endDate,
                          () => pickDate(dialogContext, false, setDialogState),
                        ),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: notifyUser,
                    onChanged: (value) =>
                        setDialogState(() => notifyUser = value ?? true),
                    title: const Text('Notify the account holder'),
                    subtitle: const Text(
                        'Delivery is recorded locally in demo mode.'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (reason.text.trim().isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text('Enter a suspension reason.')),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      final error = await ref
                          .read(appDataProvider.notifier)
                          .createSuspension(
                            accountId: accountId,
                            accountName: accountName,
                            accountType: accountType,
                            reason: reason.text,
                            startDate: startDate,
                            endDate: endDate,
                            note: note.text,
                            notifyUser: notifyUser,
                          );
                      if (!dialogContext.mounted) return;
                      if (error != null) {
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                        return;
                      }
                      Navigator.pop(dialogContext, true);
                    },
              child: const Text('Suspend account'),
            ),
          ],
        ),
      ),
    );
  } finally {
    reason.dispose();
    note.dispose();
  }
}

Widget _dateButton(
  BuildContext context,
  String label,
  DateTime value,
  VoidCallback onPressed,
) =>
    OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 3),
          Text(shortDate.format(value), style: const TextStyle(fontSize: 12)),
        ],
      ),
    );

class _AccountDrawer extends ConsumerStatefulWidget {
  const _AccountDrawer({required this.vendor});
  final Vendor vendor;
  @override
  ConsumerState<_AccountDrawer> createState() => _AccountDrawerState();
}

class _AccountDrawerState extends ConsumerState<_AccountDrawer> {
  late AccountStatus current = widget.vendor.status;
  @override
  Widget build(BuildContext context) {
    final vendor = ref.watch(appDataProvider).vendors.firstWhere(
          (item) => item.id == widget.vendor.id,
          orElse: () => widget.vendor,
        );
    final colors = semanticColors(context);
    return Material(
      color: colors.elevatedSurface,
      child: SafeArea(
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width < 520
              ? MediaQuery.sizeOf(context).width
              : 410,
          height: double.infinity,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Account Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AvatarCircle(name: vendor.name, size: 56),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vendor.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'ID: ${vendor.id}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                const SizedBox(height: 4),
                                StatusBadge(
                                  label: enumLabel(vendor.status),
                                  kind: vendor.status == AccountStatus.active
                                      ? BadgeKind.success
                                      : vendor.status == AccountStatus.blocked
                                          ? BadgeKind.danger
                                          : BadgeKind.warning,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              context,
                              'RECENT ORDERS',
                              '${vendor.orders}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metric(
                              context,
                              'RECENT REVENUE',
                              '₱${(vendor.transactions / 1000).toStringAsFixed(1)}k',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      const SectionLabel('Contact Information'),
                      const SizedBox(height: 12),
                      _contact(context, 'Email Address', vendor.email),
                      _contact(context, 'Phone Number', vendor.phone),
                      _contact(context, 'Primary Residence', vendor.residence),
                      const SizedBox(height: 17),
                      const SectionLabel('Account Status'),
                      const SizedBox(height: 9),
                      DropdownButtonFormField<AccountStatus>(
                        initialValue: current,
                        items: AccountStatus.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(enumLabel(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => current = value);
                            ref
                                .read(appDataProvider.notifier)
                                .setVendorStatus(vendor.id, value);
                          }
                        },
                      ),
                      const SizedBox(height: 22),
                      const SectionLabel('Recent Activity'),
                      const SizedBox(height: 10),
                      _activity(
                        context,
                        'Renewed Stall Permit #44',
                        'Today at 11:42 AM',
                      ),
                      _activity(
                        context,
                        'Processed monthly maintenance fee',
                        'Yesterday at 4:15 PM',
                      ),
                      _activity(context, 'Updated profile', 'Jan 12, 2024'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: colors.dangerContainer.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Violation History',
                              style: TextStyle(
                                color: colors.danger,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Minor: Stall Encroachment',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Stall extended beyond 2m limit. Warning issued on Nov 05, 2023.',
                              style: TextStyle(fontSize: 10),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No major violations recorded in the last 24 months.',
                              style: TextStyle(
                                fontSize: 9,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: semanticColors(context).infoContainer.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(fontSize: 8)),
          ],
        ),
      );
  Widget _contact(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 8.5)),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => copyToClipboard(context, value),
              icon: const Icon(Icons.copy_rounded, size: 14),
            ),
          ],
        ),
      );
  Widget _activity(BuildContext context, String title, String time) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: semanticColors(context).success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(time, style: const TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
      );
}

class _AccountDetailsData {
  const _AccountDetailsData({
    required this.id,
    required this.name,
    required this.email,
    required this.stallType,
    required this.registeredAt,
    required this.status,
    required this.location,
    required this.orders,
    required this.transactions,
    required this.phone,
    required this.residence,
    required this.accountType,
    required this.administrativeNotes,
    required this.suspension,
    this.blockedReason,
    this.blockedFromReportId,
    this.blockedAt,
    this.blockedBy,
  });

  factory _AccountDetailsData.fromVendor(
    Vendor vendor, {
    Suspension? suspension,
  }) =>
      _AccountDetailsData(
        id: vendor.id,
        name: vendor.name,
        email: vendor.email,
        stallType: vendor.stallType,
        registeredAt: vendor.registeredAt,
        status: vendor.status,
        location: vendor.location,
        orders: vendor.orders,
        transactions: vendor.transactions,
        phone: vendor.phone,
        residence: vendor.residence,
        accountType: 'Stall Holder',
        administrativeNotes: vendor.administrativeNotes,
        suspension: suspension,
        blockedReason: vendor.blockedReason,
        blockedFromReportId: vendor.blockedFromReportId,
        blockedAt: vendor.blockedAt,
        blockedBy: vendor.blockedBy,
      );

  factory _AccountDetailsData.fromCustomer(
    Customer customer, {
    Suspension? suspension,
  }) =>
      _AccountDetailsData(
        id: customer.id,
        name: customer.name,
        email: customer.email,
        stallType: 'Customer Account',
        registeredAt: customer.registeredAt,
        status: customer.status,
        location: 'Customer account',
        orders: 0,
        transactions: customer.transactions.toDouble(),
        phone: 'Not provided',
        residence: 'Not provided',
        accountType: 'Customer',
        administrativeNotes: customer.administrativeNotes,
        suspension: suspension,
        blockedReason: customer.blockedReason,
        blockedFromReportId: customer.blockedFromReportId,
        blockedAt: customer.blockedAt,
        blockedBy: customer.blockedBy,
      );

  final String id;
  final String name;
  final String email;
  final String stallType;
  final DateTime registeredAt;
  final AccountStatus status;
  final String location;
  final int orders;
  final double transactions;
  final String phone;
  final String residence;
  final String accountType;
  final String administrativeNotes;
  final Suspension? suspension;
  final String? blockedReason;
  final String? blockedFromReportId;
  final DateTime? blockedAt;
  final String? blockedBy;
}

class _AccountDetailsDialog extends ConsumerStatefulWidget {
  const _AccountDetailsDialog({
    required this.account,
    required this.closeRequests,
    required this.onSave,
    this.onUnblock,
    this.onLift,
    this.onSuspend,
  });

  final _AccountDetailsData account;
  final ValueNotifier<int> closeRequests;
  final Future<void> Function(String notes) onSave;
  final Future<void> Function(String notes)? onUnblock;
  final Future<void> Function(String notes)? onLift;
  final Future<bool?> Function()? onSuspend;

  @override
  ConsumerState<_AccountDetailsDialog> createState() =>
      _AccountDetailsDialogState();
}

class _AccountDetailsDialogState extends ConsumerState<_AccountDetailsDialog> {
  late final TextEditingController notes = TextEditingController(
    text: widget.account.administrativeNotes,
  );
  bool saving = false;
  bool unblocking = false;
  bool lifting = false;
  bool suspending = false;
  bool closePromptOpen = false;

  bool get dirty => notes.text != widget.account.administrativeNotes;
  bool get busy => saving || unblocking || lifting || suspending;

  @override
  void initState() {
    super.initState();
    widget.closeRequests.addListener(_handleCloseRequest);
  }

  void _handleCloseRequest() => requestClose();

  @override
  void dispose() {
    widget.closeRequests.removeListener(_handleCloseRequest);
    notes.dispose();
    super.dispose();
  }

  Future<void> requestClose() async {
    if (busy || closePromptOpen) return;
    if (!dirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    closePromptOpen = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'Your account changes have not been saved. Close this window anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    closePromptOpen = false;
    if (discard == true) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (!dirty || busy) return;
    setState(() => saving = true);
    try {
      await widget.onSave(notes.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account changes saved.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save account changes: $error')),
      );
      setState(() => saving = false);
    }
  }

  Future<void> _unblock() async {
    if (busy || widget.onUnblock == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unblock account?'),
        content: Text(
          'Restore access for ${widget.account.name}? The account status will '
          'change to Active and the account holder will be able to use '
          'PalengkeGo again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.lock_open_rounded, size: 17),
            label: const Text('Unblock account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => unblocking = true);
    try {
      await widget.onUnblock!(notes.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.account.name} has been unblocked.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to unblock account: $error')),
      );
      setState(() => unblocking = false);
    }
  }

  Future<void> _liftSuspension() async {
    if (busy || widget.onLift == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lift suspension?'),
        content: Text(
          'Restore access for ${widget.account.name}? The account status will '
          'change to Active and the related report will remain resolved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.lock_open_rounded, size: 17),
            label: const Text('Lift suspension'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => lifting = true);
    try {
      await widget.onLift!(widget.account.administrativeNotes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.account.name} is active again.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to lift suspension: $error')),
      );
      setState(() => lifting = false);
    }
  }

  Future<void> _suspend() async {
    if (busy || widget.onSuspend == null) return;
    setState(() => suspending = true);
    try {
      final created = await widget.onSuspend!();
      if (!mounted) return;
      if (created != true) {
        setState(() => suspending = false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.account.name} is now suspended.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to suspend account: $error')),
      );
      setState(() => suspending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        SingleActivator(LogicalKeyboardKey.escape): () => requestClose(),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: colors.elevatedSurface,
          elevation: 20,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _header(context),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summary(context),
                      if (widget.account.status == AccountStatus.suspended &&
                          widget.account.suspension != null) ...[
                        const SizedBox(height: 18),
                        _suspensionInfo(context),
                      ],
                      if (widget.account.status == AccountStatus.blocked) ...[
                        const SizedBox(height: 18),
                        _blockInfo(context),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              context,
                              '${widget.account.orders}',
                              widget.account.accountType == 'Stall Holder'
                                  ? 'RECENT ORDERS'
                                  : 'TOTAL ORDERS',
                              Icons.receipt_long_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              context,
                              '\u20B1${(widget.account.transactions / 1000).toStringAsFixed(1)}K',
                              widget.account.accountType == 'Stall Holder'
                                  ? 'RECENT REVENUE'
                                  : 'TOTAL TRANSACTIONS',
                              Icons.account_balance_wallet_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 21),
                      _sectionTitle('CONTACT INFORMATION'),
                      const SizedBox(height: 10),
                      _contactRow(
                          context, 'Email Address', widget.account.email),
                      _contactRow(
                          context, 'Phone Number', widget.account.phone),
                      _contactRow(
                        context,
                        'Primary Residence',
                        widget.account.residence,
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle('RECENT ACTIVITY'),
                      const SizedBox(height: 10),
                      _activity(context, 'Renewed Stall Permit #44',
                          'Today at 11:42 AM'),
                      _activity(context, 'Processed monthly maintenance fee',
                          'Yesterday at 4:15 PM'),
                      _activity(context, 'Updated profile', 'Jan 12, 2024'),
                      const SizedBox(height: 11),
                      _violationCard(context),
                      const SizedBox(height: 20),
                      _sectionTitle('ADMINISTRATIVE NOTES'),
                      const SizedBox(height: 9),
                      TextField(
                        controller: notes,
                        minLines: 4,
                        maxLines: 4,
                        maxLength: 500,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Add notes about this account...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 12, 13),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    'Account Details',
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Account ID: ${widget.account.id}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: semanticColors(context).mutedText,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: requestClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );

  Widget _summary(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final profile = Row(
            children: [
              AvatarCircle(name: widget.account.name, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.account.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ID: ${widget.account.id}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: semanticColors(context).mutedText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.account.accountType,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: semanticColors(context).mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final metadata = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.account.stallType,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                widget.account.location,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: semanticColors(context).mutedText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Registered ${shortDate.format(widget.account.registeredAt)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: semanticColors(context).mutedText,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 540) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [profile, const SizedBox(height: 12), metadata],
            );
          }
          return Row(
            children: [
              Expanded(child: profile),
              const SizedBox(width: 22),
              SizedBox(width: 190, child: metadata),
            ],
          );
        },
      );

  Widget _suspensionInfo(BuildContext context) {
    final colors = semanticColors(context);
    final suspension = widget.account.suspension!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warningContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.warning.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pause_circle_outline, size: 17, color: colors.warning),
              const SizedBox(width: 8),
              Text(
                'ACCOUNT STATUS',
                style: GoogleFonts.inter(
                  color: colors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              const StatusBadge(label: 'Suspended', kind: BadgeKind.warning),
            ],
          ),
          const SizedBox(height: 12),
          _restrictionDetail('Suspension Reason', suspension.reason),
          if (suspension.relatedReportId != null)
            _restrictionDetail('Related Report', suspension.relatedReportId!),
          _restrictionDetail(
            'Suspension Start',
            longDate.format(suspension.startDate),
          ),
          _restrictionDetail(
            'Suspension End',
            longDate.format(suspension.endDate),
          ),
          _restrictionDetail('Suspended By', suspension.administratorName),
        ],
      ),
    );
  }

  Widget _blockInfo(BuildContext context) {
    final colors = semanticColors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.dangerContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.danger.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block_outlined, size: 17, color: colors.danger),
              const SizedBox(width: 8),
              Text(
                'ACCOUNT STATUS',
                style: GoogleFonts.inter(
                  color: colors.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              const StatusBadge(label: 'Blocked', kind: BadgeKind.danger),
            ],
          ),
          const SizedBox(height: 12),
          _restrictionDetail(
            'Blocking Reason',
            widget.account.blockedReason ?? 'Not provided',
          ),
          if (widget.account.blockedFromReportId != null)
            _restrictionDetail(
              'Related Report',
              widget.account.blockedFromReportId!,
            ),
          if (widget.account.blockedAt != null)
            _restrictionDetail(
              'Blocked On',
              longDate.format(widget.account.blockedAt!),
            ),
          if (widget.account.blockedBy != null)
            _restrictionDetail('Blocked By', widget.account.blockedBy!),
        ],
      ),
    );
  }

  Widget _restrictionDetail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 116,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: semanticColors(context).mutedText,
                ),
              ),
            ),
            Expanded(
              child: Text(value, style: GoogleFonts.inter(fontSize: 11)),
            ),
          ],
        ),
      );

  Widget _statCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    final colors = semanticColors(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.infoContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.heroBackground),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: colors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final color = semanticColors(context).mutedText;
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .25,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: color.withValues(alpha: .25))),
      ],
    );
  }

  Widget _contactRow(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: semanticColors(context).mutedText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy $label',
              onPressed: () => copyToClipboard(context, value),
              icon: const Icon(Icons.copy_rounded, size: 15),
            ),
          ],
        ),
      );

  Widget _activity(BuildContext context, String title, String time) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: semanticColors(context).success,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500)),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: semanticColors(context).mutedText,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _violationCard(BuildContext context) {
    final colors = semanticColors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.dangerContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Violation History',
            style: GoogleFonts.inter(
              color: colors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Minor: Stall Encroachment',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Stall extended beyond the 2m limit. Warning issued on Nov 05, 2023.',
            style: GoogleFonts.inter(fontSize: 10),
          ),
          const SizedBox(height: 7),
          Text(
            'No major violations recorded in the last 24 months.',
            style: GoogleFonts.inter(
              fontSize: 9,
              color: colors.mutedText,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final canUnblock = widget.onUnblock != null;
    final canLift = widget.onLift != null;
    final canSuspend = widget.onSuspend != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 9, 22, 15),
      child: Row(
        children: [
          Expanded(
            child: canUnblock
                ? OutlinedButton.icon(
                    onPressed: busy ? null : _unblock,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: semanticColors(context).success,
                    ),
                    icon: unblocking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open_rounded, size: 17),
                    label: Text(
                      unblocking ? 'Unblocking...' : 'Unblock Account',
                    ),
                  )
                : canLift
                    ? OutlinedButton.icon(
                        onPressed: busy ? null : _liftSuspension,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: semanticColors(context).warning,
                        ),
                        icon: lifting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock_open_rounded, size: 17),
                        label: Text(
                          lifting ? 'Lifting...' : 'Lift Suspension',
                        ),
                      )
                    : canSuspend
                        ? OutlinedButton.icon(
                            onPressed: busy ? null : _suspend,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: semanticColors(context).warning,
                            ),
                            icon: suspending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.pause_circle_outline,
                                    size: 17,
                                  ),
                            label: Text(
                              suspending ? 'Suspending...' : 'Suspend Account',
                            ),
                          )
                        : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: dirty && !busy ? _save : null,
              child: saving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
