import 'dart:typed_data';

enum StallStatus { available, occupied, reserved, underMaintenance }

class Stall {
  const Stall({
    required this.id,
    required this.stallNumber,
    required this.section,
    required this.status,
    this.vendorId,
    this.vendorName,
    this.maintenanceNotes,
    this.closureStartDate,
    this.closureEndDate,
  });

  final String id;
  final String stallNumber;
  final String section;
  final StallStatus status;
  final String? vendorId;
  final String? vendorName;
  final String? maintenanceNotes;
  final DateTime? closureStartDate;
  final DateTime? closureEndDate;

  /// Use the clear flags to remove nullable relationships or maintenance data.
  Stall copyWith({
    String? stallNumber,
    String? section,
    StallStatus? status,
    String? vendorId,
    String? vendorName,
    String? maintenanceNotes,
    DateTime? closureStartDate,
    DateTime? closureEndDate,
    bool clearVendor = false,
    bool clearMaintenance = false,
  }) {
    return Stall(
      id: id,
      stallNumber: stallNumber ?? this.stallNumber,
      section: section ?? this.section,
      status: status ?? this.status,
      vendorId: clearVendor ? null : (vendorId ?? this.vendorId),
      vendorName: clearVendor ? null : (vendorName ?? this.vendorName),
      maintenanceNotes:
          clearMaintenance ? null : (maintenanceNotes ?? this.maintenanceNotes),
      closureStartDate:
          clearMaintenance ? null : (closureStartDate ?? this.closureStartDate),
      closureEndDate:
          clearMaintenance ? null : (closureEndDate ?? this.closureEndDate),
    );
  }
}

enum AccountStatus { active, offline, suspended, blocked }

enum ApplicationStatus { verified, reviewing, invalidDocs, rejected }

enum RenewalStatus { approved, reviewing, expired }

enum ReportStatus { pending, underReview, resolved, dismissed }

enum Priority { high, medium, low }

class KycDocument {
  const KycDocument({
    required this.name,
    required this.filename,
    required this.mimeType,
    required this.uploadedAt,
    this.assetPath,
    this.fileSizeFormatted,
    this.fileUrl,
    this.isLandscape = false,
    this.idFrontAssetPath,
    this.idBackAssetPath,
    this.idFrontUrl,
    this.idBackUrl,
    this.hasBackSide = false,
    this.isBackSubmitted = true,
  });

  final String name;
  final String filename;
  final String mimeType;
  final DateTime uploadedAt;
  final String? assetPath;
  final String? fileSizeFormatted;
  final String? fileUrl;
  final bool isLandscape;
  final String? idFrontAssetPath;
  final String? idBackAssetPath;
  final String? idFrontUrl;
  final String? idBackUrl;
  final bool hasBackSide;
  final bool isBackSubmitted;
}

final _enumLabelCache = <Object, String>{};

String enumLabel(Object value) {
  return _enumLabelCache.putIfAbsent(value, () {
    final raw = value.toString().split('.').last;
    final spaced = raw.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  });
}

class Vendor {
  const Vendor({
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
    this.administrativeNotes = '',
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
  final String administrativeNotes;
  final String? blockedReason;
  final String? blockedFromReportId;
  final DateTime? blockedAt;
  final String? blockedBy;
  final DateTime? closureRequestedAt;
  final String? closureReason;
  final DateTime? relocationRequestedAt;
  final String? relocationTargetLocation;
  final String? relocationReason;

  Vendor copyWith({
    AccountStatus? status,
    String? administrativeNotes,
    String? blockedReason,
    String? blockedFromReportId,
    DateTime? blockedAt,
    String? blockedBy,
    String? location,
    String? stallType,
    DateTime? closureRequestedAt,
    String? closureReason,
    DateTime? relocationRequestedAt,
    String? relocationTargetLocation,
    String? relocationReason,
    bool clearBlockDetails = false,
    bool clearClosureRequest = false,
    bool clearRelocationRequest = false,
  }) =>
      Vendor(
        id: id,
        name: name,
        email: email,
        stallType: stallType ?? this.stallType,
        registeredAt: registeredAt,
        status: status ?? this.status,
        location: location ?? this.location,
        orders: orders,
        transactions: transactions,
        phone: phone,
        residence: residence,
        administrativeNotes: administrativeNotes ?? this.administrativeNotes,
        blockedReason:
            clearBlockDetails ? null : blockedReason ?? this.blockedReason,
        blockedFromReportId: clearBlockDetails
            ? null
            : blockedFromReportId ?? this.blockedFromReportId,
        blockedAt: clearBlockDetails ? null : blockedAt ?? this.blockedAt,
        blockedBy: clearBlockDetails ? null : blockedBy ?? this.blockedBy,
        closureRequestedAt: clearClosureRequest
            ? null
            : closureRequestedAt ?? this.closureRequestedAt,
        closureReason:
            clearClosureRequest ? null : closureReason ?? this.closureReason,
        relocationRequestedAt: clearRelocationRequest
            ? null
            : relocationRequestedAt ?? this.relocationRequestedAt,
        relocationTargetLocation: clearRelocationRequest
            ? null
            : relocationTargetLocation ?? this.relocationTargetLocation,
        relocationReason: clearRelocationRequest
            ? null
            : relocationReason ?? this.relocationReason,
      );
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.registeredAt,
    required this.transactions,
    required this.status,
    this.administrativeNotes = '',
    this.blockedReason,
    this.blockedFromReportId,
    this.blockedAt,
    this.blockedBy,
  });

  final String id;
  final String name;
  final String email;
  final DateTime registeredAt;
  final int transactions;
  final AccountStatus status;
  final String administrativeNotes;
  final String? blockedReason;
  final String? blockedFromReportId;
  final DateTime? blockedAt;
  final String? blockedBy;

  Customer copyWith({
    AccountStatus? status,
    String? administrativeNotes,
    String? blockedReason,
    String? blockedFromReportId,
    DateTime? blockedAt,
    String? blockedBy,
    bool clearBlockDetails = false,
  }) =>
      Customer(
        id: id,
        name: name,
        email: email,
        registeredAt: registeredAt,
        transactions: transactions,
        status: status ?? this.status,
        administrativeNotes: administrativeNotes ?? this.administrativeNotes,
        blockedReason:
            clearBlockDetails ? null : blockedReason ?? this.blockedReason,
        blockedFromReportId: clearBlockDetails
            ? null
            : blockedFromReportId ?? this.blockedFromReportId,
        blockedAt: clearBlockDetails ? null : blockedAt ?? this.blockedAt,
        blockedBy: clearBlockDetails ? null : blockedBy ?? this.blockedBy,
      );
}

class VendorApplication {
  const VendorApplication({
    required this.id,
    required this.applicant,
    required this.stallName,
    required this.category,
    required this.submittedAt,
    required this.status,
    required this.location,
    this.documents = const [],
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
  });

  final String id;
  final String applicant;
  final String stallName;
  final String category;
  final DateTime submittedAt;
  final ApplicationStatus status;
  final String location;
  final List<KycDocument> documents;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  VendorApplication copyWith({
    ApplicationStatus? status,
    String? rejectionReason,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) =>
      VendorApplication(
        id: id,
        applicant: applicant,
        stallName: stallName,
        category: category,
        submittedAt: submittedAt,
        status: status ?? this.status,
        location: location,
        documents: documents,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        reviewedBy: reviewedBy ?? this.reviewedBy,
      );
}

class RenewalRequest {
  const RenewalRequest({
    required this.id,
    required this.applicant,
    required this.stallName,
    required this.category,
    required this.expiryDate,
    required this.status,
    required this.location,
    this.submittedAt,
    this.rejectionReason,
    this.documents = const [],
  });

  final String id;
  final String applicant;
  final String stallName;
  final String category;
  final DateTime expiryDate;
  final RenewalStatus status;
  final String location;
  final DateTime? submittedAt;
  final String? rejectionReason;
  final List<KycDocument> documents;

  RenewalRequest copyWith({
    RenewalStatus? status,
    DateTime? submittedAt,
    String? rejectionReason,
    List<KycDocument>? documents,
  }) =>
      RenewalRequest(
        id: id,
        applicant: applicant,
        stallName: stallName,
        category: category,
        expiryDate: expiryDate,
        status: status ?? this.status,
        location: location,
        submittedAt: submittedAt ?? this.submittedAt,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        documents: documents ?? this.documents,
      );
}

class Report {
  final List<String> evidenceUrls;
  bool get isUnread => status == ReportStatus.pending;

  const Report({
    this.evidenceUrls = const [],
    required this.id,
    required this.type,
    required this.accountIssue,
    this.category = 'FRESH FISH',
    required this.submittedBy,
    required this.reason,
    required this.date,
    required this.status,
    required this.priority,
    required this.description,
    required this.reporterEmail,
    required this.phone,
    required this.vendorName,
    required this.owner,
    required this.stallNumber,
    required this.previousViolations,
    required this.notes,
    this.decision,
    this.actionTaken,
    this.resolutionNote,
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String type;
  final String accountIssue;
  final String? category;
  final String submittedBy;
  final String reason;
  final DateTime date;
  final ReportStatus status;
  final Priority priority;
  final String description;
  final String reporterEmail;
  final String phone;
  final String vendorName;
  final String owner;
  final String stallNumber;
  final int previousViolations;
  final String notes;
  final String? decision;
  final String? actionTaken;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  Report copyWith({
    ReportStatus? status,
    String? notes,
    String? decision,
    String? actionTaken,
    String? resolutionNote,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) =>
      Report(
        id: id,
        type: type,
        accountIssue: accountIssue,
        category: category,
        submittedBy: submittedBy,
        reason: reason,
        date: date,
        status: status ?? this.status,
        priority: priority,
        description: description,
        reporterEmail: reporterEmail,
        phone: phone,
        vendorName: vendorName,
        owner: owner,
        stallNumber: stallNumber,
        previousViolations: previousViolations,
        evidenceUrls: evidenceUrls,
        notes: notes ?? this.notes,
        decision: decision ?? this.decision,
        actionTaken: actionTaken ?? this.actionTaken,
        resolutionNote: resolutionNote ?? this.resolutionNote,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        resolvedBy: resolvedBy ?? this.resolvedBy,
      );
}

class Announcement {
  const Announcement({
    this.id = '',
    required this.title,
    required this.summary,
    required this.audience,
    required this.createdAt,
    required this.isDraft,
    this.notificationType = 'Information',
    this.state = 'Sent',
    this.scheduledAt,
    this.expiresAt,
    this.createdBy = 'ADM-001',
    this.recipientCount = 0,
    this.deliveredCount = 0,
    this.failedCount = 0,
    this.imageUrl,
    this.imageBytes,
    this.popupImageUrls = const [],
    this.popupImageBytes = const [],
    this.showAsPopup = false,
    this.facebookUrl,
  });

  final String id;
  final String title;
  final String summary;
  final String audience;
  final DateTime createdAt;
  final bool isDraft;
  final String notificationType;
  final String state;
  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final String createdBy;
  final int recipientCount;
  final int deliveredCount;
  final int failedCount;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final List<String> popupImageUrls;
  final List<Uint8List> popupImageBytes;
  final bool showAsPopup;
  final String? facebookUrl;

  Announcement copyWith({
    String? id,
    String? title,
    String? summary,
    String? audience,
    DateTime? createdAt,
    bool? isDraft,
    String? notificationType,
    String? state,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    String? createdBy,
    int? recipientCount,
    int? deliveredCount,
    int? failedCount,
    String? imageUrl,
    Uint8List? imageBytes,
    List<String>? popupImageUrls,
    List<Uint8List>? popupImageBytes,
    bool? showAsPopup,
    String? facebookUrl,
    bool clearImage = false,
  }) =>
      Announcement(
        id: id ?? this.id,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        audience: audience ?? this.audience,
        createdAt: createdAt ?? this.createdAt,
        isDraft: isDraft ?? this.isDraft,
        notificationType: notificationType ?? this.notificationType,
        state: state ?? this.state,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        expiresAt: expiresAt ?? this.expiresAt,
        createdBy: createdBy ?? this.createdBy,
        recipientCount: recipientCount ?? this.recipientCount,
        deliveredCount: deliveredCount ?? this.deliveredCount,
        failedCount: failedCount ?? this.failedCount,
        imageUrl: clearImage ? null : imageUrl ?? this.imageUrl,
        imageBytes: clearImage ? null : imageBytes ?? this.imageBytes,
        popupImageUrls: popupImageUrls ?? this.popupImageUrls,
        popupImageBytes: popupImageBytes ?? this.popupImageBytes,
        showAsPopup: showAsPopup ?? this.showAsPopup,
        facebookUrl: facebookUrl ?? this.facebookUrl,
      );
}
