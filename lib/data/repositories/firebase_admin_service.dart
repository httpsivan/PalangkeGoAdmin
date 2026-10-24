import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/admin_models.dart';
import '../../models/app_models.dart';

/// Live backend for the Admin portal (Firebase mode).
///
/// Reads map Firestore collections into the portal's existing UI models;
/// every privileged mutation goes through the trusted callables in the
/// main repo's `functions/src/admin.ts` — the portal NEVER writes
/// `kycSubmissions`, `licenseRenewals` or `users.isBlocked` directly
/// (rules deny that anyway). Server truth wins: after each mutation the
/// caller reloads.
class FirebaseAdminService {
  FirebaseAdminService._();

  static final instance = FirebaseAdminService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      );

  /// Emits when data represented in the admin portal changes. The controller
  /// reloads one complete snapshot so every navigation view stays aligned.
  Stream<void> get liveDataChanges {
    late final StreamController<void> controller;
    final subscriptions = <StreamSubscription<QuerySnapshot>>[];
    const collections = [
      'users',
      'vendorStalls',
      'kycSubmissions',
      'licenseRenewals',
      'orders',
      'adminActions',
      'systemAnnouncements',
    ];
    controller = StreamController<void>(
      onListen: () {
        for (final collection in collections) {
          subscriptions.add(
            _db.collection(collection).snapshots().listen(
                  (_) => controller.add(null),
                  onError: controller.addError,
                ),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  Stream<bool> get authState => _auth.authStateChanges().map((u) => u != null);

  String? get currentEmail => _auth.currentUser?.email;

  /// Signs in and verifies the account really is an admin (users doc role).
  /// Returns null on success, else a user-readable error.
  Future<String?> signIn(String email, String password,
      {bool verifyFirestoreRole = true}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (verifyFirestoreRole) {
        final role = await _roleOf(cred.user!.uid);
        if (role != 'admin') {
          await _auth.signOut();
          return 'This account does not have admin access.';
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'The email or password is incorrect.',
        'invalid-email' => 'That email address is not valid.',
        'too-many-requests' =>
          'Too many attempts — please wait a moment and try again.',
        'network-request-failed' =>
          'Network error — check your connection and try again.',
        _ => 'Sign-in failed (${e.code}).',
      };
    }
  }

  Future<String?> verifyCurrentAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'You are not signed in.';
    try {
      if (await _roleOf(uid) == 'admin') return null;
      return 'This account does not have admin access.';
    } on FirebaseException catch (e) {
      return 'Admin access check failed (${e.code}).';
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<String?> _roleOf(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data()?['role'] as String?;
  }

  // ── Trusted callables ───────────────────────────────────────────────────────

  Future<String?> _call(String fn, Map<String, dynamic> data) async {
    try {
      await _functions.httpsCallable(fn).call(data);
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'The operation failed (${e.code}).';
    }
  }

  Future<String?> approveKyc(
    String kycId, {
    String? stallNumber,
    String? section,
  }) =>
      _call('approveKyc', {
        'kycId': kycId,
        'decision': 'approved',
        if (stallNumber != null && stallNumber.isNotEmpty)
          'stallNumber': stallNumber,
        if (section != null && section.isNotEmpty) 'section': section,
      });

  Future<String?> rejectKyc(String kycId, String reason) =>
      _call('approveKyc', {
        'kycId': kycId,
        'decision': 'rejected',
        'rejectionReason': reason,
      });

  Future<String?> approveRenewal(String renewalId) =>
      _call('approveRenewal', {'renewalId': renewalId, 'decision': 'approved'});

  Future<String?> rejectRenewal(String renewalId, String reason) =>
      _call('approveRenewal', {
        'renewalId': renewalId,
        'decision': 'rejected',
        'rejectionReason': reason,
      });

  Future<String?> setAccountBlocked(String uid, bool blocked) =>
      _call('setAccountBlocked', {'uid': uid, 'blocked': blocked});

  /// Announcements are the one admin write the rules permit directly
  /// (no money / state machine involved).
  Future<String?> publishAnnouncement({
    required String title,
    required String body,
    required String targetAudience,
    DateTime? expiresAt,
    String? imageUrl,
  }) async {
    try {
      await _db.collection('systemAnnouncements').add({
        'title': title,
        'body': body,
        'targetAudience': targetAudience,
        'createdBy': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      });
      return null;
    } on FirebaseException catch (e) {
      return 'Publishing failed (${e.code}).';
    }
  }

  Future<String?> updateAnnouncement({
    required String id,
    required String title,
    required String body,
    required String targetAudience,
    DateTime? expiresAt,
    String? imageUrl,
    bool clearImage = false,
  }) async {
    try {
      await _db.collection('systemAnnouncements').doc(id).update({
        'title': title,
        'body': body,
        'targetAudience': targetAudience,
        'updatedAt': FieldValue.serverTimestamp(),
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
        if (clearImage)
          'imageUrl': FieldValue.delete()
        else if (imageUrl != null && imageUrl.isNotEmpty)
          'imageUrl': imageUrl,
      });
      return null;
    } on FirebaseException catch (e) {
      return 'Update failed (${e.code}).';
    }
  }

  Future<String?> deleteAnnouncement(String id) async {
    try {
      await _db.collection('systemAnnouncements').doc(id).delete();
      return null;
    } on FirebaseException catch (e) {
      return 'Delete failed (${e.code}).';
    }
  }

  // ── Reads ───────────────────────────────────────────────────────────────────

  /// Loads the portal's data slices from Firestore. Only live sources are
  /// included — domains without a backend (reports, suspensions, in-app
  /// notification delivery counts) come back empty so the UI shows honest
  /// empty states instead of seeded fiction.
  Future<AdminLiveData> loadAll() async {
    final usersSnap = await _db.collection('users').get();
    final stallsSnap = await _db.collection('vendorStalls').get();
    final kycSnap = await _db.collection('kycSubmissions').get();
    final renewalsSnap = await _db.collection('licenseRenewals').get();
    // Reporting must use the complete order history; silently truncating at
    // 500 records makes the account and sales totals disagree over time.
    final ordersSnap = await _db.collection('orders').get();
    final auditSnap = await _db
        .collection('adminActions')
        .orderBy('at', descending: true)
        .limit(200)
        .get();
    final annSnap = await _db
        .collection('systemAnnouncements')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    final usersById = {for (final d in usersSnap.docs) d.id: d.data()};
    final stallById = {for (final d in stallsSnap.docs) d.id: d.data()};
    final orders = [
      for (final d in ordersSnap.docs) _mapOrder(d, usersById, stallById),
    ];

    final vendorNames = <String, String>{};
    final vendorOrderCounts = <String, int>{};
    final vendorRevenue = <String, double>{};
    for (final order in orders) {
      final stallId = order.transactionId; // transactionId carries stallId
      vendorOrderCounts[stallId] = (vendorOrderCounts[stallId] ?? 0) + 1;
      if (order.contributesToSales) {
        vendorRevenue[stallId] =
            (vendorRevenue[stallId] ?? 0) + order.netRevenue;
      }
    }
    stallById.forEach((id, stall) {
      vendorNames[id] = (stall['name'] as String?) ?? id;
    });

    final vendors = <Vendor>[];
    final customers = <Customer>[];
    usersById.forEach((uid, user) {
      final role = user['role'] as String?;
      final blocked = user['isBlocked'] == true;
      final status = blocked ? AccountStatus.blocked : AccountStatus.active;
      final name = (user['displayName'] as String?)?.isNotEmpty == true
          ? user['displayName'] as String
          : (user['email'] as String? ?? uid);
      if (role == 'vendor') {
        final stall = stallById[uid] ?? const <String, dynamic>{};
        vendors.add(Vendor(
          id: uid,
          name: name,
          email: (user['email'] as String?) ?? '',
          stallType: (stall['category'] as String?) ?? 'Unassigned',
          registeredAt: _asDate(stall['createdAt']) ?? DateTime.now(),
          status: status,
          location: (stall['location'] as String?) ?? 'Unassigned',
          orders: vendorOrderCounts[uid] ?? 0,
          transactions: vendorRevenue[uid] ?? 0,
          phone: (user['phoneNumber'] as String?) ?? '',
          residence: (user['residence'] as String?) ?? '',
        ));
      } else if (role == 'customer') {
        customers.add(Customer(
          id: uid,
          name: name,
          email: (user['email'] as String?) ?? '',
          registeredAt: _asDate(user['createdAt']) ?? DateTime.now(),
          transactions: 0,
          status: status,
        ));
      }
    });

    final applications = [
      for (final d in kycSnap.docs) _mapApplication(d, usersById, stallById)
    ];
    final renewals = [
      for (final d in renewalsSnap.docs) _mapRenewal(d, stallById)
    ];
    final auditLogs = [for (final d in auditSnap.docs) _mapAudit(d, usersById)];
    final announcements = [for (final d in annSnap.docs) _mapAnnouncement(d)];

    return AdminLiveData(
      vendors: vendors,
      customers: customers,
      applications: applications,
      renewals: renewals,
      orders: orders,
      auditLogs: auditLogs,
      announcements: announcements,
    );
  }

  // ── Mappers ─────────────────────────────────────────────────────────────────

  Order _mapOrder(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
    Map<String, Map<String, dynamic>> usersById,
    Map<String, Map<String, dynamic>> stallById,
  ) {
    final data = d.data();
    final stallId = (data['stallId'] as String?) ?? '';
    final stall = stallById[stallId] ?? const <String, dynamic>{};
    final holder = usersById[stallId] ?? const <String, dynamic>{};
    final storedVendorName = (data['vendorName'] as String?)?.trim();
    final vendorName = storedVendorName?.isNotEmpty == true
        ? storedVendorName!
        : ((holder['displayName'] as String?)?.trim().isNotEmpty == true
            ? (holder['displayName'] as String).trim()
            : (holder['email'] as String?) ??
                (stall['name'] as String?) ??
                'Unassigned stall holder');
    final storedStallName = (data['stallName'] as String?)?.trim();
    final stallName = storedStallName?.isNotEmpty == true
        ? storedStallName!
        : ((stall['name'] as String?)?.trim().isNotEmpty == true
            ? (stall['name'] as String).trim()
            : vendorName);
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((i) => Map<String, dynamic>.from(i as Map))
        .map((i) => OrderItem(
              name:
                  (i['productName'] as String?) ?? (i['name'] as String?) ?? '',
              category: (i['category'] as String?) ??
                  (i['productCategory'] as String?) ??
                  '',
              quantity: ((i['quantity'] as num?) ?? 0).toDouble(),
              unitPrice: ((i['unitPrice'] as num?) ?? (i['price'] as num?) ?? 0)
                  .toDouble(),
            ))
        .toList();
    final method = switch (data['paymentMethod'] as String?) {
      'gcash' => PaymentMethod.gcash,
      'paymaya' || 'maya' => PaymentMethod.wallet,
      'card' => PaymentMethod.card,
      _ => PaymentMethod.cashOnDelivery,
    };
    final payStatus = switch (data['paymentStatus'] as String?) {
      'paid' => PaymentStatus.paid,
      'failed' => PaymentStatus.failed,
      'refundPending' => PaymentStatus.partiallyRefunded,
      'refunded' => PaymentStatus.refunded,
      _ => PaymentStatus.pending,
    };
    final status = switch (data['status'] as String?) {
      'completed' => OrderStatus.completed,
      'confirmed' || 'preparing' || 'ready' => OrderStatus.processing,
      'cancelled' || 'rejected' => OrderStatus.cancelled,
      _ => OrderStatus.pending,
    };
    return Order(
      id: d.id,
      transactionId: stallId,
      placedAt: _asDate(data['placedAt']) ??
          _asDate(data['createdAt']) ??
          DateTime.now(),
      customerName: (data['customerName'] as String?) ?? '',
      vendorName: vendorName,
      stallName: stallName,
      items: items,
      discounts:
          ((data['discountAmount'] as num?) ?? (data['discount'] as num?) ?? 0)
              .toDouble(),
      deliveryFee: ((data['deliveryFee'] as num?) ?? 0).toDouble(),
      platformFee: ((data['serviceFee'] as num?) ?? 0).toDouble() +
          ((data['priorityFee'] as num?) ?? 0).toDouble(),
      refundAmount:
          ((data['refundAmount'] as num?) ?? (data['refund'] as num?) ?? 0)
              .toDouble(),
      paymentMethod: method,
      paymentStatus: payStatus,
      status: status,
    );
  }

  VendorApplication _mapApplication(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
    Map<String, Map<String, dynamic>> usersById,
    Map<String, Map<String, dynamic>> stallById,
  ) {
    final data = d.data();
    final holderId = (data['stallHolderId'] as String?) ?? d.id;
    final stall = stallById[holderId] ?? const <String, dynamic>{};
    final status = switch (data['status'] as String?) {
      'approved' => ApplicationStatus.verified,
      'rejected' => ApplicationStatus.rejected,
      _ => ApplicationStatus.reviewing,
    };
    final docUrls = [
      ('Mayor’s Permit', data['mayorPermitUrl']),
      ('Sanitary Permit', data['sanitaryPermitUrl']),
      ('Fire Certification', data['fireCertificationUrl']),
      ('Market Clearance', data['marketClearanceUrl']),
      ('Valid ID', data['validIdPhotoUrl']),
    ];
    final documents = [
      for (final entry in docUrls)
        if (entry.$2 is String && (entry.$2 as String).isNotEmpty)
          KycDocument(
            name: entry.$1,
            filename: (entry.$2 as String).split('/').last,
            mimeType: 'image/*',
            uploadedAt: _asDate(data['submittedAt']) ?? DateTime.now(),
            assetPath: entry.$2 as String,
          ),
    ];
    return VendorApplication(
      id: d.id,
      applicant: (usersById[holderId]?['displayName'] as String?) ??
          (usersById[holderId]?['email'] as String?) ??
          holderId,
      stallName: (stall['name'] as String?) ?? 'Pending allocation',
      category: (stall['category'] as String?) ?? 'Uncategorized',
      submittedAt: _asDate(data['submittedAt']) ?? DateTime.now(),
      status: status,
      location: (stall['location'] as String?) ?? 'Unassigned',
      documents: documents,
      rejectionReason: data['rejectionReason'] as String?,
      reviewedAt: _asDate(data['reviewedAt']),
      reviewedBy: data['reviewedBy'] as String?,
    );
  }

  RenewalRequest _mapRenewal(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
    Map<String, Map<String, dynamic>> stallById,
  ) {
    final data = d.data();
    final stallId = (data['stallId'] as String?) ?? d.id;
    final stall = stallById[stallId] ?? const <String, dynamic>{};
    final status = switch (data['status'] as String?) {
      'approved' => RenewalStatus.approved,
      'rejected' => RenewalStatus.expired,
      _ => RenewalStatus.reviewing,
    };
    return RenewalRequest(
      id: d.id,
      applicant: (data['vendorName'] as String?) ??
          (stall['name'] as String?) ??
          stallId,
      stallName: (stall['name'] as String?) ?? 'Unknown stall',
      category: (stall['category'] as String?) ?? 'Uncategorized',
      expiryDate: _asDate(data['periodEnd']) ??
          DateTime.now().add(
            const Duration(days: 365),
          ),
      status: status,
      location: (stall['location'] as String?) ?? 'Unassigned',
      submittedAt: _asDate(data['submittedAt']) ?? _asDate(data['createdAt']),
    );
  }

  AuditLog _mapAudit(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
    Map<String, Map<String, dynamic>> usersById,
  ) {
    final data = d.data();
    final action = switch (data['action'] as String?) {
      'kyc.approved' => AuditAction.approveKyc,
      'kyc.rejected' => AuditAction.rejectKyc,
      'account.blocked' => AuditAction.blockAccount,
      'account.unblocked' => AuditAction.unblockAccount,
      _ => AuditAction.editAccountStatus,
    };
    final byUid = (data['byUid'] as String?) ?? '';
    return AuditLog(
      id: d.id,
      administratorId: byUid,
      administratorName:
          (usersById[byUid]?['displayName'] as String?) ?? 'Administrator',
      action: action,
      targetEntityType: 'System',
      targetEntityId: (data['target'] as String?) ?? '',
      targetUserName: (data['target'] as String?) ?? '',
      previousValue: '',
      newValue: '',
      reason: '',
      metadata: const {},
      timestamp: _asDate(data['at']) ?? DateTime.now(),
    );
  }

  Announcement _mapAnnouncement(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return Announcement(
      id: d.id,
      title: (data['title'] as String?) ?? '',
      summary: (data['body'] as String?) ?? '',
      audience: switch ((data['targetAudience'] as String?)?.toLowerCase()) {
        'customers' || 'customer' => 'Customers',
        'stallholders' ||
        'stall holders' ||
        'vendors' ||
        'vendor' =>
          'Stall Holders',
        _ => 'All Users',
      },
      createdAt: _asDate(data['createdAt']) ?? DateTime.now(),
      isDraft: false,
      expiresAt: _asDate(data['expiresAt']),
      imageUrl: (data['imageUrl'] ?? data['image_url']) as String?,
      createdBy: (data['createdBy'] as String?) ?? 'ADM-001',
    );
  }

  static DateTime? _asDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Live slices loaded from Firestore (everything else stays empty on
/// purpose — no seeded fiction in Firebase mode).
class AdminLiveData {
  const AdminLiveData({
    required this.vendors,
    required this.customers,
    required this.applications,
    required this.renewals,
    required this.orders,
    required this.auditLogs,
    required this.announcements,
  });

  final List<Vendor> vendors;
  final List<Customer> customers;
  final List<VendorApplication> applications;
  final List<RenewalRequest> renewals;
  final List<Order> orders;
  final List<AuditLog> auditLogs;
  final List<Announcement> announcements;
}
