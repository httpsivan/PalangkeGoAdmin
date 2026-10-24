import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/admin_notification.dart';
import '../../models/admin_models.dart';
import '../../models/app_models.dart';

final supabaseAdminServiceProvider = Provider<SupabaseAdminService>((ref) {
  SupabaseClient? client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    client = null;
  }
  return SupabaseAdminService(client: client);
});

class SupabaseAccounts {
  const SupabaseAccounts({required this.vendors, required this.customers});

  final List<Vendor> vendors;
  final List<Customer> customers;
}

Report mapSupabaseComplaintRow(Map<String, dynamic> row) {
  final status = (row['status'] ?? 'open').toString().toLowerCase();
  final reason = (row['reason'] ?? 'Vendor complaint').toString();
  final details = (row['details'] ?? '').toString();
  final stallName = (row['stall_name'] ?? 'Vendor').toString();
  final reporterName = (row['reporter_name'] ?? 'Customer').toString();
  final reviewedAt = DateTime.tryParse(row['reviewed_at']?.toString() ?? '');

  return Report(
    evidenceUrls: (row['evidence_urls'] as List? ?? const [])
        .whereType<String>()
        .where((url) => Uri.tryParse(url)?.scheme == 'https')
        .toList(),
    id: (row['complaint_id'] ?? '').toString(),
    type: 'Vendor',
    accountIssue: stallName,
    submittedBy: reporterName,
    reason: reason,
    date: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    status: switch (status) {
      'reviewing' => ReportStatus.underReview,
      'resolved' || 'dismissed' => ReportStatus.resolved,
      _ => ReportStatus.pending,
    },
    priority: Priority.medium,
    description: details.isEmpty ? reason : details,
    reporterEmail: '',
    phone: '',
    vendorName: stallName,
    owner: stallName,
    stallNumber: '',
    previousViolations: 0,
    notes: (row['admin_notes'] ?? '').toString(),
    decision: status == 'dismissed'
        ? 'Dismissed'
        : status == 'resolved'
            ? 'Resolved'
            : null,
    actionTaken: status == 'dismissed'
        ? 'Dismissed'
        : status == 'resolved'
            ? 'Marked as Resolved'
            : null,
    resolvedAt: reviewedAt,
    resolvedBy: row['reviewed_by']?.toString(),
  );
}

/// Central Supabase administration client for querying and synchronizing
/// announcements, KYC applications, and sales orders directly with the shared
/// Supabase database used by PalengkeGoAPP.
class SupabaseAdminService {
  const SupabaseAdminService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get client {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isConfigured => client != null;

  Future<String?> verifyAdmin() async {
    try {
      await _invoke('verify-admin');
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<Map<String, dynamic>> fetchAdminProfile() => _invoke('verify-admin');

  Future<String?> updateAdminName(String fullName) async {
    try {
      await _invoke('update-admin-profile', {'fullName': fullName.trim()});
      return null;
    } catch (error) {
      debugPrint('[admin] Updating admin name failed: $error');
      return error.toString();
    }
  }

  Future<Map<String, dynamic>> _invoke(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final sb = client;
    final user = FirebaseAuth.instance.currentUser;
    if (sb == null) throw StateError('Supabase client is not configured');
    if (user == null) throw StateError('Admin is not signed in');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Could not obtain the admin sign-in token');
    }
    final response = await sb.functions.invoke(
      'admin-portal',
      body: {'action': action, ...data},
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Admin backend request failed (${response.status})');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<SupabaseAccounts> fetchAccounts() async {
    if (client == null) {
      return const SupabaseAccounts(vendors: [], customers: []);
    }
    try {
      final response = await _invoke('accounts');
      final users = (response['users'] as List<dynamic>? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final customerRows = (response['customers'] as List<dynamic>? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final stalls = (response['stalls'] as List<dynamic>? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final orders = (response['orders'] as List<dynamic>? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      final stallByUser = <String, Map<String, dynamic>>{};
      for (final stall in stalls) {
        stallByUser[(stall['user_id'] ?? '').toString()] = stall;
      }
      final customerIdByUser = <String, String>{
        for (final customer in customerRows)
          (customer['user_id'] ?? '').toString():
              (customer['customer_id'] ?? '').toString(),
      };

      final vendorOrderCounts = <String, int>{};
      final vendorRevenue = <String, double>{};
      final customerOrderCounts = <String, int>{};
      for (final order in orders) {
        final stallId = (order['stall_holder_id'] ?? '').toString();
        final customerId = (order['customer_id'] ?? '').toString();
        vendorOrderCounts[stallId] = (vendorOrderCounts[stallId] ?? 0) + 1;
        customerOrderCounts[customerId] =
            (customerOrderCounts[customerId] ?? 0) + 1;
        if ({'delivered', 'completed'}.contains(order['order_status'])) {
          vendorRevenue[stallId] = (vendorRevenue[stallId] ?? 0) +
              ((order['total_amount'] as num?) ?? 0).toDouble();
        }
      }

      final vendors = <Vendor>[];
      final customers = <Customer>[];
      for (final user in users) {
        final id = (user['user_id'] ?? '').toString();
        final role = (user['role'] ?? '').toString().toLowerCase();
        final status = user['is_blocked'] == true
            ? AccountStatus.blocked
            : AccountStatus.active;
        final createdAt =
            DateTime.tryParse(user['created_at']?.toString() ?? '') ??
                DateTime.now();
        if (role == 'vendor' || role == 'stallholder') {
          final stall = stallByUser[id] ?? const <String, dynamic>{};
          final stallId = (stall['stall_holder_id'] ?? '').toString();
          final stallNumber = (stall['stall_number'] ?? '').toString();
          final floor = (stall['floor_number'] ?? '').toString();
          vendors.add(Vendor(
            id: id,
            name: (user['full_name'] ?? user['email'] ?? id).toString(),
            email: (user['email'] ?? '').toString(),
            stallType: (stall['category'] ?? 'Unassigned').toString(),
            registeredAt: createdAt,
            status: status,
            location: [
              if (stallNumber.isNotEmpty) 'Stall $stallNumber',
              if (floor.isNotEmpty) 'Floor $floor',
            ].join(', '),
            orders: vendorOrderCounts[stallId] ?? 0,
            transactions: vendorRevenue[stallId] ?? 0,
            phone: (user['phone_number'] ?? '').toString(),
            residence: '',
          ));
        } else if (role == 'customer') {
          final customerId = customerIdByUser[id] ?? '';
          customers.add(Customer(
            id: id,
            name: (user['full_name'] ?? user['email'] ?? id).toString(),
            email: (user['email'] ?? '').toString(),
            registeredAt: createdAt,
            transactions: customerOrderCounts[customerId] ?? 0,
            status: status,
          ));
        }
      }
      return SupabaseAccounts(vendors: vendors, customers: customers);
    } catch (e) {
      debugPrint('[admin] Supabase fetchAccounts failed: $e');
      rethrow;
    }
  }

  // ── Announcements ─────────────────────────────────────────────────────────

  /// Fetches all announcements from `system_announcements`.
  Future<List<Announcement>> fetchAnnouncements() async {
    final sb = client;
    if (sb == null) return [];

    try {
      final response = await _invoke('announcements');
      final list = response['announcements'] as List<dynamic>? ?? [];
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = (map['id'] ?? map['announcement_id'] ?? '').toString();
        final rawAudience =
            (map['target_audience'] ?? map['targetAudience']) as String?;
        final audience = targetAudienceToDisplay(rawAudience);
        final createdAt = DateTime.tryParse(
              map['created_at']?.toString() ??
                  map['createdAt']?.toString() ??
                  '',
            ) ??
            DateTime.now();
        final expiresAt = map['expires_at'] != null
            ? DateTime.tryParse(map['expires_at'].toString())
            : (map['expiresAt'] != null
                ? DateTime.tryParse(map['expiresAt'].toString())
                : null);

        return Announcement(
          id: id,
          title: (map['title'] as String?) ?? '',
          summary: (map['body'] as String?) ?? '',
          audience: audience,
          createdAt: createdAt,
          expiresAt: expiresAt,
          isDraft: false,
          state: 'Sent',
          imageUrl: (map['image_url'] ?? map['imageUrl']) as String?,
          popupImageUrls:
              (map['popup_image_urls'] as List<dynamic>? ?? const [])
                  .whereType<String>()
                  .toList(growable: false),
          showAsPopup: map['show_as_popup'] == true,
          facebookUrl: map['facebook_url'] as String?,
          createdBy: (map['created_by'] as String?) ?? 'ADM-001',
        );
      }).toList();
    } catch (e) {
      debugPrint('[admin] Supabase fetchAnnouncements failed: $e');
      rethrow;
    }
  }

  /// Inserts a newly published announcement into `system_announcements`.
  Future<String?> publishAnnouncement({
    required String title,
    required String body,
    required String audience,
    DateTime? expiresAt,
    String? imageUrl,
    Uint8List? imageBytes,
    bool showAsPopup = false,
    String? facebookUrl,
    List<String> popupImageUrls = const [],
    List<Uint8List> popupImageBytes = const [],
  }) async {
    final sb = client;
    if (sb == null) return 'Supabase client is not configured';

    try {
      String? resolvedImageUrl = imageUrl;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final uploaded = await _uploadImageBytes(imageBytes);
        if (uploaded != null) resolvedImageUrl = uploaded;
      }
      final resolvedPopupImageUrls = [...popupImageUrls];
      for (final bytes in popupImageBytes) {
        final uploaded = await _uploadImageBytes(bytes);
        if (uploaded == null) {
          throw StateError('Could not upload a popup image');
        }
        resolvedPopupImageUrls.add(uploaded);
      }

      await _invoke('publish-announcement', {
        'title': title,
        'body': body,
        'showAsPopup': showAsPopup,
        'facebookUrl': facebookUrl,
        'popupImageUrls': resolvedPopupImageUrls,
        'audience': audienceToTargetAudience(audience),
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
        if (resolvedImageUrl != null && resolvedImageUrl.isNotEmpty)
          'imageUrl': resolvedImageUrl,
      });
      return null;
    } catch (e) {
      debugPrint('[admin] Supabase publishAnnouncement error: $e');
      return e.toString();
    }
  }

  /// Updates an announcement in `system_announcements`.
  Future<String?> updateAnnouncement({
    required String id,
    required String title,
    required String body,
    required String audience,
    DateTime? expiresAt,
    String? imageUrl,
    Uint8List? imageBytes,
    bool clearImage = false,
    bool showAsPopup = false,
    String? facebookUrl,
    List<String> popupImageUrls = const [],
    List<Uint8List> popupImageBytes = const [],
  }) async {
    final sb = client;
    if (sb == null) return 'Supabase client is not configured';

    try {
      String? resolvedImageUrl = imageUrl;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final uploaded = await _uploadImageBytes(imageBytes);
        if (uploaded != null) resolvedImageUrl = uploaded;
      }
      final resolvedPopupImageUrls = [...popupImageUrls];
      for (final bytes in popupImageBytes) {
        final uploaded = await _uploadImageBytes(bytes);
        if (uploaded == null) {
          throw StateError('Could not upload a popup image');
        }
        resolvedPopupImageUrls.add(uploaded);
      }

      await _invoke('update-announcement', {
        'id': id,
        'title': title,
        'body': body,
        'showAsPopup': showAsPopup,
        'facebookUrl': facebookUrl,
        'popupImageUrls': resolvedPopupImageUrls,
        'audience': audienceToTargetAudience(audience),
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
        if (resolvedImageUrl != null && resolvedImageUrl.isNotEmpty)
          'imageUrl': resolvedImageUrl,
        'clearImage': clearImage,
      });
      return null;
    } catch (e) {
      debugPrint('[admin] Supabase updateAnnouncement error: $e');
      return e.toString();
    }
  }

  /// Deletes an announcement in `system_announcements`.
  Future<String?> deleteAnnouncement(String id) async {
    final sb = client;
    if (sb == null) return 'Supabase client is not configured';

    try {
      await _invoke('delete-announcement', {'id': id});
      return null;
    } catch (e) {
      debugPrint('[admin] Supabase deleteAnnouncement error: $e');
      return e.toString();
    }
  }

  // ── KYC Applications ──────────────────────────────────────────────────────

  /// Loads vendor KYC submissions from `kyc_submissions` table.
  Future<List<VendorApplication>> fetchApplications() async {
    final sb = client;
    if (sb == null) return [];

    try {
      final response = await _invoke('applications');
      final kycRows = response['applications'];
      final stallsRows = response['stalls'];
      final usersRows = response['users'];

      final stallById = <String, Map<String, dynamic>>{};
      for (final item in (stallsRows as List<dynamic>? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        final id = (m['stall_holder_id'] ?? m['id'] ?? '').toString();
        if (id.isNotEmpty) stallById[id] = m;
      }

      final userById = <String, Map<String, dynamic>>{};
      for (final item in (usersRows as List<dynamic>? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        final id = (m['user_id'] ?? m['id'] ?? '').toString();
        if (id.isNotEmpty) userById[id] = m;
      }

      final results = <VendorApplication>[];
      for (final item in (kycRows as List<dynamic>? ?? [])) {
        final kyc = Map<String, dynamic>.from(item as Map);
        final id = (kyc['kyc_id'] ?? kyc['id'] ?? '').toString();
        final stallId = (kyc['stall_holder_id'] ?? '').toString();
        final stall = stallById[stallId] ?? const <String, dynamic>{};
        final user = userById[(stall['user_id'] ?? stallId).toString()] ??
            const <String, dynamic>{};

        final submittedAt = DateTime.tryParse(
              kyc['submitted_at']?.toString() ?? '',
            ) ??
            DateTime.now();

        final rawStatus = (kyc['status'] as String? ?? 'pending').toLowerCase();
        final status = switch (rawStatus) {
          'approved' => ApplicationStatus.verified,
          'rejected' => ApplicationStatus.rejected,
          'invaliddocs' || 'invalid_docs' => ApplicationStatus.invalidDocs,
          _ => ApplicationStatus.reviewing,
        };

        final applicantName = (user['full_name'] ??
                user['displayName'] ??
                kyc['owner_name']) as String? ??
            'Vendor ($stallId)';
        final stallName = (stall['stall_name'] ??
                stall['name'] ??
                kyc['stall_name']) as String? ??
            'Stall $stallId';
        final category =
            (stall['category'] ?? kyc['category']) as String? ?? 'General';
        final location = stall['stall_number'] != null
            ? 'Stall #${stall['stall_number']}, Floor ${stall['floor_number'] ?? '1'}'
            : 'Main Wet Market';

        final documents = <KycDocument>[];
        void addDoc(String name, String? url) {
          if (url != null && url.isNotEmpty) {
            documents.add(
              KycDocument(
                name: name,
                filename: url.split('/').last.split('?').first,
                mimeType: 'image/*',
                uploadedAt: submittedAt,
                fileUrl: url,
                idFrontUrl: url,
              ),
            );
          }
        }

        addDoc("Mayor's Permit", kyc['mayor_permit_url'] as String?);
        addDoc("Sanitary Permit", kyc['sanitary_permit_url'] as String?);
        addDoc("Fire Safety Certificate",
            kyc['fire_certification_url'] as String?);
        addDoc("Market Clearance", kyc['market_clearance_url'] as String?);
        addDoc("Valid Government ID", kyc['valid_id_photo_url'] as String?);
        addDoc("Selfie Verification", kyc['selfie_url'] as String?);

        results.add(
          VendorApplication(
            id: id,
            applicant: applicantName,
            stallName: stallName,
            category: category,
            submittedAt: submittedAt,
            status: status,
            location: location,
            documents: documents,
            rejectionReason: kyc['rejection_reason'] as String?,
            reviewedAt: kyc['reviewed_at'] != null
                ? DateTime.tryParse(kyc['reviewed_at'].toString())
                : null,
            reviewedBy: kyc['reviewed_by'] as String?,
          ),
        );
      }

      return results;
    } catch (e) {
      debugPrint('[admin] Supabase fetchApplications failed: $e');
      rethrow;
    }
  }

  /// Loads complaints created by customers in the PalengkeGo app.
  Future<List<Report>> fetchComplaints() async {
    if (client == null) return [];

    try {
      final response = await _invoke('complaints');
      final rows = response['complaints'] as List<dynamic>? ?? const [];
      return rows
          .map((value) => mapSupabaseComplaintRow(
                Map<String, dynamic>.from(value as Map),
              ))
          .toList();
    } catch (e) {
      debugPrint('[admin] Supabase fetchComplaints failed: $e');
      rethrow;
    }
  }

  RealtimeChannel? subscribeToComplaintChanges(VoidCallback onChange) {
    final sb = client;
    if (sb == null) return null;
    return sb
        .channel('admin-complaints')
        .onBroadcast(
          event: 'complaint_changed',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<String?> reviewComplaint({
    required String complaintId,
    required String status,
    required String adminNotes,
  }) async {
    try {
      await _invoke('review-complaint', {
        'complaintId': complaintId,
        'status': status,
        'adminNotes': adminNotes.trim(),
      });
      return null;
    } catch (e) {
      debugPrint('[admin] Supabase reviewComplaint failed: $e');
      return e.toString();
    }
  }

  Future<List<AdminNotification>> fetchNotifications() async {
    if (client == null) return [];

    try {
      final response = await _invoke('notifications');
      final rows = response['notifications'] as List<dynamic>? ?? const [];
      return rows.map((value) {
        final row = Map<String, dynamic>.from(value as Map);
        final type = (row['type'] ?? '').toString();
        final referenceId = row['reference_id']?.toString();
        final targetType = switch (type) {
          'complaint' => NotificationTargetType.report,
          'kyc_update' => NotificationTargetType.application,
          _ => null,
        };
        return AdminNotification(
          id: (row['notification_id'] ?? '').toString(),
          title: (row['title'] ?? 'Notification').toString(),
          message: (row['body'] ?? '').toString(),
          type: switch (type) {
            'complaint' => NotificationType.report,
            'kyc_update' => NotificationType.vendorApplication,
            'new_order' || 'order_update' => NotificationType.accountUpdate,
            _ => NotificationType.system,
          },
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          isRead: row['is_read'] == true,
          target: targetType != null && referenceId != null
              ? NotificationTarget(type: targetType, id: referenceId)
              : null,
          actionLabel: type == 'complaint'
              ? 'Review Complaint'
              : type == 'kyc_update'
                  ? 'Review Application'
                  : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('[admin] Supabase fetchNotifications failed: $e');
      rethrow;
    }
  }

  /// Updates application status in `kyc_submissions` and `stall_holders`.
  Future<String?> updateApplicationStatus(
    String id,
    ApplicationStatus status, {
    String? rejectionReason,
    String? stallHolderId,
  }) async {
    final sb = client;
    if (sb == null) return 'Supabase client is not configured';

    try {
      final dbStatus = switch (status) {
        ApplicationStatus.verified => 'approved',
        ApplicationStatus.rejected ||
        ApplicationStatus.invalidDocs =>
          'rejected',
        ApplicationStatus.reviewing => 'pending',
      };
      await _invoke('review-kyc', {
        'kycId': id,
        'status': dbStatus,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      });
      return null;
    } catch (e) {
      debugPrint('[admin] Supabase updateApplicationStatus failed: $e');
      return e.toString();
    }
  }

  // ── Orders & Sales Reports ────────────────────────────────────────────────

  /// Fetches orders from Supabase `orders` and `order_items` tables.
  Future<List<Order>> fetchOrders() async {
    final sb = client;
    if (sb == null) return [];

    try {
      final response = await _invoke('orders');
      final orderRows = response['orders'];
      final itemsRows = response['items'];
      final stallsRows = response['stalls'];

      final itemsByOrderId = <String, List<OrderItem>>{};
      for (final item in (itemsRows as List<dynamic>? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        final orderId = (m['order_id'] ?? '').toString();
        if (orderId.isEmpty) continue;

        itemsByOrderId.putIfAbsent(orderId, () => []).add(
              OrderItem(
                name: (m['product_name'] ?? 'Product').toString(),
                category: (m['category_tag'] ?? m['category'] ?? 'Produce')
                    .toString(),
                quantity: ((m['quantity'] as num?) ?? 1).toDouble(),
                unitPrice:
                    ((m['unit_price'] ?? m['price_at_order'] as num?) ?? 0.0)
                        .toDouble(),
              ),
            );
      }

      final stallById = <String, Map<String, dynamic>>{};
      for (final item in (stallsRows as List<dynamic>? ?? [])) {
        final m = Map<String, dynamic>.from(item as Map);
        final id = (m['stall_holder_id'] ?? m['id'] ?? '').toString();
        if (id.isNotEmpty) stallById[id] = m;
      }

      final results = <Order>[];
      for (final item in (orderRows as List<dynamic>? ?? [])) {
        final row = Map<String, dynamic>.from(item as Map);
        final orderId = (row['order_id'] ?? row['id'] ?? '').toString();
        final stallId = (row['stall_holder_id'] ?? '').toString();
        final stall = stallById[stallId] ?? const <String, dynamic>{};

        final stallName = (stall['stall_name'] ??
                stall['name'] ??
                row['vendor_name']) as String? ??
            'Market Stall';
        final vendorName = (stall['owner_name'] ?? stallName) as String;

        final items = itemsByOrderId[orderId] ??
            [
              OrderItem(
                name: 'Market Produce',
                category: 'General',
                quantity: 1,
                unitPrice:
                    ((row['total_amount'] ?? row['total'] as num?) ?? 0.0)
                        .toDouble(),
              ),
            ];

        final pm = (row['payment_method'] as String? ?? 'cod').toLowerCase();
        final paymentMethod = switch (pm) {
          'gcash' => PaymentMethod.gcash,
          'card' => PaymentMethod.card,
          'wallet' => PaymentMethod.wallet,
          _ => PaymentMethod.cashOnDelivery,
        };

        final ps =
            (row['payment_status'] as String? ?? 'pending').toLowerCase();
        final paymentStatus = switch (ps) {
          'paid' => PaymentStatus.paid,
          'refunded' => PaymentStatus.refunded,
          'partially_refunded' => PaymentStatus.partiallyRefunded,
          'failed' => PaymentStatus.failed,
          _ => PaymentStatus.pending,
        };

        final os =
            (row['order_status'] ?? row['status'] as String? ?? 'pending')
                .toLowerCase();
        final orderStatus = switch (os) {
          'completed' || 'delivered' => OrderStatus.completed,
          'cancelled' => OrderStatus.cancelled,
          'refunded' => OrderStatus.refunded,
          'preparing' ||
          'ready' ||
          'processing' ||
          'out_for_delivery' ||
          'outfordelivery' =>
            OrderStatus.processing,
          _ => OrderStatus.pending,
        };

        results.add(
          Order(
            id: orderId,
            transactionId: stallId.isNotEmpty ? stallId : orderId,
            placedAt: DateTime.tryParse(
                  row['created_at']?.toString() ??
                      row['placed_at']?.toString() ??
                      '',
                ) ??
                DateTime.now(),
            customerName:
                (row['customer_name'] as String?) ?? 'Market Customer',
            vendorName: vendorName,
            stallName: stallName,
            items: items,
            discounts: ((row['discounts'] as num?) ?? 0.0).toDouble(),
            deliveryFee: ((row['delivery_fee'] as num?) ?? 0.0).toDouble(),
            platformFee: ((row['service_fee'] as num?) ?? 0.0).toDouble(),
            refundAmount: ((row['refunded_amount'] as num?) ?? 0.0).toDouble(),
            paymentMethod: paymentMethod,
            paymentStatus: paymentStatus,
            status: orderStatus,
          ),
        );
      }

      return results;
    } catch (e) {
      debugPrint('[admin] Supabase fetchOrders failed: $e');
      rethrow;
    }
  }

  // ── Account Blocking Sync ─────────────────────────────────────────────────

  /// Syncs an account block/unblock state with Supabase `users` table.
  Future<String?> setAccountBlocked(String userId, bool blocked) async {
    final sb = client;
    if (sb == null) return 'Supabase client is not configured';
    try {
      await _invoke('set-account-blocked', {
        'userId': userId,
        'blocked': blocked,
      });
      return null;
    } catch (e) {
      debugPrint('[admin] Supabase setAccountBlocked failed: $e');
      return e.toString();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _uploadImageBytes(Uint8List bytes) async {
    final sb = client;
    if (sb == null) return null;
    try {
      var extension = 'jpg';
      var contentType = 'image/jpeg';
      if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47) {
        extension = 'png';
        contentType = 'image/png';
      } else if (bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        extension = 'webp';
        contentType = 'image/webp';
      } else if (bytes.length >= 3 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46) {
        extension = 'gif';
        contentType = 'image/gif';
      }
      final fileName =
          'announcement_${DateTime.now().microsecondsSinceEpoch}.$extension';
      await sb.storage.from('stalls').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return sb.storage.from('stalls').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('[admin] Storage upload fallback: $e');
      return null;
    }
  }

  static String audienceToTargetAudience(String audience) {
    switch (audience.trim().toLowerCase()) {
      case 'stall holders':
      case 'stallholders':
      case 'vendors':
      case 'vendor':
        return 'stallholders';
      case 'customers':
      case 'customer':
        return 'customers';
      default:
        return 'all';
    }
  }

  static String targetAudienceToDisplay(String? targetAudience) {
    switch (targetAudience?.trim().toLowerCase()) {
      case 'stallholders':
      case 'vendors':
        return 'Stall Holders';
      case 'customers':
        return 'Customers';
      default:
        return 'All Users';
    }
  }
}
