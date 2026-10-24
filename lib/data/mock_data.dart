import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../models/app_models.dart';

class StallHolderProfile {
  const StallHolderProfile({
    required this.idNumber,
    required this.name,
    required this.stallName,
    required this.category,
    required this.stallType,
    required this.location,
    required this.email,
    required this.phone,
    required this.residence,
  });

  final int idNumber;
  final String name;
  final String stallName;
  final String category;
  final String stallType;
  final String location;
  final String email;
  final String phone;
  final String residence;
}

const stallHolderProfiles = [
  StallHolderProfile(
    idNumber: 92834,
    name: 'Aicel Castillo',
    stallName: 'Riverside Seafood',
    category: 'FRESH FISH',
    stallType: 'Fresh Fish',
    location: 'Block 14 - Stall 2',
    email: 'aicel.castillo@gmail.com',
    phone: '+63 921 555 1000',
    residence: 'Brgy. Peñafrancia, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92835,
    name: 'Diosa Del Rosario',
    stallName: 'Bicol Dry Goods',
    category: 'DRIED FISH',
    stallType: 'Dried Fish',
    location: 'Block 15 - Stall 3',
    email: 'diosa.del.rosario@gmail.com',
    phone: '+63 921 555 1001',
    residence: 'Brgy. Dayangdang, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92836,
    name: 'William Del Rosario',
    stallName: 'Clara Vegetable Cart',
    category: 'VEGETABLES',
    stallType: 'Vegetables',
    location: 'Block 16 - Stall 4',
    email: 'william.del.rosario@gmail.com',
    phone: '+63 921 555 1002',
    residence: 'Brgy. Triangulo, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92837,
    name: 'Sophie Sb',
    stallName: 'Southside Poultry',
    category: 'CHICKEN',
    stallType: 'Chicken',
    location: 'Block 17 - Stall 5',
    email: 'sophie.sb@gmail.com',
    phone: '+63 921 555 1003',
    residence: 'Brgy. Concepcion Grande, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92838,
    name: 'Elena Ramos',
    stallName: 'North Market Fruits',
    category: 'FRUITS',
    stallType: 'Fruits',
    location: 'Block 14 - Stall 6',
    email: 'elena.ramos@gmail.com',
    phone: '+63 921 555 1004',
    residence: 'Brgy. Tinago, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92839,
    name: 'Ricardo Santos',
    stallName: 'Santos Quality Meats',
    category: 'MEAT',
    stallType: 'Meat',
    location: 'Block 15 - Stall 7',
    email: 'ricardo.santos@gmail.com',
    phone: '+63 921 555 1005',
    residence: 'Brgy. Mabolo, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92840,
    name: 'Maria Clara Santos',
    stallName: 'Sunrise Bakery Stall',
    category: 'MARITATAS',
    stallType: 'Maritatas',
    location: 'Block 16 - Stall 8',
    email: 'maria.clara.santos@gmail.com',
    phone: '+63 921 555 1006',
    residence: 'Brgy. Sabang, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92841,
    name: 'Antonio Reyes',
    stallName: 'Central Spice House',
    category: 'SARI-SARI',
    stallType: 'SARI-SARI',
    location: 'Block 17 - Stall 9',
    email: 'antonio.reyes@gmail.com',
    phone: '+63 921 555 1007',
    residence: 'Brgy. San Felipe, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92842,
    name: 'Bianca Salazar',
    stallName: 'Coastal Catch Depot',
    category: 'FRESH FISH',
    stallType: 'Fresh Fish',
    location: 'Block 14 - Stall 2',
    email: 'bianca.salazar@gmail.com',
    phone: '+63 921 555 1008',
    residence: 'Brgy. Cararayan, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92843,
    name: 'Rico Fernandez',
    stallName: 'Baybayin Crafts & Native Snacks',
    category: 'MARITATAS',
    stallType: 'Maritatas',
    location: 'Block 15 - Stall 3',
    email: 'rico.fernandez@gmail.com',
    phone: '+63 921 555 1009',
    residence: 'Brgy. Pacol, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92844,
    name: 'Mila Mendoza',
    stallName: 'Harvest Meat Corner',
    category: 'MEAT',
    stallType: 'Meat',
    location: 'Block 16 - Stall 4',
    email: 'mila.mendoza@gmail.com',
    phone: '+63 921 555 1010',
    residence: 'Brgy. Peñafrancia, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92845,
    name: 'Carlo Mendoza',
    stallName: 'Westside Poultry Farm',
    category: 'CHICKEN',
    stallType: 'Chicken',
    location: 'Block 17 - Stall 5',
    email: 'carlo.mendoza@gmail.com',
    phone: '+63 921 555 1011',
    residence: 'Brgy. Dayangdang, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92846,
    name: 'Diana Villanueva',
    stallName: 'Island Roots Pantry',
    category: 'SARI-SARI',
    stallType: 'SARI-SARI',
    location: 'Block 14 - Stall 6',
    email: 'diana.villanueva@gmail.com',
    phone: '+63 921 555 1012',
    residence: 'Brgy. Triangulo, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92847,
    name: 'Emilio Navarro',
    stallName: 'Valley Harvest Vegetables',
    category: 'VEGETABLES',
    stallType: 'Vegetables',
    location: 'Block 15 - Stall 7',
    email: 'emilio.navarro@gmail.com',
    phone: '+63 921 555 1013',
    residence: 'Brgy. Concepcion Grande, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92848,
    name: 'Fatima Cruz',
    stallName: 'Golden Fields Grains',
    category: 'SARI-SARI',
    stallType: 'SARI-SARI',
    location: 'Block 16 - Stall 8',
    email: 'fatima.cruz@gmail.com',
    phone: '+63 921 555 1014',
    residence: 'Brgy. Tinago, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92849,
    name: 'Gabriel Lim',
    stallName: 'Freshway Dairy Booth',
    category: 'MARITATAS',
    stallType: 'Maritatas',
    location: 'Block 17 - Stall 9',
    email: 'gabriel.lim@gmail.com',
    phone: '+63 921 555 1015',
    residence: 'Brgy. Mabolo, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92850,
    name: 'Helena Bautista',
    stallName: 'Cedar Home Supplies',
    category: 'SARI-SARI',
    stallType: 'SARI-SARI',
    location: 'Block 14 - Stall 2',
    email: 'helena.bautista@gmail.com',
    phone: '+63 921 555 1016',
    residence: 'Brgy. Sabang, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92851,
    name: 'Isaac Fernandez',
    stallName: 'Luzon Fresh Produce',
    category: 'VEGETABLES',
    stallType: 'Vegetables',
    location: 'Block 15 - Stall 3',
    email: 'isaac.fernandez@gmail.com',
    phone: '+63 921 555 1017',
    residence: 'Brgy. San Felipe, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92852,
    name: 'Julia Ramos',
    stallName: 'Orchard Fruit Basket',
    category: 'FRUITS',
    stallType: 'Fruits',
    location: 'Block 16 - Stall 4',
    email: 'julia.ramos@gmail.com',
    phone: '+63 921 555 1018',
    residence: 'Brgy. Cararayan, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92853,
    name: 'Kevin Tan',
    stallName: 'Morning Star Snacks',
    category: 'MARITATAS',
    stallType: 'Maritatas',
    location: 'Block 17 - Stall 5',
    email: 'kevin.tan@gmail.com',
    phone: '+63 921 555 1019',
    residence: 'Brgy. Pacol, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92854,
    name: 'Lucia Flores',
    stallName: 'Pine Street Provisions',
    category: 'SARI-SARI',
    stallType: 'SARI-SARI',
    location: 'Block 14 - Stall 6',
    email: 'lucia.flores@gmail.com',
    phone: '+63 921 555 1020',
    residence: 'Brgy. Peñafrancia, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92855,
    name: 'Cora Morales',
    stallName: 'Township Tea House',
    category: 'MARITATAS',
    stallType: 'Maritatas',
    location: 'Block 15 - Stall 7',
    email: 'cora.morales@gmail.com',
    phone: '+63 921 555 1021',
    residence: 'Brgy. Dayangdang, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92856,
    name: 'Mateo Garcia',
    stallName: 'Green Valley Fresh Greens',
    category: 'VEGETABLES',
    stallType: 'Vegetables',
    location: 'Block 16 - Stall 8',
    email: 'mateo.garcia@gmail.com',
    phone: '+63 921 555 1022',
    residence: 'Brgy. Triangulo, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92857,
    name: 'Nina Castillo',
    stallName: 'Westside Kitchen Poultry',
    category: 'CHICKEN',
    stallType: 'Chicken',
    location: 'Block 17 - Stall 9',
    email: 'nina.castillo@gmail.com',
    phone: '+63 921 555 1023',
    residence: 'Brgy. Concepcion Grande, Naga City',
  ),
  StallHolderProfile(
    idNumber: 92858,
    name: 'Omar Rivera',
    stallName: 'Zest and Spice Stall',
    category: 'SARI-SARI',
    stallType: 'SARI-SARI',
    location: 'Block 14 - Stall 2',
    email: 'omar.rivera@gmail.com',
    phone: '+63 921 555 1024',
    residence: 'Brgy. Tinago, Naga City',
  ),
];

final _customers = [
  'Juan Dela Cruz',
  'Maria Santos',
  'Paolo Rivera',
  'Marcus Koppel',
  'Elena Petrova',
  'Bea Navarro',
  'Nina Morales',
  'Catherine Tan',
  'Miguel Flores',
  'Noah Reyes',
  'Jasmine Lim',
  'Kevin Bautista',
  'Rina Villanueva',
  'Oscar Cruz',
  'Tomas Yu',
  'Ivy Fernandez',
  'Gabriel Ramos',
  'Lara Mendoza',
  'Pia Garcia',
  'Derek Wong',
  'Anne Castillo',
  'Sam Ortega',
  'Sarah Chen',
  'Alex Richardson',
  'Linda Williams',
];

List<Vendor> seedVendors({List<Order>? ordersSource}) {
  final base = DateTime(2023, 10, 12, 10, 45);

  final ordersList = ordersSource ?? seedOrders();
  final vendorStats = <String, (int count, double revenue)>{};
  for (final o in ordersList) {
    final current = vendorStats[o.vendorName] ?? (0, 0.0);
    vendorStats[o.vendorName] = (current.$1 + 1, current.$2 + o.total);
  }

  // Seed vendor accounts for applicants whose initial applications are verified
  final verifiedIndices = [
    0,
    1,
    3,
    4,
    6,
    7,
    8,
    10,
    11,
    13,
    15,
    16,
    18,
    19,
    21,
    22,
    24
  ];

  return List.generate(verifiedIndices.length, (i) {
    final index = verifiedIndices[i];
    final profile = stallHolderProfiles[index];
    final AccountStatus status = switch (index) {
      4 => AccountStatus.offline,
      6 => AccountStatus.suspended,
      7 => AccountStatus.blocked,
      10 => AccountStatus.blocked,
      19 => AccountStatus.offline,
      _ => AccountStatus.active,
    };
    final isStallClosed = index == 10;
    final isBlocked = status == AccountStatus.blocked && !isStallClosed;
    final isClosureRequested = index == 3;
    final isRelocationRequested = index == 1;
    final stats = vendorStats[profile.name];
    final orderCount = stats?.$1 ?? (1429 - index * 31);
    final totalTransactions = stats?.$2 ?? (42800 - index * 875).toDouble();

    return Vendor(
      id: 'VND-${profile.idNumber}',
      name: profile.name,
      email: profile.email,
      stallType: profile.stallType,
      registeredAt: base.add(Duration(days: index * 8, hours: index % 7)),
      status: status,
      location:
          isStallClosed ? 'Archived (${profile.location})' : profile.location,
      orders: orderCount,
      transactions: totalTransactions,
      phone: profile.phone,
      residence: profile.residence,
      administrativeNotes: isStallClosed
          ? 'Stall operations concluded. Formal lease surrender completed and stall archived. Order and financial records preserved for audits.'
          : isBlocked
              ? 'Account permanently restricted due to policy violations.'
              : status == AccountStatus.suspended
                  ? 'Account temporarily under administrative review.'
                  : isClosureRequested
                      ? 'Stall holder submitted formal request to close stall and surrender lease.'
                      : isRelocationRequested
                          ? 'Stall holder requested transfer to Stall #02, Fish Section.'
                          : 'Stall holder account verified.',
      blockedReason: isStallClosed
          ? 'Stall closed upon vendor request: Formal lease surrender and voluntary retirement.'
          : isBlocked
              ? 'Repeated non-compliance with market sanitary guidelines and unauthorized subletting.'
              : null,
      blockedFromReportId: isBlocked ? '#REP-${1040 + index}' : null,
      blockedAt: isStallClosed
          ? DateTime(2024, 2, 10, 14, 30)
          : isBlocked
              ? DateTime(2024, 1, 15).subtract(Duration(days: index * 2))
              : null,
      blockedBy:
          (isBlocked || isStallClosed) ? 'Kirren Michael Fraginal' : null,
      closureRequestedAt: isClosureRequested
          ? DateTime.now().subtract(const Duration(hours: 14))
          : null,
      closureReason: isClosureRequested
          ? 'Retiring from wet market operations after 18 years of service.'
          : null,
      relocationRequestedAt: isRelocationRequested
          ? DateTime.now().subtract(const Duration(hours: 6))
          : null,
      relocationTargetLocation:
          isRelocationRequested ? 'Stall #02, Fish Section' : null,
      relocationReason: isRelocationRequested
          ? 'Requesting relocation closer to primary water and drainage line.'
          : null,
    );
  });
}

List<Customer> seedCustomers() {
  final base = DateTime(2023, 10, 12);
  return List.generate(
    _customers.length,
    (index) => Customer(
      id: 'CUS-${1200 + index}',
      name: _customers[index],
      email:
          '${_customers[index].toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '.')}@example.com',
      registeredAt: base.add(Duration(days: index * 14)),
      transactions: [142, 58, 0, 214, 12, 36, 84][index % 7],
      status: index == 2
          ? AccountStatus.blocked
          : index == 3
              ? AccountStatus.suspended
              : AccountStatus.active,
    ),
  );
}

List<VendorApplication> seedApplications() {
  return List.generate(
    25,
    (index) {
      final profile = stallHolderProfiles[index];
      final status = switch (index) {
        5 || 9 || 12 || 17 || 20 => ApplicationStatus.reviewing,
        2 || 14 || 23 => ApplicationStatus.invalidDocs,
        _ => ApplicationStatus.verified,
      };
      return VendorApplication(
        id: '#APP-${profile.idNumber}',
        applicant: profile.name,
        stallName: profile.stallName,
        category: profile.category,
        submittedAt: DateTime(2023, 10, 24).subtract(Duration(days: index)),
        status: status,
        location: profile.location,
        documents: seedKycDocuments(
            DateTime(2023, 10, 24).subtract(Duration(days: index))),
      );
    },
  );
}

List<KycDocument> seedKycDocuments(DateTime uploadedAt) => [
      KycDocument(
        name: 'Mayor\'s Permit',
        filename: 'mayors-permit.pdf',
        mimeType: 'application/pdf',
        uploadedAt: uploadedAt,
        fileSizeFormatted: '245 KB',
        isLandscape: false,
      ),
      KycDocument(
        name: 'Sanitary Permit',
        filename: 'sanitary-permit.pdf',
        mimeType: 'application/pdf',
        uploadedAt: uploadedAt,
        fileSizeFormatted: '180 KB',
        isLandscape: false,
      ),
      KycDocument(
        name: 'Government ID',
        filename: 'government-id-front-back.jpg',
        mimeType: 'image/jpeg',
        uploadedAt: uploadedAt,
        assetPath: 'assets/images/mobile_conversation.png',
        idFrontAssetPath: 'assets/images/mobile_conversation.png',
        idBackAssetPath: 'assets/images/mobile_conversation.png',
        hasBackSide: true,
        isBackSubmitted: true,
        fileSizeFormatted: '890 KB',
        isLandscape: true,
      ),
      KycDocument(
        name: 'Fire Certification',
        filename: 'fire-certification.docx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        uploadedAt: uploadedAt.subtract(const Duration(days: 1)),
        fileSizeFormatted: '118 KB',
        isLandscape: false,
      ),
      KycDocument(
        name: 'Market Clearance',
        filename: 'market-clearance.pdf',
        mimeType: 'application/pdf',
        uploadedAt: uploadedAt,
        fileSizeFormatted: '310 KB',
        isLandscape: false,
      ),
    ];

List<RenewalRequest> seedRenewals() {
  final now = DateTime.now();
  final targetYear =
      (now.month > 1 || (now.month == 1 && now.day > 7)) ? 2027 : 2026;
  final annualJanuaryDeadline = DateTime(targetYear, 1, 7);
  final expiredJanuaryDeadline = DateTime(targetYear - 1, 1, 7);

  return List.generate(
    25,
    (index) {
      final profile = stallHolderProfiles[index];
      final status = switch (index) {
        1 || 5 || 9 || 13 || 17 || 21 => RenewalStatus.reviewing,
        2 || 6 || 10 || 14 || 18 => RenewalStatus.expired,
        _ => RenewalStatus.approved,
      };
      final DateTime expiryDate = switch (status) {
        RenewalStatus.expired => expiredJanuaryDeadline,
        RenewalStatus.reviewing => annualJanuaryDeadline,
        RenewalStatus.approved => annualJanuaryDeadline,
      };
      final DateTime submittedAt = status == RenewalStatus.expired
          ? expiredJanuaryDeadline.subtract(Duration(days: index % 5 + 1))
          : DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: index % 5));

      return RenewalRequest(
        id: '#RN-${profile.idNumber}',
        applicant: profile.name,
        stallName: profile.stallName,
        category: profile.category,
        expiryDate: expiryDate,
        status: status,
        location: profile.location,
        submittedAt: submittedAt,
        documents: seedKycDocuments(submittedAt),
      );
    },
  );
}

List<Report> seedReports() {
  const customerTopics = [
    'Order Issue',
    'Delivery Problem',
    'Payment Problem',
    'App Issue',
    'Other',
  ];
  const stallHolderTopics = [
    'App Issue',
    'Payout/Earnings',
    'Order Management',
    'Customer Conflict',
    'Other Support',
  ];
  final priorities = [Priority.high, Priority.medium, Priority.low];
  return List.generate(25, (index) {
    final isStallHolder = index % 2 == 0;
    final type = isStallHolder ? 'Stall Holder' : 'Customer';
    final profile =
        stallHolderProfiles[(index ~/ 2) % stallHolderProfiles.length];
    final accountIssue = isStallHolder
        ? profile.name
        : _customers[(index ~/ 2) % _customers.length];
    final submittedBy = isStallHolder
        ? _customers[(index + 9) % _customers.length]
        : profile.name;
    final reason = (isStallHolder
        ? customerTopics
        : stallHolderTopics)[index % customerTopics.length];
    final date = DateTime(2023, 10, 24).subtract(Duration(days: index));

    // Ensure specific accounts used in unit tests (e.g. Diosa Fruit Stand, Juan Dela Cruz) remain active (pending/underReview)
    final ReportStatus status = switch (index) {
      4 || 8 || 14 || 18 || 20 || 24 => ReportStatus.resolved,
      _ => (index % 2 == 0) ? ReportStatus.pending : ReportStatus.underReview,
    };

    final String description = switch (reason) {
      'Order Issue' =>
        'The order was incomplete and the stall holder did not provide the items shown in the order confirmation.',
      'Delivery Problem' =>
        'The delivery arrived outside the agreed time window, causing the perishable items to spoil.',
      'Payment Problem' =>
        'The payment was completed but the order status did not update and no refund has been received.',
      'App Issue' =>
        'The PalengkeGo app failed while processing an order or account request related to this report.',
      'Payout/Earnings' =>
        'A completed order for the related customer is missing from the stall holder payout summary.',
      'Order Management' =>
        'The stall holder needs help managing an order for the related customer after its status did not update correctly.',
      'Customer Conflict' =>
        'The customer used abusive language while disputing an order and the stall holder needs assistance.',
      'Other Support' =>
        'The stall holder submitted a support concern that does not fit the available topics.',
      'Scam or Fraud' => isStallHolder
          ? 'The stall holder collected payment for premium produce but substituted lower grade items and refused a refund upon delivery.'
          : 'The customer claimed goods were never delivered despite rider photo proof and opened a fraudulent chargeback dispute.',
      'Harassment' => isStallHolder
          ? 'The seller became hostile and sent aggressive messages on the chat feature after a customer inquired about late order delivery.'
          : 'The customer submitted abusive and profane messages to the vendor staff during order inquiry.',
      'Bug Report' =>
        'The mobile application crashed during checkout while selecting delivery location, causing duplicated pending order charges.',
      'Incorrect Pricing' => isStallHolder
          ? 'Stall displayed price of ₱180/kg on app listing but charged ₱250/kg at digital payment checkout without notice.'
          : 'Customer attempted to override listed item prices by placing invalid custom order notes.',
      _ => isStallHolder
          ? 'Order delivery arrived 2 hours past agreed scheduled window, resulting in spoiled perishable goods.'
          : 'Customer repeatedly rescheduled rider pick-up times without prior notice.',
    };

    final isResolved = status == ReportStatus.resolved;
    final decisions = [
      'Warning Issued',
      'Account Blocked',
      'Refund Approved',
      'No Violation'
    ];
    final actions = [
      'Warning Issued',
      'Account Blocked',
      'Refund Processed',
      'Dismissed'
    ];

    final reporterEmail = isStallHolder
        ? '${submittedBy.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '.')}@gmail.com'
        : profile.email;

    return Report(
      id: '#RPT-${(index + 1) * 100}',
      type: type,
      accountIssue: accountIssue,
      category: profile.category,
      submittedBy: submittedBy,
      reason: reason,
      date: date,
      status: status,
      priority: priorities[index % priorities.length],
      description: description,
      reporterEmail: reporterEmail,
      phone: profile.phone,
      vendorName: profile.name,
      owner: '',
      stallNumber: profile.location,
      previousViolations: (index % 3),
      notes: isResolved ? 'Resolved by admin officer after investigation.' : '',
      decision: isResolved ? decisions[index % decisions.length] : null,
      actionTaken: isResolved ? actions[index % actions.length] : null,
      resolutionNote: isResolved ? 'Case reviewed and closed.' : null,
      resolvedAt: isResolved ? date.add(const Duration(hours: 5)) : null,
      resolvedBy: isResolved ? 'Administrator' : null,
    );
  });
}

List<Announcement> seedAnnouncements() => [
      Announcement(
        id: 'ANN-1001',
        title: 'New Market Guidelines',
        summary: 'Updated safety protocols for the upcoming weekend market.',
        audience: 'All Users',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        isDraft: false,
        notificationType: 'Push notification',
        state: 'Sent',
        createdBy: 'Admin Office',
        recipientCount: 168,
        deliveredCount: 168,
        failedCount: 0,
      ),
      Announcement(
        id: 'ANN-1002',
        title: 'Maintenance Notice',
        summary: 'Payment reconciliation will be available again at 8:00 AM.',
        audience: 'Stall Holders',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isDraft: false,
        notificationType: 'In-app notice',
        state: 'Sent',
        createdBy: 'Finance Admin',
        recipientCount: 42,
        deliveredCount: 42,
        failedCount: 0,
      ),
      Announcement(
        id: 'ANN-1003',
        title: 'Holiday Operating Hours',
        summary:
            'Please review the special opening schedule for public holidays.',
        audience: 'All Users',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        isDraft: false,
        notificationType: 'Push notification',
        state: 'Sent',
        createdBy: 'Admin Office',
        recipientCount: 168,
        deliveredCount: 165,
        failedCount: 3,
      ),
      Announcement(
        id: 'ANN-1004',
        title: 'Stall Holder Orientation & Training',
        summary: 'New stall holders can reserve a training slot this week.',
        audience: 'Stall Holders',
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        isDraft: false,
        notificationType: 'In-app notice',
        state: 'Sent',
        createdBy: 'Market Supervisor',
        recipientCount: 42,
        deliveredCount: 42,
        failedCount: 0,
      ),
      Announcement(
        id: 'ANN-1005',
        title: 'Fresh Finds Rewards Campaign',
        summary: 'Customers can now redeem points at participating stalls.',
        audience: 'Customers',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        isDraft: false,
        notificationType: 'Push notification',
        state: 'Sent',
        createdBy: 'Marketing Desk',
        recipientCount: 126,
        deliveredCount: 126,
        failedCount: 0,
      ),
      Announcement(
        id: 'ANN-1006',
        title: 'Weekend Market Sanitation Protocol Draft',
        summary: 'Scheduled deep cleaning for fish and meat market aisles.',
        audience: 'Stall Holders',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        isDraft: true,
        notificationType: 'In-app notice',
        state: 'Draft',
        createdBy: 'Admin Office',
        recipientCount: 42,
        deliveredCount: 0,
        failedCount: 0,
      ),
    ];

const topSellerNames = ['Aicel Castillo', 'Mila Mendoza', 'Elena Ramos'];
const topSellerRevenue = ['43.9k', '34.1k', '17.1k'];
const topSellerOrders = ['2395 orders', '2013 orders', '1579 orders'];

List<Order> seedOrders() {
  final customers = [
    'Alex Richardson',
    'Linda Williams',
    'Juan Dela Cruz',
    'Maria Santos'
  ];

  final vendorProfiles = [
    (
      name: 'Aicel Castillo',
      category: 'FRESH FISH',
      stall: 'Riverside Seafood',
      products: [
        ('Bangus', 220.0),
        ('Tilapia', 180.0),
      ],
    ),
    (
      name: 'Mila Mendoza',
      category: 'MEAT',
      stall: 'Harvest Meat Corner',
      products: [
        ('Pork Belly', 360.0),
        ('Beef Sirloin', 420.0),
      ],
    ),
    (
      name: 'Elena Ramos',
      category: 'FRUITS',
      stall: 'North Market Fruits',
      products: [
        ('Mangoes', 180.0),
        ('Ripe Papaya & Bananas', 120.0),
      ],
    ),
    (
      name: 'Sophie Sb',
      category: 'CHICKEN',
      stall: 'Southside Poultry',
      products: [
        ('Whole Dressed Chicken', 210.0),
        ('Chicken Wings & Thighs', 190.0),
      ],
    ),
    (
      name: 'Emilio Navarro',
      category: 'VEGETABLES',
      stall: 'Valley Harvest Vegetables',
      products: [
        ('Fresh Vegetables', 150.0),
        ('Pinakbet Pack', 110.0),
      ],
    ),
    (
      name: 'Diosa Del Rosario',
      category: 'DRIED FISH',
      stall: 'Bicol Dry Goods',
      products: [
        ('Daing na Bangus', 160.0),
        ('Tuyô & Danggit', 140.0),
      ],
    ),
    (
      name: 'Maria Clara Santos',
      category: 'MARITATAS',
      stall: 'Sunrise Bakery Stall',
      products: [
        ('Cassava Cake & Delicacies', 120.0),
        ('Native Kakanin', 90.0),
      ],
    ),
    (
      name: 'Antonio Reyes',
      category: 'SARI-SARI',
      stall: 'Central Spice House',
      products: [
        ('Canned Goods & Essentials', 85.0),
        ('Cooking Oil & Condiments', 75.0),
      ],
    ),
  ];

  final statuses = [
    OrderStatus.completed,
    OrderStatus.completed,
    OrderStatus.processing,
    OrderStatus.pending,
    OrderStatus.refunded,
    OrderStatus.cancelled,
  ];
  final payments = [
    PaymentStatus.paid,
    PaymentStatus.paid,
    PaymentStatus.pending,
    PaymentStatus.pending,
    PaymentStatus.refunded,
    PaymentStatus.failed,
  ];
  final methods = [
    PaymentMethod.gcash,
    PaymentMethod.card,
    PaymentMethod.wallet,
    PaymentMethod.cashOnDelivery,
  ];

  final now = DateTime.now();
  return List.generate(48, (index) {
    // Select vendor profile ensuring realistic distribution across Accounts stall holders
    final profileIdx = switch (index % 12) {
      0 || 1 || 2 => 0, // Aicel Castillo (Fresh Fish) - 12 orders
      3 || 4 => 1, // Mila Mendoza (Meat) - 8 orders
      5 || 6 => 2, // Elena Ramos (Fruits) - 8 orders
      7 => 3, // Sophie Sb (Chicken) - 4 orders
      8 => 4, // Emilio Navarro (Vegetables) - 4 orders
      9 => 5, // Diosa Del Rosario (Dried Fish) - 4 orders
      10 => 6, // Maria Clara Santos (Maritatas) - 4 orders
      _ => 7, // Antonio Reyes (SARI-SARI) - 4 orders
    };

    final profile = vendorProfiles[profileIdx];
    final prodPrimary = profile.products[index % profile.products.length];
    final prodSecondary =
        profile.products[(index + 1) % profile.products.length];
    final quantity = 1 + index % 4;
    final placedAt =
        now.subtract(Duration(days: index % 38, hours: index % 12));
    final datePart = '${(placedAt.year % 100).toString().padLeft(2, '0')}'
        '${placedAt.month.toString().padLeft(2, '0')}'
        '${placedAt.day.toString().padLeft(2, '0')}';

    final items = [
      OrderItem(
        name: prodPrimary.$1,
        category: profile.category,
        quantity: quantity.toDouble(),
        unitPrice: prodPrimary.$2.toDouble(),
      ),
      if (index % 3 == 0)
        OrderItem(
          name: prodSecondary.$1,
          category: profile.category,
          quantity: 1.0,
          unitPrice: prodSecondary.$2.toDouble(),
        ),
    ];

    return Order(
      id: '$datePart-${(index + 1).toString().padLeft(2, '0')}',
      transactionId: 'TXN-${72001 + index}',
      placedAt: placedAt,
      customerName: customers[index % customers.length],
      vendorName: profile.name,
      stallName: profile.stall,
      items: items,
      discounts: index % 5 == 0 ? 25 : 0,
      deliveryFee: 40,
      platformFee: 15,
      refundAmount:
          statuses[index % statuses.length] == OrderStatus.refunded ? 120 : 0,
      paymentMethod: methods[index % methods.length],
      paymentStatus: payments[index % payments.length],
      status: statuses[index % statuses.length],
    );
  });
}

const avatarColors = [
  Color(0xFFFFD7B5),
  Color(0xFFB8D8FF),
  Color(0xFFC8E6C9),
  Color(0xFFFFE0B2),
  Color(0xFFE1BEE7),
];

List<Suspension> seedSuspensions() {
  final now = DateTime.now();
  final vendors = seedVendors();
  final suspendedVendors =
      vendors.where((v) => v.status == AccountStatus.suspended).toList();

  final suspensions = <Suspension>[];

  for (var i = 0; i < suspendedVendors.length; i++) {
    final v = suspendedVendors[i];
    suspensions.add(
      Suspension(
        id: 'SUS-${9001 + i}',
        accountId: v.id,
        accountName: v.name,
        accountType: 'Stall Holder',
        reason: i % 2 == 0
            ? 'Sanitary permit expired and pending renewal inspection'
            : 'Pricing inconsistency and stall encroachment under investigation',
        startDate: now.subtract(Duration(days: 2 + i)),
        endDate: now.add(Duration(days: 5 + i)),
        administratorId: 'ADM-001',
        administratorName: 'Kirren Michael Fraginal',
        createdAt: now.subtract(Duration(days: 2 + i)),
        note: 'Stall temporarily held pending compliance review',
        notifyUser: true,
        relatedReportId: '#REP-${1020 + i}',
      ),
    );
  }

  suspensions.add(
    Suspension(
      id: 'SUS-9099',
      accountId: 'CUS-1203',
      accountName: 'Marcus Koppel',
      accountType: 'Customer',
      reason: 'Repeated cancellation of accepted orders',
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 6)),
      administratorId: 'ADM-001',
      administratorName: 'Kirren Michael Fraginal',
      createdAt: now.subtract(const Duration(days: 1)),
      note: 'Account temporarily suspended for review',
      notifyUser: true,
      relatedReportId: '#REP-1015',
    ),
  );

  return suspensions;
}

List<AuditLog> seedAuditLogs() {
  final now = DateTime.now();
  const adminName = 'Kirren Michael Fraginal';
  return [
    AuditLog(
      id: 'AUD-8801',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.approveKyc,
      targetEntityType: 'VendorApplication',
      targetEntityId: '#APP-92834',
      targetUserName: 'Elena Ramos',
      previousValue: 'Reviewing',
      newValue: 'Verified',
      reason: 'All submitted permits verified with City Hall records',
      metadata: const {'source': 'verification_dialog'},
      timestamp: now.subtract(const Duration(hours: 2)),
    ),
    AuditLog(
      id: 'AUD-8802',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.approveKyc,
      targetEntityType: 'VendorApplication',
      targetEntityId: '#APP-92835',
      targetUserName: 'Mateo Santos',
      previousValue: 'Reviewing',
      newValue: 'Verified',
      reason: 'Sanitary and fire clearances verified',
      metadata: const {'source': 'verification_dialog'},
      timestamp: now.subtract(const Duration(hours: 5)),
    ),
    AuditLog(
      id: 'AUD-8803',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.rejectKyc,
      targetEntityType: 'VendorApplication',
      targetEntityId: '#APP-92836',
      targetUserName: 'Corazon Aquino',
      previousValue: 'Reviewing',
      newValue: 'Rejected',
      reason: 'Expired mayor\'s permit document submitted',
      metadata: const {'source': 'verification_dialog'},
      timestamp: now.subtract(const Duration(hours: 8)),
    ),
    AuditLog(
      id: 'AUD-8804',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.approveKyc,
      targetEntityType: 'VendorApplication',
      targetEntityId: '#APP-92837',
      targetUserName: 'Danilo Cruz',
      previousValue: 'Reviewing',
      newValue: 'Verified',
      reason: 'Valid DTI registration and Barangay clearance',
      metadata: const {'source': 'verification_dialog'},
      timestamp: now.subtract(const Duration(days: 1, hours: 3)),
    ),
    AuditLog(
      id: 'AUD-8805',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.rejectKyc,
      targetEntityType: 'VendorApplication',
      targetEntityId: '#APP-92838',
      targetUserName: 'Rowena Bautista',
      previousValue: 'Reviewing',
      newValue: 'InvalidDocs',
      reason: 'Government ID photo is blurry and illegible',
      metadata: const {'source': 'verification_dialog'},
      timestamp: now.subtract(const Duration(days: 1, hours: 7)),
    ),
    AuditLog(
      id: 'AUD-8806',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.blockAccount,
      targetEntityType: 'Vendor',
      targetEntityId: 'VND-92836',
      targetUserName: 'William Del Rosario - Clara Vegetable Cart',
      previousValue: 'Active',
      newValue: 'Blocked',
      reason: 'Repeated underweight produce violations reported',
      metadata: const {'relatedReportId': '#RPT-0001'},
      timestamp: now.subtract(const Duration(days: 2, hours: 1)),
    ),
    AuditLog(
      id: 'AUD-8807',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.suspendAccount,
      targetEntityType: 'Vendor',
      targetEntityId: 'VND-92837',
      targetUserName: 'Sophie Sb - Southside Poultry',
      previousValue: 'Active',
      newValue: 'Suspended',
      reason: 'Pricing inconsistency under investigation',
      metadata: const {'durationDays': '7'},
      timestamp: now.subtract(const Duration(days: 2, hours: 4)),
    ),
    AuditLog(
      id: 'AUD-8808',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.blockAccount,
      targetEntityType: 'Customer',
      targetEntityId: 'CUS-1202',
      targetUserName: 'Dr. Sarah Chen',
      previousValue: 'Active',
      newValue: 'Blocked',
      reason: 'Abusive language directed at stall holders',
      metadata: const {'relatedReportId': '#RPT-0004'},
      timestamp: now.subtract(const Duration(days: 3, hours: 2)),
    ),
    AuditLog(
      id: 'AUD-8809',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.suspendAccount,
      targetEntityType: 'Customer',
      targetEntityId: 'CUS-1203',
      targetUserName: 'Marcus Koppel',
      previousValue: 'Active',
      newValue: 'Suspended',
      reason: 'Repeated cancellation of accepted orders',
      metadata: const {'durationDays': '7'},
      timestamp: now.subtract(const Duration(days: 3, hours: 6)),
    ),
    AuditLog(
      id: 'AUD-8810',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.sendAnnouncement,
      targetEntityType: 'Announcement',
      targetEntityId: 'ANN-001',
      targetUserName: 'All Users',
      previousValue: 'Draft',
      newValue: 'Sent',
      reason: 'Market operational hours update broadcast',
      metadata: const {'audience': 'All', 'channel': 'Push + SMS'},
      timestamp: now.subtract(const Duration(days: 4, hours: 1)),
    ),
    AuditLog(
      id: 'AUD-8811',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.resolveReport,
      targetEntityType: 'Report',
      targetEntityId: '#RPT-0003',
      targetUserName: 'Santos Quality Meats',
      previousValue: 'UnderReview',
      newValue: 'Resolved',
      reason: 'Quality issue reviewed with stall owner; replacement issued',
      metadata: const {'decision': 'Resolved with stall owner'},
      timestamp: now.subtract(const Duration(days: 4, hours: 5)),
    ),
    AuditLog(
      id: 'AUD-8812',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.changeSettings,
      targetEntityType: 'SystemSettings',
      targetEntityId: 'SET-001',
      targetUserName: 'System',
      previousValue: 'Default',
      newValue: 'Updated',
      reason: 'Delivery commission fee adjusted for rainy season',
      metadata: const {'setting': 'delivery_fee_policy'},
      timestamp: now.subtract(const Duration(days: 5, hours: 2)),
    ),
    AuditLog(
      id: 'AUD-8813',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.login,
      targetEntityType: 'AdminSession',
      targetEntityId: 'SES-1001',
      targetUserName: adminName,
      previousValue: 'Signed out',
      newValue: 'Signed in',
      reason: 'Administrative web console login',
      metadata: const {'ip': '192.168.1.100'},
      timestamp: now.subtract(const Duration(days: 5, hours: 8)),
    ),
    AuditLog(
      id: 'AUD-8814',
      administratorId: 'ADM-001',
      administratorName: adminName,
      action: AuditAction.approveKyc,
      targetEntityType: 'VendorApplication',
      targetEntityId: '#APP-92839',
      targetUserName: 'Ricardo Santos',
      previousValue: 'Reviewing',
      newValue: 'Verified',
      reason: 'Stall permit and lease contract fully verified',
      metadata: const {'source': 'verification_dialog'},
      timestamp: now.subtract(const Duration(days: 6, hours: 4)),
    ),
  ];
}
