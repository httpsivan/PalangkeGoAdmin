import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/utils/export/admin_export_service.dart';
import '../../core/utils/export/module_export_data_builders.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../data/repositories/stall_products_provider.dart';
import '../../models/app_models.dart';
import '../../models/stall_product.dart';

Future<void> showStallProductsDialog(
  BuildContext context, {
  required Vendor vendor,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Stall Products Audit',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1060,
            maxHeight: 780,
          ),
          child: Material(
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            elevation: 16,
            child: _StallProductsAuditView(vendor: vendor),
          ),
        ),
      );
    },
  );
}

class _StallProductsAuditView extends ConsumerStatefulWidget {
  const _StallProductsAuditView({required this.vendor});

  final Vendor vendor;

  @override
  ConsumerState<_StallProductsAuditView> createState() =>
      _StallProductsAuditViewState();
}

class _StallProductsAuditViewState
    extends ConsumerState<_StallProductsAuditView> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _warnedProductIds = {};
  String _selectedStock = 'All Stock Statuses';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final allProducts = ref
        .watch(stallProductsProvider)
        .forVendor(widget.vendor.id, vendorCategory: widget.vendor.stallType);

    // Calculate metrics
    final totalListed = allProducts.length;
    final inStockCount = allProducts.where((p) => !p.isOutOfStock).length;
    final lowStockCount = allProducts.where((p) => p.isLowStock).length;
    final outOfStockCount = allProducts.where((p) => p.isOutOfStock).length;

    // Filter products
    final query = _searchController.text.trim().toLowerCase();
    final filtered = allProducts.where((p) {
      final matchesSearch = query.isEmpty ||
          p.name.toLowerCase().contains(query);

      final matchesStock = switch (_selectedStock) {
        'In Stock Only' => !p.isOutOfStock,
        'Low Stock' => p.isLowStock,
        'Sold Out' => p.isOutOfStock,
        _ => true,
      };

      return matchesSearch && matchesStock;
    }).toList();

    return Container(
      color: colors.elevatedSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          _buildHeader(context, colors, filtered),

          // Metric Badges Strip
          _buildMetricStrip(
            context,
            colors: colors,
            totalListed: totalListed,
            inStockCount: inStockCount,
            lowStockCount: lowStockCount,
            outOfStockCount: outOfStockCount,
          ),

          // Search & Stock Status Toolbar (Category filter removed)
          _buildToolbar(context, colors),

          // Products Table (Category column removed)
          Expanded(
            child: _buildTable(context, filtered, colors),
          ),

          // Footer info
          _buildFooter(context, filtered.length, totalListed, colors),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppSemanticColors colors,
    List<StallProduct> filteredProducts,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
      color: colors.heroBackground,
      child: Row(
        children: [
          AvatarCircle(name: widget.vendor.name, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      widget.vendor.name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Stall Category displayed beside the name of the stall holder to the top left
                    CategoryBadge(
                      category: widget.vendor.stallType,
                      uppercase: true,
                    ),
                    if (widget.vendor.location.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.vendor.location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Stall Holder Product Listing & Price Audit * Market Master View',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ExportButton(
            label: 'Export Audit Sheet',
            backgroundColor: Colors.white,
            foregroundColor: colors.heroBackground,
            borderColor: Colors.white,
            onExportPdf: () => _exportAudit(ExportFormat.pdf, filteredProducts),
            onExportCsv: () => _exportAudit(ExportFormat.csv, filteredProducts),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Future<void> _exportAudit(
    ExportFormat format,
    List<StallProduct> filteredProducts,
  ) async {
    final allProducts = ref.read(stallProductsProvider).forVendor(
          widget.vendor.id,
          vendorCategory: widget.vendor.stallType,
        );

    final filterLabels = <String>[];
    if (_searchController.text.trim().isNotEmpty) {
      filterLabels.add('Search: "${_searchController.text.trim()}"');
    }
    if (_selectedStock != 'All Stock Statuses') {
      filterLabels.add('Stock: $_selectedStock');
    }
    final activeFilters =
        filterLabels.isEmpty ? 'All Records' : filterLabels.join(', ');

    final doc = StallAuditExportData.build(
      vendor: widget.vendor,
      allProducts: allProducts,
      filteredProducts: filteredProducts,
      activeFilters: activeFilters,
    );

    await AdminExportService.export(
      context: context,
      ref: ref,
      doc: doc,
      format: format,
    );
  }

  Widget _buildMetricStrip(
    BuildContext context, {
    required AppSemanticColors colors,
    required int totalListed,
    required int inStockCount,
    required int lowStockCount,
    required int outOfStockCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        border: Border(bottom: BorderSide(color: colors.subtleBorder)),
      ),
      child: Row(
        children: [
          _metricCard(
            label: 'TOTAL LISTED',
            value: '$totalListed items',
            accent: const Color(0xFF0F4A3C),
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(width: 12),
          _metricCard(
            label: 'IN STOCK',
            value: '$inStockCount items',
            accent: const Color(0xFF10B981),
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 12),
          _metricCard(
            label: 'LOW STOCK',
            value: '$lowStockCount items',
            accent: const Color(0xFFF59E0B),
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(width: 12),
          _metricCard(
            label: 'OUT OF STOCK',
            value: '$outOfStockCount items',
            accent: const Color(0xFFEF4444),
            icon: Icons.remove_circle_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required Color accent,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: accent),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    AppSemanticColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search products by name...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _dropdownFilter(
            value: _selectedStock,
            items: const ['All Stock Statuses', 'In Stock Only', 'Low Stock', 'Sold Out'],
            onChanged: (v) => setState(() => _selectedStock = v ?? 'All Stock Statuses'),
          ),
        ],
      ),
    );
  }

  Widget _dropdownFilter({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          items: items
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c, style: const TextStyle(fontSize: 11.5)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<StallProduct> products,
    AppSemanticColors colors,
  ) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No matching stall products found.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Try clearing your search query or filters.',
              style: TextStyle(fontSize: 12, color: colors.mutedText),
            ),
          ],
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3.2), // PRODUCT DETAILS
          1: FlexColumnWidth(1.6), // STALL PRICE
          2: FlexColumnWidth(1.5), // LIVE STOCK
          3: FlexColumnWidth(1.9), // DATE ADDED
          4: FlexColumnWidth(1.4), // ACTIONS
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Table Header
          TableRow(
            decoration: BoxDecoration(
              color: colors.tableHeader,
              border: Border(bottom: BorderSide(color: colors.subtleBorder)),
            ),
            children: const [
              _HeaderCell('PRODUCT DETAILS'),
              _HeaderCell('STALL PRICE'),
              _HeaderCell('LIVE STOCK'),
              _HeaderCell('DATE ADDED'),
              _HeaderCell('ACTIONS', alignRight: true),
            ],
          ),

          // Table Rows
          ...products.map((p) {
            final isWarned = _warnedProductIds.contains(p.id);
            return TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              children: [
                // Product details with stall holder uploaded photo
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Row(
                    children: [
                      _ProductThumbnail(
                        imageUrl: p.imageUrl,
                        fallbackEmoji: p.emoji,
                        colors: colors,
                        size: 42,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isWarned) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.warningContainer,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: colors.warning.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  'WARNING SENT',
                                  style: TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w800,
                                    color: colors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Price
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${currencyFormat.format(p.price)} / ${p.unit}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                // Live Stock Level
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${p.stockQuantity % 1 == 0 ? p.stockQuantity.toInt() : p.stockQuantity.toStringAsFixed(1)} ${p.unit}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: p.isOutOfStock
                              ? const Color(0xFFDC2626)
                              : p.isLowStock
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        p.isOutOfStock
                            ? 'SOLD OUT'
                            : p.isLowStock
                                ? 'LOW STOCK'
                                : 'IN STOCK',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: p.isOutOfStock
                              ? const Color(0xFFDC2626)
                              : p.isLowStock
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),

                // Date & Time when product was added
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(p.dateAdded),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        DateFormat('hh:mm a').format(p.dateAdded),
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions Column (View product & Send price warning - admin has no edit/delete powers)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TableActionIconButton(
                        icon: Icons.visibility_outlined,
                        tooltip: 'View Product & Pricing',
                        onPressed: () => _showProductDetails(context, p),
                      ),
                      const SizedBox(width: 6),
                      TableActionIconButton(
                        icon: isWarned
                            ? Icons.warning_rounded
                            : Icons.warning_amber_rounded,
                        tooltip: isWarned
                            ? 'Price Warning Sent (Send Another)'
                            : 'Send Price Warning',
                        color: colors.warning,
                        onPressed: () => _showSendWarningDialog(context, p),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // --- ACTIONS IMPLEMENTATIONS ---

  void _showProductDetails(BuildContext context, StallProduct p) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final colors = semanticColors(context);
    final isWarned = _warnedProductIds.contains(p.id);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo uploaded by the stall holder (Banner display)
              _ProductPhotoBanner(
                imageUrl: p.imageUrl,
                fallbackEmoji: p.emoji,
                colors: colors,
                height: 170,
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Product Details Grid
                    Row(
                      children: [
                        Expanded(
                          child: _detailTile(
                            label: 'STALL PRICE',
                            value: '${currencyFormat.format(p.price)} / ${p.unit}',
                            icon: Icons.payments_outlined,
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _detailTile(
                            label: 'LIVE INVENTORY',
                            value: '${p.stockQuantity} ${p.unit}',
                            icon: Icons.inventory_2_outlined,
                            colors: colors,
                            statusText: p.isOutOfStock
                                ? 'SOLD OUT'
                                : p.isLowStock
                                    ? 'LOW STOCK'
                                    : 'IN STOCK',
                            statusColor: p.isOutOfStock
                                ? const Color(0xFFDC2626)
                                : p.isLowStock
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _detailTile(
                            label: 'STALL OWNER',
                            value: widget.vendor.name,
                            icon: Icons.storefront_outlined,
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _detailTile(
                            label: 'STALL LOCATION',
                            value: widget.vendor.location.isNotEmpty
                                ? widget.vendor.location
                                : widget.vendor.stallType,
                            icon: Icons.location_on_outlined,
                            colors: colors,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _detailTile(
                      label: 'DATE & TIME ADDED',
                      value: DateFormat('MMMM dd, yyyy • hh:mm a').format(p.dateAdded),
                      icon: Icons.calendar_today_outlined,
                      colors: colors,
                    ),
                    const SizedBox(height: 14),
                    // Price Monitoring Note
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.subtleBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: colors.mutedText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Weekly DTI Suggested Retail Price (SRP) verification. Market Masters can issue price compliance warnings.',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: colors.mutedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showSendWarningDialog(context, p);
            },
            icon: Icon(
              isWarned ? Icons.warning_rounded : Icons.warning_amber_rounded,
              size: 15,
              color: colors.warning,
            ),
            label: Text(
              isWarned ? 'Warning Sent (Send Again)' : 'Send Price Warning',
              style: TextStyle(
                color: colors.warning,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colors.warning.withValues(alpha: 0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.heroBackground,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailTile({
    required String label,
    required String value,
    required IconData icon,
    required AppSemanticColors colors,
    String? statusText,
    Color? statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.hoverSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.subtleBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.mutedText),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: colors.mutedText,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (statusText != null && statusColor != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSendWarningDialog(BuildContext context, StallProduct p) {
    final colors = semanticColors(context);
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final messageController = TextEditingController(
      text:
          'Notice regarding "${p.name}" (Current Stall Price: ${currencyFormat.format(p.price)} / ${p.unit}): In accordance with weekly Monday DTI Suggested Retail Price (SRP) monitoring, please review and adjust your pricing to ensure compliance.',
    );

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.warningContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, size: 20, color: colors.warning),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Send Price Warning',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'DTI Weekly Price Audit • Monday Verification',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.hoverSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.subtleBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Stall Holder: ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.mutedText,
                          ),
                        ),
                        Text(
                          widget.vendor.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.vendor.location.isNotEmpty) ...[
                          Text(
                            ' • ${widget.vendor.location}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.mutedText,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Product: ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.mutedText,
                          ),
                        ),
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${currencyFormat.format(p.price)} / ${p.unit}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: colors.heroBackground,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Warning Notice Message',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: messageController,
                maxLines: 4,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Enter price compliance warning message...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _warnedProductIds.add(p.id);
              });
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Price compliance warning sent to ${widget.vendor.name} for ${p.name}.',
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: colors.warning,
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 14),
            label: const Text('Send Warning', style: TextStyle(fontSize: 11.5)),
            style: FilledButton.styleFrom(
              backgroundColor: colors.warning,
              foregroundColor: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    int showing,
    int total,
    AppSemanticColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        border: Border(top: BorderSide(color: colors.subtleBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $showing of $total products for ${widget.vendor.name}',
            style: TextStyle(fontSize: 11, color: colors.mutedText),
          ),
          Text(
            'PalengkeGo Market Master & Stall Inventory System',
            style: TextStyle(
              fontSize: 10,
              color: colors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.title, {this.alignRight = false});

  final String title;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        title,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}

/// Thumbnail component for stall holder uploaded product photos
class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({
    required this.imageUrl,
    required this.fallbackEmoji,
    required this.colors,
    this.size = 40,
  });

  final String imageUrl;
  final String fallbackEmoji;
  final AppSemanticColors colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.subtleBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? (imageUrl.startsWith('assets/')
              ? Image.asset(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackWidget(),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackWidget(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: size * 0.4,
                        height: size * 0.4,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ))
          : _fallbackWidget(),
    );
  }

  Widget _fallbackWidget() {
    return Center(
      child: fallbackEmoji.isNotEmpty
          ? Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.48))
          : Icon(Icons.storefront_outlined, size: size * 0.5, color: colors.mutedText),
    );
  }
}

/// High resolution banner component for modal preview of uploaded photo
class _ProductPhotoBanner extends StatelessWidget {
  const _ProductPhotoBanner({
    required this.imageUrl,
    required this.fallbackEmoji,
    required this.colors,
    this.height = 160,
  });

  final String imageUrl;
  final String fallbackEmoji;
  final AppSemanticColors colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFF0F4A3C).withValues(alpha: 0.08),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            (imageUrl.startsWith('assets/')
                ? Image.asset(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackBanner(),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackBanner(),
                  ))
          else
            _fallbackBanner(),

          // Subtle gradient overlay for visual clarity
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Uploaded by Stall Holder Badge
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 12, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Photo uploaded by stall holder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackBanner() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(fallbackEmoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 6),
          Text(
            'Uploaded Product Photo',
            style: TextStyle(fontSize: 11, color: colors.mutedText),
          ),
        ],
      ),
    );
  }
}
