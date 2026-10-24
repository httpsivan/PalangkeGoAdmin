import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/export/admin_export_service.dart';
import '../../core/utils/export/module_export_data_builders.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../data/repositories/mock_repository.dart';
import '../../models/admin_models.dart';
import '../../models/app_models.dart';

String _accountRevenue(num? value) {
  final amount = value ?? 0;
  if (!amount.isFinite || amount <= 0) return '₱0';
  return '₱${NumberFormat.decimalPattern().format(amount)}';
}

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({
    super.key,
    this.selectedAccountId,
    this.openDetailsOnLoad = false,
    this.initialTab,
  });

  final String? selectedAccountId;
  final bool openDetailsOnLoad;
  final String? initialTab;

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
  void initState() {
    super.initState();
    customers = widget.initialTab == 'customers';
  }

  @override
  void didUpdateWidget(covariant AccountsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() {
        customers = widget.initialTab == 'customers';
        status = 'All Statuses';
        search.clear();
      });
      _resetTable();
    }
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
                onTap: () {
                  setState(() {
                    customers = false;
                    status = 'Active';
                  });
                  _resetTable();
                },
              ),
            if (!customers)
              MetricCardData(
                value:
                    '${data.vendors.where((v) => v.closureRequestedAt != null).length}',
                label: 'Closure Requests',
                icon: Icons.store_mall_directory_outlined,
                accent: const Color(0xFFF97316),
                onTap: () {
                  setState(() {
                    customers = false;
                    status = 'Closure Requested';
                  });
                  _resetTable();
                },
              ),
            if (!customers)
              MetricCardData(
                value:
                    '${data.vendors.where((v) => v.relocationRequestedAt != null).length}',
                label: 'Relocation Requests',
                icon: Icons.edit_location_alt_outlined,
                accent: const Color(0xFF0284C7),
                onTap: () {
                  setState(() {
                    customers = false;
                    status = 'Relocation Requested';
                  });
                  _resetTable();
                },
              ),
            if (!customers)
              MetricCardData(
                value:
                    '${data.vendors.where((v) => v.status == AccountStatus.blocked && (v.blockedReason?.toLowerCase().contains('stall closed') == true || v.blockedReason?.toLowerCase().contains('closed upon') == true)).length}',
                label: 'Closed Stalls',
                icon: Icons.inventory_2_outlined,
                accent: const Color(0xFF64748B),
                onTap: () {
                  setState(() {
                    customers = false;
                    status = 'Closed';
                  });
                  _resetTable();
                },
              ),
            if (customers)
              MetricCardData(
                value:
                    '${data.customers.where((c) => c.status == AccountStatus.active).length}',
                label: 'Active Customers',
                icon: Icons.people_outline_rounded,
                accent: const Color(0xFF3B82F6),
                onTap: () {
                  setState(() {
                    customers = true;
                    status = 'Active';
                  });
                  _resetTable();
                },
              ),
            MetricCardData(
              value: customers
                  ? '${data.customers.where((c) => c.status == AccountStatus.suspended).length}'
                  : '${data.vendors.where((v) => v.status == AccountStatus.suspended).length}',
              label: 'Suspended Accounts',
              icon: Icons.pause_circle_outline_rounded,
              accent: const Color(0xFFF59E0B),
              onTap: () {
                setState(() => status = 'Suspended');
                _resetTable();
              },
            ),
            MetricCardData(
              value: customers
                  ? '${data.customers.where((c) => c.status == AccountStatus.blocked).length}'
                  : '${data.vendors.where((v) => v.status == AccountStatus.blocked && !(v.blockedReason?.toLowerCase().contains('stall closed') == true || v.blockedReason?.toLowerCase().contains('closed upon') == true)).length}',
              label: customers ? 'Blocked Customers' : 'Blocked Stall Holders',
              icon: Icons.block_rounded,
              accent: const Color(0xFFEF4444),
              onTap: () {
                setState(() => status = 'Blocked');
                _resetTable();
              },
            ),
          ],
          tabs: _Tabs(
            selected: customers,
            onChanged: (value) {
              if (customers != value) {
                setState(() {
                  customers = value;
                  status = 'All Statuses';
                  search.clear();
                });
                _resetTable();
              }
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
        setState(() {
          customers = true;
          status = 'All Statuses';
        });
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
            (status == 'All Statuses' ||
                (status == 'Closure Requested'
                    ? v.closureRequestedAt != null
                    : status == 'Relocation Requested'
                        ? v.relocationRequestedAt != null
                        : status == 'Closed'
                            ? (v.status == AccountStatus.blocked &&
                                (v.blockedReason
                                            ?.toLowerCase()
                                            .contains('stall closed') ==
                                        true ||
                                    v.blockedReason
                                            ?.toLowerCase()
                                            .contains('closed upon') ==
                                        true))
                            : status == 'Blocked'
                                ? (v.status == AccountStatus.blocked &&
                                    !(v.blockedReason
                                                ?.toLowerCase()
                                                .contains('stall closed') ==
                                            true ||
                                        v.blockedReason
                                                ?.toLowerCase()
                                                .contains('closed upon') ==
                                            true))
                                : enumLabel(v.status) == status)) &&
            (stallCategory == 'All Categories' || v.stallType == stallCategory),
      )
      .toList();
  String get effectiveCustomerStatus =>
      const ['All Statuses', 'Active', 'Suspended', 'Blocked'].contains(status)
          ? status
          : 'All Statuses';

  List<Customer> get filteredCustomers => ref
      .read(appDataProvider)
      .customers
      .where(
        (v) =>
            (search.text.trim().isEmpty ||
                '${v.name} ${v.email} ${v.id}'.toLowerCase().contains(
                      search.text.trim().toLowerCase(),
                    )) &&
            (effectiveCustomerStatus == 'All Statuses' ||
                enumLabel(v.status) == effectiveCustomerStatus),
      )
      .toList();

  Widget _vendorPanel(List<Vendor> values) {
    final categories = <String>[
      'All Categories',
      ...values.map((v) => v.stallType).toSet(),
    ];
    final visible = values
        .where(
          (v) =>
              (search.text.trim().isEmpty ||
                  '${v.name} ${v.email} ${v.id} ${v.stallType}'
                      .toLowerCase()
                      .contains(search.text.trim().toLowerCase())) &&
              (status == 'All Statuses' ||
                  (status == 'Closure Requested'
                      ? v.closureRequestedAt != null
                      : status == 'Relocation Requested'
                          ? v.relocationRequestedAt != null
                          : status == 'Closed'
                              ? (v.status == AccountStatus.blocked &&
                                  (v.blockedReason
                                              ?.toLowerCase()
                                              .contains('stall closed') ==
                                          true ||
                                      v.blockedReason
                                              ?.toLowerCase()
                                              .contains('closed upon') ==
                                          true))
                              : status == 'Blocked'
                                  ? (v.status == AccountStatus.blocked &&
                                      !(v.blockedReason
                                                  ?.toLowerCase()
                                                  .contains('stall closed') ==
                                              true ||
                                          v.blockedReason
                                                  ?.toLowerCase()
                                                  .contains('closed upon') ==
                                              true))
                                  : enumLabel(v.status) == status)) &&
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
                'Closure Requested',
                'Relocation Requested',
                'Closed',
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
              ExportButton(
                onExportPdf: () => _exportStallHolders(
                  allVendors: values,
                  filteredVendors: visible,
                  format: ExportFormat.pdf,
                ),
                onExportExcel: () => _exportStallHolders(
                  allVendors: values,
                  filteredVendors: visible,
                  format: ExportFormat.excel,
                ),
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
    final customerStatus = effectiveCustomerStatus;
    final visible = values
        .where(
          (v) =>
              (search.text.trim().isEmpty ||
                  '${v.name} ${v.email} ${v.id}'.toLowerCase().contains(
                        search.text.trim().toLowerCase(),
                      )) &&
              (customerStatus == 'All Statuses' ||
                  enumLabel(v.status) == customerStatus),
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
              _filter(customerStatus, [
                'All Statuses',
                'Active',
                'Suspended',
                'Blocked',
              ], (v) {
                status = v;
                _resetTable();
              }),
              ExportButton(
                onExportPdf: () => _exportCustomers(
                  allCustomers: values,
                  filteredCustomers: visible,
                  format: ExportFormat.pdf,
                ),
                onExportExcel: () => _exportCustomers(
                  allCustomers: values,
                  filteredCustomers: visible,
                  format: ExportFormat.excel,
                ),
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

  Future<void> _exportStallHolders({
    required List<Vendor> allVendors,
    required List<Vendor> filteredVendors,
    required ExportFormat format,
  }) async {
    final filters = <String>[
      'Stall Holders',
      if (status != 'All Statuses') 'Status: $status',
      if (stallCategory != 'All Categories') 'Stall Category: $stallCategory',
      if (search.text.trim().isNotEmpty) 'Search: "${search.text.trim()}"',
    ];
    final doc = AccountsExportData.buildStallHolders(
      allVendors: allVendors,
      filteredVendors: filteredVendors,
      activeFilters: filters.join(' | '),
    );
    await AdminExportService.export(
      context: context,
      ref: ref,
      doc: doc,
      format: format,
    );
  }

  Future<void> _exportCustomers({
    required List<Customer> allCustomers,
    required List<Customer> filteredCustomers,
    required ExportFormat format,
  }) async {
    final filters = <String>[
      'Customers',
      if (effectiveCustomerStatus != 'All Statuses')
        'Status: $effectiveCustomerStatus',
      if (search.text.trim().isNotEmpty) 'Search: "${search.text.trim()}"',
    ];
    final doc = AccountsExportData.buildCustomers(
      allCustomers: allCustomers,
      filteredCustomers: filteredCustomers,
      activeFilters: filters.join(' | '),
    );
    await AdminExportService.export(
      context: context,
      ref: ref,
      doc: doc,
      format: format,
    );
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
                vendor.closureRequestedAt != null
                    ? const StatusBadge(
                        label: 'Closure Requested',
                        kind: BadgeKind.warning,
                      )
                    : vendor.relocationRequestedAt != null
                        ? const StatusBadge(
                            label: 'Relocation Requested',
                            kind: BadgeKind.info,
                          )
                        : (vendor.status == AccountStatus.blocked &&
                                (vendor.blockedReason
                                            ?.toLowerCase()
                                            .contains('stall closed') ==
                                        true ||
                                    vendor.blockedReason
                                            ?.toLowerCase()
                                            .contains('closed upon') ==
                                        true))
                            ? const StatusBadge(
                                label: 'Closed',
                                kind: BadgeKind.danger,
                              )
                            : StatusBadge(
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
                          onBlock: account.status != AccountStatus.blocked
                              ? (notes) => update(notes, AccountStatus.blocked)
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
                          onCloseStall: vendor != null &&
                                  account.status != AccountStatus.blocked
                              ? (notes) => ref
                                  .read(appDataProvider.notifier)
                                  .approveVendorClosure(
                                    vendor.id,
                                    administrativeNotes: notes,
                                  )
                              : null,
                          onDismissClosure: vendor != null &&
                                  account.closureRequestedAt != null
                              ? (notes) => ref
                                  .read(appDataProvider.notifier)
                                  .dismissVendorClosureRequest(
                                    vendor.id,
                                    administrativeNotes: notes,
                                  )
                              : null,
                          onReassignLocation: vendor != null
                              ? (newLoc, newCat, notes) => ref
                                  .read(appDataProvider.notifier)
                                  .reassignVendorLocation(
                                    vendor.id,
                                    newLocation: newLoc,
                                    newCategory: newCat,
                                    administrativeNotes: notes,
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
    Future.delayed(const Duration(milliseconds: 300), () {
      reason.dispose();
      note.dispose();
    });
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
                              _accountRevenue(vendor.transactions),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      const SectionLabel('Contact Information'),
                      const SizedBox(height: 12),
                      _contact(context, 'Email Address', vendor.email),
                      _contact(context, 'Phone Number', vendor.phone),
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
    this.closureRequestedAt,
    this.closureReason,
    this.relocationRequestedAt,
    this.relocationTargetLocation,
    this.relocationReason,
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
        closureRequestedAt: vendor.closureRequestedAt,
        closureReason: vendor.closureReason,
        relocationRequestedAt: vendor.relocationRequestedAt,
        relocationTargetLocation: vendor.relocationTargetLocation,
        relocationReason: vendor.relocationReason,
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
  final DateTime? closureRequestedAt;
  final String? closureReason;
  final DateTime? relocationRequestedAt;
  final String? relocationTargetLocation;
  final String? relocationReason;
}

class _AccountDetailsDialog extends ConsumerStatefulWidget {
  const _AccountDetailsDialog({
    required this.account,
    required this.closeRequests,
    required this.onSave,
    this.onUnblock,
    this.onLift,
    this.onSuspend,
    this.onBlock,
    this.onCloseStall,
    this.onDismissClosure,
    this.onReassignLocation,
  });

  final _AccountDetailsData account;
  final ValueNotifier<int> closeRequests;
  final Future<void> Function(String notes) onSave;
  final Future<void> Function(String notes)? onUnblock;
  final Future<void> Function(String notes)? onLift;
  final Future<bool?> Function()? onSuspend;
  final Future<void> Function(String notes)? onBlock;
  final Future<void> Function(String notes)? onCloseStall;
  final Future<void> Function(String notes)? onDismissClosure;
  final Future<void> Function(
          String newLocation, String? newCategory, String notes)?
      onReassignLocation;

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
  bool blocking = false;
  bool closing = false;
  bool dismissing = false;
  bool reassigning = false;
  bool closePromptOpen = false;

  bool get dirty => notes.text != widget.account.administrativeNotes;
  bool get busy =>
      saving ||
      unblocking ||
      lifting ||
      suspending ||
      blocking ||
      closing ||
      dismissing ||
      reassigning;

  int get activeOrderCount {
    if (widget.account.accountType != 'Stall Holder') return 0;
    final orders = ref.read(appDataProvider).orders;
    return orders
        .where(
          (o) =>
              (o.transactionId == widget.account.id ||
                  o.vendorName == widget.account.name) &&
              (o.status == OrderStatus.pending ||
                  o.status == OrderStatus.processing),
        )
        .length;
  }

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
    if (busy) return;
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

  Future<void> _block() async {
    if (busy || widget.onBlock == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block account?'),
        content: Text(
          'Block access for ${widget.account.name}? The account status will '
          'change to Blocked and the account holder will not be able to use '
          'PalengkeGo.',
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
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.block_outlined, size: 17),
            label: const Text('Block account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => blocking = true);
    try {
      await widget.onBlock!(notes.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.account.name} has been blocked.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to block account: $error')),
      );
      setState(() => blocking = false);
    }
  }

  Future<void> _unblock() async {
    if (busy || widget.onUnblock == null) return;
    final isStallClosed = widget.account.accountType == 'Stall Holder' &&
        (widget.account.blockedReason?.toLowerCase().contains('stall closed') ==
                true ||
            widget.account.blockedReason
                    ?.toLowerCase()
                    .contains('closed upon') ==
                true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(isStallClosed ? 'Reopen stall account?' : 'Unblock account?'),
        content: Text(
          isStallClosed
              ? 'Reopen the stall account for ${widget.account.name}? The account status will change to Active, allowing the stall holder to resume operations on PalengkeGo.'
              : 'Restore access for ${widget.account.name}? The account status will change to Active and the account holder will be able to use PalengkeGo again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.lock_open_rounded, size: 17),
            label: Text(isStallClosed ? 'Reopen Stall' : 'Unblock account'),
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
        SnackBar(
          content: Text(
            isStallClosed
                ? 'Stall account for ${widget.account.name} is reactivated.'
                : 'Account is restored and user can log in again',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to restore account: $error')),
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

  Future<void> _approveClosure() async {
    if (busy || widget.onCloseStall == null) return;
    final activeCount = activeOrderCount;
    if (activeCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('Cannot close stall'),
            ],
          ),
          content: Text(
            '${widget.account.name} has $activeCount active order(s) in progress (Pending or Processing). '
            'All active customer orders must be fulfilled or refunded before this stall can be closed.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final closureReasonController = TextEditingController(
      text: widget.account.closureReason?.isNotEmpty == true
          ? widget.account.closureReason
          : 'Stall closure requested by vendor.',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve stall closure?'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deactivate ${widget.account.name} and close their stall? '
                'The vendor account will be blocked from logging in, their stall space '
                'will be marked as vacated, and all past sales and transaction history '
                'will remain securely archived.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: closureReasonController,
                decoration: const InputDecoration(
                  labelText: 'Closure Reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.store_mall_directory_outlined, size: 17),
            label: const Text('Approve & Close Stall'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => closing = true);
    try {
      final reason = closureReasonController.text.trim();
      final finalNotes = notes.text.trim().isEmpty
          ? 'Stall closed on ${DateFormat('MMM dd, yyyy').format(DateTime.now())}. Reason: $reason'
          : '${notes.text.trim()}\n[Closure Approved] $reason';
      await widget.onCloseStall!(finalNotes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.account.name} stall closed and account deactivated.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to close stall: $e')),
      );
      setState(() => closing = false);
    }
  }

  Future<void> _dismissClosure() async {
    if (busy || widget.onDismissClosure == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dismiss closure request?'),
        content: Text(
          'Keep ${widget.account.name} active and dismiss their pending closure request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Dismiss Request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => dismissing = true);
    try {
      final finalNotes = notes.text.trim().isEmpty
          ? 'Closure request dismissed by administrator.'
          : '${notes.text.trim()}\n[Closure Request Dismissed]';
      await widget.onDismissClosure!(finalNotes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Closure request for ${widget.account.name} dismissed.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to dismiss request: $e')),
      );
      setState(() => dismissing = false);
    }
  }

  Future<void> _reassignLocation() async {
    if (busy || widget.onReassignLocation == null) return;
    final locController = TextEditingController(
      text: widget.account.relocationTargetLocation ?? widget.account.location,
    );
    final noteController = TextEditingController(
      text: widget.account.relocationReason != null
          ? 'Relocation approved: ${widget.account.relocationReason}'
          : '',
    );
    var selectedCategory = widget.account.stallType;
    final categories = const [
      'Meat',
      'Fish',
      'Fruits',
      'Vegetables',
      'Dry Goods',
      'Spices',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reassign Stall Location'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update market stall assignment for ${widget.account.name}. The previous stall space will be released.',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locController,
                  decoration: const InputDecoration(
                    labelText: 'New Stall Location / Number',
                    hintText: 'e.g. Stall #05, Meat Section',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: categories.contains(selectedCategory)
                      ? selectedCategory
                      : categories.first,
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedCategory = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Stall Category',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Administrative Notes / Reason',
                    hintText: 'e.g. Relocation approved per MEPO request',
                    border: OutlineInputBorder(),
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
              onPressed: () {
                if (locController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Save Reassignment'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final newLoc = locController.text.trim();
    if (newLoc.isEmpty) return;

    setState(() => reassigning = true);
    try {
      final reason = noteController.text.trim().isEmpty
          ? 'Stall relocated from ${widget.account.location} to $newLoc.'
          : noteController.text.trim();
      await widget.onReassignLocation!(newLoc, selectedCategory, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stall reassigned to $newLoc successfully.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to reassign stall: $e')),
      );
      setState(() => reassigning = false);
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
                      if (widget.account.closureRequestedAt != null) ...[
                        const SizedBox(height: 18),
                        _closureRequestBanner(context),
                      ],
                      if (widget.account.relocationRequestedAt != null) ...[
                        const SizedBox(height: 18),
                        _relocationRequestBanner(context),
                      ],
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
                              widget.account.accountType == 'Stall Holder'
                                  ? '${widget.account.orders}'
                                  : '${widget.account.transactions.toInt()}',
                              widget.account.accountType == 'Stall Holder'
                                  ? 'RECENT ORDERS'
                                  : 'TOTAL ORDERS',
                              Icons.receipt_long_outlined,
                            ),
                          ),
                          if (widget.account.accountType == 'Stall Holder') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _statCard(
                                context,
                                _accountRevenue(widget.account.transactions),
                                'RECENT REVENUE',
                                Icons.account_balance_wallet_outlined,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 21),
                      _sectionTitle('CONTACT INFORMATION'),
                      const SizedBox(height: 10),
                      _contactRow(
                          context, 'Email Address', widget.account.email),
                      _contactRow(
                          context, 'Phone Number', widget.account.phone),
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
                    Row(
                      children: [
                        Text(
                          widget.account.accountType,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: semanticColors(context).mutedText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.account.accountType == 'Stall Holder' &&
                            widget.account.status == AccountStatus.blocked &&
                            (widget.account.blockedReason
                                        ?.toLowerCase()
                                        .contains('stall closed') ==
                                    true ||
                                widget.account.blockedReason
                                        ?.toLowerCase()
                                        .contains('closed upon') ==
                                    true))
                          const StatusBadge(
                            label: 'Closed & Archived',
                            kind: BadgeKind.danger,
                          )
                        else if (widget.account.closureRequestedAt != null)
                          const StatusBadge(
                            label: 'Closure Requested',
                            kind: BadgeKind.warning,
                          )
                        else if (widget.account.relocationRequestedAt != null)
                          const StatusBadge(
                            label: 'Relocation Requested',
                            kind: BadgeKind.info,
                          )
                        else
                          StatusBadge(
                            label: enumLabel(widget.account.status),
                            kind: widget.account.status == AccountStatus.active
                                ? BadgeKind.success
                                : widget.account.status == AccountStatus.blocked
                                    ? BadgeKind.danger
                                    : BadgeKind.warning,
                          ),
                      ],
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

  Widget _closureRequestBanner(BuildContext context) {
    final colors = semanticColors(context);
    final activeCount = activeOrderCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warningContainer.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.warning.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store_mall_directory_outlined,
                  size: 18, color: colors.warning),
              const SizedBox(width: 8),
              Text(
                'STALL CLOSURE REQUESTED',
                style: GoogleFonts.inter(
                  color: colors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              const StatusBadge(
                  label: 'Pending Review', kind: BadgeKind.warning),
            ],
          ),
          const SizedBox(height: 10),
          _restrictionDetail(
            'Reason Given',
            widget.account.closureReason ?? 'Vendor requested account removal',
          ),
          if (widget.account.closureRequestedAt != null)
            _restrictionDetail(
              'Requested On',
              longDate.format(widget.account.closureRequestedAt!),
            ),
          _restrictionDetail(
            'Active Orders',
            activeCount > 0
                ? '$activeCount active order(s) in progress (Must complete/refund first)'
                : '0 active orders (Clear to close stall)',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.danger,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: busy ? null : _approveClosure,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Approve Closure'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: busy ? null : _dismissClosure,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Dismiss Request'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _relocationRequestBanner(BuildContext context) {
    final colors = semanticColors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.infoContainer.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.heroBackground.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_location_alt_outlined,
                  size: 18, color: colors.heroBackground),
              const SizedBox(width: 8),
              Text(
                'STALL RELOCATION REQUESTED',
                style: GoogleFonts.inter(
                  color: colors.heroBackground,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              const StatusBadge(label: 'Pending Review', kind: BadgeKind.info),
            ],
          ),
          const SizedBox(height: 10),
          _restrictionDetail(
            'Current Stall',
            widget.account.location,
          ),
          if (widget.account.relocationTargetLocation != null)
            _restrictionDetail(
              'Target Stall',
              widget.account.relocationTargetLocation!,
            ),
          if (widget.account.relocationReason != null)
            _restrictionDetail(
              'Reason Given',
              widget.account.relocationReason!,
            ),
          if (widget.account.relocationRequestedAt != null)
            _restrictionDetail(
              'Requested On',
              longDate.format(widget.account.relocationRequestedAt!),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.heroBackground,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: busy ? null : _reassignLocation,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Review & Reassign'),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
    final isStallClosed = widget.account.accountType == 'Stall Holder' &&
        (widget.account.blockedReason?.toLowerCase().contains('stall closed') ==
                true ||
            widget.account.blockedReason
                    ?.toLowerCase()
                    .contains('closed upon') ==
                true);

    if (isStallClosed) {
      // Keep permanently closed stalls visually distinct from ordinary blocks.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.dangerContainer.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: colors.subtleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 17, color: colors.danger),
                const SizedBox(width: 8),
                Text(
                  'STALL CLOSED & ARCHIVED',
                  style: GoogleFonts.inter(
                    color: colors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                const StatusBadge(label: 'Archived', kind: BadgeKind.danger),
              ],
            ),
            const SizedBox(height: 12),
            _restrictionDetail(
              'Closure Reason',
              widget.account.blockedReason ??
                  'Stall operations closed upon vendor request.',
            ),
            if (widget.account.blockedAt != null)
              _restrictionDetail(
                'Closed On',
                longDate.format(widget.account.blockedAt!),
              ),
            if (widget.account.blockedBy != null)
              _restrictionDetail('Authorized By', widget.account.blockedBy!),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.infoContainer.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 15, color: colors.heroBackground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Historical order history, sales analytics, and transaction records remain permanently preserved for reporting. Vendor portal login is deactivated.',
                      style: GoogleFonts.inter(fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
    final isStallClosed = widget.account.accountType == 'Stall Holder' &&
        (widget.account.blockedReason?.toLowerCase().contains('stall closed') ==
                true ||
            widget.account.blockedReason
                    ?.toLowerCase()
                    .contains('closed upon') ==
                true);
    final canUnblock = widget.onUnblock != null;
    final canLift = widget.onLift != null;
    final canSuspend = widget.onSuspend != null;
    final canBlock = widget.onBlock != null;
    final canCloseStall = widget.onCloseStall != null &&
        widget.account.accountType == 'Stall Holder' &&
        widget.account.status != AccountStatus.blocked &&
        widget.account.closureRequestedAt == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
      child: Row(
        children: [
          if (canUnblock) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : _unblock,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  elevation: 0,
                ),
                icon: unblocking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_open_rounded,
                        size: 16, color: Colors.white),
                label: Text(
                  unblocking
                      ? 'Processing...'
                      : isStallClosed
                          ? 'Reopen Stall'
                          : 'Unblock',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ] else if (canLift) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _liftSuspension,
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFFBBF24), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
                icon: lifting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_rounded, size: 16),
                label: Text(
                  lifting ? 'Lifting...' : 'Lift',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ] else if (canSuspend) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _suspend,
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFFEF3C7).withValues(alpha: 0.55),
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFFBBF24), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
                icon: suspending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.pause_circle_outline,
                        size: 16, color: Color(0xFFD97706)),
                label: Text(
                  suspending ? 'Suspending...' : 'Suspend',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ],
          if (canBlock) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _block,
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFFEE2E2).withValues(alpha: 0.55),
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFF87171), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
                icon: blocking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.block_outlined,
                        size: 16, color: Color(0xFFDC2626)),
                label: Text(
                  blocking ? 'Blocking...' : 'Block',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ],
          if (canCloseStall) ...[
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : _approveClosure,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  elevation: 0,
                ),
                icon: closing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.storefront_outlined,
                        size: 16, color: Colors.white),
                label: Text(
                  closing ? 'Closing...' : 'Close Stall',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.white),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                elevation: 0,
              ),
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded,
                      size: 16, color: Colors.white),
              label: const Text(
                'Save Changes',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
