import 'package:intl/intl.dart';

import 'app_models.dart';

enum OrderStatus { pending, processing, completed, cancelled, refunded }

enum PaymentStatus { pending, paid, failed, refunded, partiallyRefunded }

enum PaymentMethod { cashOnDelivery, gcash, card, wallet }

enum AuditAction {
  login,
  logout,
  approveKyc,
  rejectKyc,
  blockAccount,
  unblockAccount,
  suspendAccount,
  liftSuspension,
  resolveReport,
  editAccountStatus,
  sendAnnouncement,
  exportPdf,
  exportExcel,
  changeSettings,
}

class OrderItem {
  const OrderItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final String category;
  final double quantity;
  final double unitPrice;

  double get subtotal => quantity * unitPrice;
}

class Order {
  const Order({
    required this.id,
    required this.transactionId,
    required this.placedAt,
    required this.customerName,
    required this.vendorName,
    required this.stallName,
    required this.items,
    required this.discounts,
    required this.deliveryFee,
    required this.platformFee,
    required this.refundAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
  });

  final String id;
  final String transactionId;
  final DateTime placedAt;
  final String customerName;
  final String vendorName;
  final String stallName;
  final List<OrderItem> items;
  final double discounts;
  final double deliveryFee;
  final double platformFee;
  final double refundAmount;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final OrderStatus status;

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get total => subtotal - discounts + deliveryFee + platformFee;
  double get netRevenue => total - refundAmount;
  bool get contributesToSales =>
      status == OrderStatus.completed || status == OrderStatus.refunded;
  double get quantity => items.fold(0, (sum, item) => sum + item.quantity);
  String get categories =>
      items.map((item) => item.category).toSet().join(', ');
  String get itemNames => items.map((item) => item.name).join(', ');

  List<Object?> toRow() => [
        id,
        transactionId,
        DateFormat('yyyy-MM-dd HH:mm').format(placedAt),
        customerName,
        vendorName,
        stallName,
        itemNames,
        categories,
        quantity,
        subtotal,
        discounts,
        deliveryFee,
        platformFee,
        refundAmount,
        total,
        enumLabel(paymentMethod),
        enumLabel(paymentStatus),
        enumLabel(status),
      ];
}

class SalesSummary {
  const SalesSummary({
    required this.totalOrders,
    required this.completedOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.refundedOrders,
    required this.grossSales,
    required this.discounts,
    required this.refunds,
    required this.platformFees,
    required this.netRevenue,
  });

  final int totalOrders;
  final int completedOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final int refundedOrders;
  final double grossSales;
  final double discounts;
  final double refunds;
  final double platformFees;
  final double netRevenue;

  factory SalesSummary.fromOrders(Iterable<Order> orders) {
    final list = orders.toList();
    final salesOrders = list.where((item) => item.contributesToSales).toList();
    final gross = salesOrders.fold<double>(0, (sum, item) => sum + item.total);
    final disc =
        salesOrders.fold<double>(0, (sum, item) => sum + item.discounts);
    final ref =
        salesOrders.fold<double>(0, (sum, item) => sum + item.refundAmount);
    final fees =
        salesOrders.fold<double>(0, (sum, item) => sum + item.platformFee);
    return SalesSummary(
      totalOrders: list.length,
      completedOrders:
          list.where((item) => item.status == OrderStatus.completed).length,
      pendingOrders: list
          .where((item) =>
              item.status == OrderStatus.pending ||
              item.status == OrderStatus.processing)
          .length,
      cancelledOrders:
          list.where((item) => item.status == OrderStatus.cancelled).length,
      refundedOrders:
          list.where((item) => item.status == OrderStatus.refunded).length,
      grossSales: gross,
      discounts: disc,
      refunds: ref,
      platformFees: fees,
      netRevenue:
          salesOrders.fold<double>(0, (sum, item) => sum + item.netRevenue),
    );
  }
}

class Suspension {
  const Suspension({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.administratorId,
    required this.createdAt,
    required this.note,
    required this.notifyUser,
    this.relatedReportId,
    this.administratorName = 'Administrator',
    this.liftedAt,
  });

  final String id;
  final String accountId;
  final String accountName;
  final String accountType;
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final String administratorId;
  final DateTime createdAt;
  final String note;
  final bool notifyUser;
  final String? relatedReportId;
  final String administratorName;
  final DateTime? liftedAt;

  bool get isActive {
    final now = DateTime.now();
    return liftedAt == null && now.isAfter(startDate) && now.isBefore(endDate);
  }

  bool get isExpired => liftedAt == null && !DateTime.now().isBefore(endDate);

  Suspension lift(DateTime at) => Suspension(
        id: id,
        accountId: accountId,
        accountName: accountName,
        accountType: accountType,
        reason: reason,
        startDate: startDate,
        endDate: endDate,
        administratorId: administratorId,
        createdAt: createdAt,
        note: note,
        notifyUser: notifyUser,
        relatedReportId: relatedReportId,
        administratorName: administratorName,
        liftedAt: at,
      );
}

class AuditLog {
  const AuditLog({
    required this.id,
    required this.administratorId,
    required this.administratorName,
    required this.action,
    required this.targetEntityType,
    required this.targetEntityId,
    required this.targetUserName,
    required this.previousValue,
    required this.newValue,
    required this.reason,
    required this.metadata,
    required this.timestamp,
  });

  final String id;
  final String administratorId;
  final String administratorName;
  final AuditAction action;
  final String targetEntityType;
  final String targetEntityId;
  final String targetUserName;
  final String previousValue;
  final String newValue;
  final String reason;
  final Map<String, String> metadata;
  final DateTime timestamp;

  List<Object?> toRow() => [
        id,
        administratorName,
        enumLabel(action),
        targetEntityType,
        targetEntityId,
        targetUserName,
        previousValue,
        newValue,
        reason,
        timestamp.toIso8601String(),
      ];
}
