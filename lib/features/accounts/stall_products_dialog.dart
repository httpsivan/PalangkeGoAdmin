import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/supabase_admin_service.dart';
import '../../models/admin_models.dart';
import '../../models/app_models.dart';

Future<void> showStallProductsDialog(
  BuildContext context, {
  required Vendor vendor,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _StallProductsDialog(vendor: vendor),
  );
}

class _StallProductsDialog extends ConsumerStatefulWidget {
  const _StallProductsDialog({required this.vendor});

  final Vendor vendor;

  @override
  ConsumerState<_StallProductsDialog> createState() =>
      _StallProductsDialogState();
}

class _StallProductsDialogState extends ConsumerState<_StallProductsDialog> {
  late Future<List<AdminProduct>> _products;
  final _searchController = TextEditingController();
  String _stockFilter = 'All';
  final Set<String> _sendingWarnings = {};

  @override
  void initState() {
    super.initState();
    _products = _fetchProducts();
  }

  Future<List<AdminProduct>> _fetchProducts() => ref
      .read(supabaseAdminServiceProvider)
      .fetchVendorProducts(widget.vendor.id);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        title: Row(
          children: [
            Expanded(child: Text('${widget.vendor.name} · Products')),
            IconButton(
              tooltip: 'Refresh products',
              onPressed: () => setState(() => _products = _fetchProducts()),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        content: SizedBox(
          width: 850,
          height: 560,
          child: FutureBuilder<List<AdminProduct>>(
            future: _products,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 36),
                        const SizedBox(height: 10),
                        const Text('Could not load live products.'),
                        const SizedBox(height: 8),
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _products = _fetchProducts()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = snapshot.data!;
              final query = _searchController.text.trim().toLowerCase();
              final shown = products.where((product) {
                final matchesQuery = query.isEmpty ||
                    '${product.name} ${product.description} ${product.category}'
                        .toLowerCase()
                        .contains(query);
                final matchesStock = switch (_stockFilter) {
                  'In stock' => product.isInStock && product.stockQuantity > 0,
                  'Out of stock' =>
                    !product.isInStock || product.stockQuantity <= 0,
                  _ => true,
                };
                return matchesQuery && matchesStock;
              }).toList();
              final inStock = products
                  .where((p) => p.isInStock && p.stockQuantity > 0)
                  .length;
              final outOfStock = products.length - inStock;
              return Column(
                children: [
                  Row(
                    children: [
                      _metric('TOTAL LISTED', products.length, Colors.teal),
                      const SizedBox(width: 8),
                      _metric('IN STOCK', inStock, Colors.green),
                      const SizedBox(width: 8),
                      _metric('OUT OF STOCK', outOfStock, Colors.red),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search this stall’s products',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _stockFilter,
                        items: const ['All', 'In stock', 'Out of stock']
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _stockFilter = value ?? 'All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: products.isEmpty
                        ? const Center(
                            child: Text('This stall has no listed products.'))
                        : shown.isEmpty
                            ? const Center(
                                child: Text('No products match these filters.'))
                            : ListView.separated(
                                itemCount: shown.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) =>
                                    _productRow(shown[index]),
                              ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'Showing ${shown.length} of ${products.length} live products'),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      );

  Widget _metric(String label, int count, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            border: Border.all(color: color.withValues(alpha: .2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('$count items',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  Widget _productRow(AdminProduct product) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox.square(
            dimension: 48,
            child: product.imageUrl == null || product.imageUrl!.isEmpty
                ? const ColoredBox(
                    color: Color(0xFFE9EEF2),
                    child: Icon(Icons.inventory_2_outlined))
                : Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFE9EEF2),
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
        ),
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${product.category.isEmpty ? 'Uncategorized' : product.category} · ${product.stallLocation.isEmpty ? widget.vendor.location : product.stallLocation}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 250,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        product.listedPrice == null
                            ? 'Price not set'
                            : '₱${NumberFormat('#,##0.00').format(product.listedPrice)} / ${product.priceUnit}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${NumberFormat('0.##').format(product.stockQuantity)} ${product.priceUnit} · ${product.isInStock && product.stockQuantity > 0 ? 'IN STOCK' : 'OUT OF STOCK'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: product.isInStock && product.stockQuantity > 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Send price warning',
                onPressed: product.listedPrice == null ||
                        _sendingWarnings.contains(product.id)
                    ? null
                    : () => _sendWarning(product),
                icon: _sendingWarnings.contains(product.id)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
              ),
            ],
          ),
        ),
      );

  Future<void> _sendWarning(AdminProduct product) async {
    final message = TextEditingController(
      text:
          'Please review this price against the current applicable DTI/SRP reference and adjust it if needed.',
    );
    final notice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send product price warning'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${product.name} · ${product.listedPrice == null ? 'Price not set' : '₱${product.listedPrice!.toStringAsFixed(2)} / ${product.priceUnit}'}'),
              const SizedBox(height: 12),
              TextField(
                controller: message,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                    labelText: 'Warning notice', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () {
              if (message.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, message.text.trim());
              }
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send warning'),
          ),
        ],
      ),
    );
    message.dispose();
    if (notice == null || !mounted) return;
    setState(() => _sendingWarnings.add(product.id));
    try {
      await ref.read(supabaseAdminServiceProvider).sendProductPriceWarning(
            productId: product.id,
            message: notice,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Price warning sent to ${widget.vendor.name}.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send product warning: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingWarnings.remove(product.id));
    }
  }
}
