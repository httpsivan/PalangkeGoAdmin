import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/widgets/document_viewer_modal.dart';
import '../../data/mock_data.dart';
import '../../data/repositories/mock_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../models/admin_notification.dart';
import '../../models/app_models.dart';

class VerificationDialog extends ConsumerStatefulWidget {
  const VerificationDialog.application(this.application, {super.key})
      : renewal = null,
        isHistory = false;
  const VerificationDialog.renewal(
    this.renewal, {
    super.key,
    this.isHistory = false,
  }) : application = null;
  final VendorApplication? application;
  final RenewalRequest? renewal;
  final bool isHistory;
  String get applicant => application?.applicant ?? renewal!.applicant;
  String get stall => application?.stallName ?? renewal!.stallName;
  String get category => application?.category ?? renewal!.category;
  String get location => application?.location ?? renewal!.location;
  String get id => application?.id ?? renewal!.id;
  @override
  ConsumerState<VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends ConsumerState<VerificationDialog> {
  bool processing = false;

  Future<void> approve() async {
    final okay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve application?'),
        content: const Text('This will grant marketplace access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (okay != true || !mounted) return;
    setState(() => processing = true);
    if (widget.application != null) {
      await ref
          .read(appDataProvider.notifier)
          .updateApplication(widget.id, ApplicationStatus.verified);
    }
    if (widget.renewal != null) {
      await ref
          .read(appDataProvider.notifier)
          .updateRenewal(widget.id, RenewalStatus.approved);
    }
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);

      Navigator.pop(context);

      messenger.clearSnackBars();
      if (widget.application != null) {
        final controller = messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Application approved! Stall allocation (${widget.location}) locked.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        Future.delayed(const Duration(seconds: 4), () {
          try {
            controller.close();
          } catch (_) {}
        });
      } else {
        final controller = messenger.showSnackBar(
          const SnackBar(
            content: Text('Stall renewal approved.'),
            duration: Duration(seconds: 4),
          ),
        );
        Future.delayed(const Duration(seconds: 4), () {
          try {
            controller.close();
          } catch (_) {}
        });
      }
    }
  }

  Future<void> reject() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _PromptInputDialogWidget(
        title: widget.renewal != null
            ? 'Reject renewal request'
            : 'Reject application',
        hintText: 'Add a mandatory reason for rejection...',
        confirmLabel: 'Reject',
        minLines: 2,
        maxLines: 4,
        isRequired: true,
      ),
    );
    if (value == null || value.trim().isEmpty || !mounted) return;
    setState(() => processing = true);
    if (widget.application != null) {
      await ref.read(appDataProvider.notifier).updateApplication(
            widget.id,
            ApplicationStatus.rejected,
            rejectionReason: value.trim(),
          );
    }
    if (widget.renewal != null) {
      await ref.read(appDataProvider.notifier).updateRenewal(
            widget.id,
            RenewalStatus.expired,
            rejectionReason: value.trim(),
          );
    }
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.renewal != null
                ? 'Renewal request rejected.'
                : 'Application rejected.',
          ),
        ),
      );
    }
  }

  Future<void> _reopenForReview() async {
    final okay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen for review?'),
        content: const Text(
          "Reopen this renewal for review? The stall holder's renewal status will change back to Under Review.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
    if (okay != true || !mounted) return;
    setState(() => processing = true);
    if (widget.application != null) {
      await ref
          .read(appDataProvider.notifier)
          .updateApplication(widget.id, ApplicationStatus.reviewing);
    }
    if (widget.renewal != null) {
      await ref
          .read(appDataProvider.notifier)
          .updateRenewal(widget.id, RenewalStatus.reviewing);
    }
    if (mounted) {
      setState(() => processing = false);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Application reopened for review.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 850;
    final appData = ref.watch(appDataProvider);
    final currentApp = widget.application != null
        ? appData.applications.firstWhere(
            (a) => a.id == widget.id,
            orElse: () => widget.application!,
          )
        : null;
    final currentRenewal = widget.renewal != null
        ? appData.renewals.firstWhere(
            (r) => r.id == widget.id,
            orElse: () => widget.renewal!,
          )
        : null;

    final isApproved = (currentApp?.status == ApplicationStatus.verified) ||
        (currentRenewal?.status == RenewalStatus.approved);
    final isRejected = (currentApp?.status == ApplicationStatus.rejected) ||
        (currentApp?.status == ApplicationStatus.invalidDocs) ||
        (currentRenewal?.status == RenewalStatus.expired);

    final isHistoricalView = widget.isHistory ||
        (widget.renewal != null &&
            currentRenewal?.status != RenewalStatus.reviewing);

    final effectiveApproved = isApproved || (widget.isHistory && !isRejected);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 10 : 40,
        vertical: narrow ? 10 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1040,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(narrow ? 16 : 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.renewal != null
                              ? (isHistoricalView
                                  ? 'RENEWALS  /  HISTORICAL RENEWAL RECORD'
                                  : 'RENEWALS  /  RENEWAL REQUEST DETAIL')
                              : 'TENANTS  /  VERIFICATION DETAIL',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: isHistoricalView
                                ? FontWeight.w700
                                : FontWeight.w500,
                            letterSpacing: 0.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: isHistoricalView ? .75 : .5),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            AvatarCircle(name: widget.applicant, size: 48),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.applicant,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (isHistoricalView) ...[
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            'Archived Record',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                      ] else if (widget.renewal != null) ...[
                                        const SizedBox(width: 10),
                                        StatusBadge(
                                          label: enumLabel(
                                              currentRenewal?.status ??
                                                  widget.renewal!.status),
                                          kind: (currentRenewal?.status ??
                                                      widget.renewal!.status) ==
                                                  RenewalStatus.approved
                                              ? BadgeKind.success
                                              : (currentRenewal?.status ??
                                                          widget.renewal!
                                                              .status) ==
                                                      RenewalStatus.expired
                                                  ? BadgeKind.danger
                                                  : BadgeKind.warning,
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (!narrow) ...[
                                    const SizedBox(height: 4),
                                    _buildSubtitleWrap(
                                      context,
                                      currentApp,
                                      currentRenewal,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (narrow) ...[
                          const SizedBox(height: 8),
                          _buildSubtitleWrap(
                            context,
                            currentApp,
                            currentRenewal,
                          ),
                        ],
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
              const SizedBox(height: 17),
              const Divider(),
              const SizedBox(height: 17),
              if (narrow) ...[
                _documents(context),
                const SizedBox(height: 18),
                _summary(context, currentApp, currentRenewal),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 64, child: _documents(context)),
                    const SizedBox(width: 20),
                    Expanded(
                        flex: 36,
                        child: _summary(context, currentApp, currentRenewal)),
                  ],
                ),
              const SizedBox(height: 22),
              _buildActionSection(
                context,
                isApproved: effectiveApproved,
                isRejected: isRejected,
                currentApp: currentApp,
                currentRenewal: currentRenewal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleWrap(
    BuildContext context,
    VendorApplication? currentApp,
    RenewalRequest? currentRenewal,
  ) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final submittedDate = currentRenewal?.submittedAt ??
        currentApp?.submittedAt ??
        widget.renewal?.submittedAt ??
        widget.application?.submittedAt ??
        DateTime.now();
    final dateText = narrow
        ? 'Submitted: ${DateFormat('MMM dd, yyyy').format(submittedDate)}'
        : 'Submitted: ${DateFormat('MMM dd, yyyy, h:mm a').format(submittedDate)}';
    // This dialog serves both application and renewal review records.
    final idLabel =
        widget.application == null ? 'Renewal ID' : 'Application ID';

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 13,
              color: semanticColors(context).mutedText,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$idLabel: #${widget.id.replaceFirst(RegExp(r'^#+'), '')}',
                maxLines: 1,
                overflow: narrow ? TextOverflow.ellipsis : TextOverflow.visible,
                style: TextStyle(
                  fontSize: 11,
                  color: semanticColors(context).mutedText,
                ),
              ),
            ),
          ],
        ),
        Text(
          '•',
          style: TextStyle(
            fontSize: 11,
            color: semanticColors(context).mutedText,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store_outlined,
              size: 13,
              color: semanticColors(context).mutedText,
            ),
            const SizedBox(width: 4),
            Text(
              widget.location,
              style: TextStyle(
                fontSize: 11,
                color: semanticColors(context).mutedText,
              ),
            ),
          ],
        ),
        Text(
          '•',
          style: TextStyle(
            fontSize: 11,
            color: semanticColors(context).mutedText,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 13,
              color: semanticColors(context).mutedText,
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: narrow ? 230 : double.infinity,
              ),
              child: Text(
                dateText,
                overflow: narrow ? TextOverflow.ellipsis : TextOverflow.visible,
                style: TextStyle(
                  fontSize: 11,
                  color: semanticColors(context).mutedText,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionSection(
    BuildContext context, {
    required bool isApproved,
    required bool isRejected,
    required VendorApplication? currentApp,
    required RenewalRequest? currentRenewal,
  }) {
    final dateTimeFormat = DateFormat("MMM dd, yyyy 'at' h:mm a");

    if (isApproved) {
      final date = currentApp?.reviewedAt ??
          currentRenewal?.submittedAt ??
          currentApp?.submittedAt ??
          DateTime.now();
      final dateStr = dateTimeFormat.format(date);
      final label = widget.renewal != null
          ? 'Approved on $dateStr'
          : 'Verified on $dateStr';
      final vendor = widget.renewal == null
          ? null
          : ref.watch(appDataProvider).vendors.cast<Vendor?>().firstWhere(
                (v) =>
                    v?.name.trim().toLowerCase() ==
                        widget.applicant.trim().toLowerCase() ||
                    v?.id ==
                        'VND-${widget.id.replaceAll(RegExp(r'[^0-9]'), '')}',
                orElse: () => null,
              );
      final targetVendorId =
          vendor?.id ?? 'VND-${widget.id.replaceAll(RegExp(r'[^0-9]'), '')}';

      final statusMessage = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: Color(0xFF059669),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF059669),
              ),
            ),
          ],
        ),
      );
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.renewal != null) ...[
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.go('/accounts?accountId=$targetVendorId&open=1');
              },
              icon: const Icon(Icons.person_outline_rounded, size: 16),
              label: const Text('View Account Profile'),
            ),
            const SizedBox(width: 10),
          ],
          OutlinedButton.icon(
            onPressed: processing ? null : _reopenForReview,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reopen for Review'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: semanticColors(context).subtleBorder),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      );
      return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 1100
            ? Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [statusMessage, actions],
              )
            : Row(
                children: [
                  Expanded(child: statusMessage),
                  const SizedBox(width: 16),
                  actions
                ],
              ),
      );
    }

    if (isRejected) {
      final date = currentApp?.reviewedAt ??
          currentRenewal?.submittedAt ??
          currentApp?.submittedAt ??
          DateTime.now();
      final dateStr = dateTimeFormat.format(date);
      final reason =
          currentApp?.rejectionReason ?? currentRenewal?.rejectionReason;
      final label = currentRenewal != null && (reason == null || reason.isEmpty)
          ? 'Expired on $dateStr'
          : 'Rejected on $dateStr';

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$label${reason != null && reason.isNotEmpty ? ' • Reason: $reason' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: processing ? null : _reopenForReview,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reopen for Review'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: semanticColors(context).subtleBorder),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: processing ? null : _moreDocs,
            icon: const Icon(Icons.document_scanner_outlined, size: 15),
            label: const Text('Request Additional Documents'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: semanticColors(context).subtleBorder),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          OutlinedButton.icon(
            onPressed: processing ? null : reject,
            icon: const Icon(Icons.close_rounded,
                size: 15, color: Color(0xFFEF4444)),
            label: const Text(
              'Reject',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.06),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
          FilledButton.icon(
            onPressed: processing ? null : approve,
            icon: processing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 16),
            label: const Text(
              'Approve',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documents(BuildContext context) {
    final rawDocs = widget.application?.documents ?? widget.renewal?.documents;
    final effectiveSubmittedAt = widget.renewal?.submittedAt ??
        widget.application?.submittedAt ??
        DateTime.now();
    final documents = (rawDocs != null && rawDocs.isNotEmpty)
        ? rawDocs
        : seedKycDocuments(effectiveSubmittedAt);

    final tiles = <Widget>[];
    for (int i = 0; i < documents.length; i++) {
      tiles.add(_docModel(context, documents[i], i, documents));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 16,
              color: semanticColors(context).secondaryText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Required Documents (${documents.length} of 5 Required Uploads)',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: semanticColors(context).primaryText,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 12,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${documents.length}/5 Completed',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width < 500
              ? 1
              : MediaQuery.sizeOf(context).width < 700
                  ? 2
                  : 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: MediaQuery.sizeOf(context).width < 500
              ? 1.75
              : MediaQuery.sizeOf(context).width < 700
                  ? 1.3
                  : 1.05,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: tiles,
        ),
      ],
    );
  }

  Widget _docModel(
    BuildContext context,
    KycDocument document,
    int index,
    List<KycDocument> allDocuments,
  ) {
    final ext = document.filename.split('.').last.toLowerCase();
    final isPdf = ext == 'pdf' || document.mimeType.contains('pdf');
    final isWord =
        ext == 'doc' || ext == 'docx' || document.mimeType.contains('word');

    return _doc(
      context,
      name: document.name,
      filename: document.filename,
      uploadedAt: document.uploadedAt,
      isPdf: isPdf,
      isWord: isWord,
      previewUrl: document.fileUrl,
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (context) => DocumentViewerModal(
            documents: allDocuments,
            initialIndex: index,
            applicantName: widget.applicant,
            stallName: widget.stall,
          ),
        );
      },
    );
  }

  Widget _doc(
    BuildContext context, {
    required String name,
    required String filename,
    required DateTime uploadedAt,
    required bool isPdf,
    required bool isWord,
    required String? previewUrl,
    required VoidCallback onTap,
  }) {
    final colors = semanticColors(context);

    final iconData = isPdf
        ? Icons.picture_as_pdf_rounded
        : isWord
            ? Icons.description_rounded
            : Icons.image_rounded;
    final iconColor = isPdf
        ? const Color(0xFFEF4444)
        : isWord
            ? const Color(0xFF2563EB)
            : const Color(0xFF10B981);
    final iconBg = iconColor.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.subtleBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: previewUrl != null &&
                        previewUrl.isNotEmpty &&
                        !isPdf &&
                        !isWord
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image(
                          image: NetworkImage(previewUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            iconData,
                            size: 16,
                            color: iconColor,
                          ),
                        ),
                      )
                    : Icon(iconData, size: 16, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: colors.mutedText,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Uploaded on ${shortDate.format(uploadedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    color: colors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.visibility_outlined, size: 13),
            label: const Text('View Document'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(28),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              side: BorderSide(color: colors.subtleBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(
    BuildContext context, [
    VendorApplication? currentApp,
    RenewalRequest? currentRenewal,
  ]) {
    final colors = semanticColors(context);
    final app = currentApp ?? widget.application;
    final renewal = currentRenewal ?? widget.renewal;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.subtleBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'APPLICANT SUMMARY',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colors.secondaryText,
                ),
              ),
              const SizedBox(height: 14),
              _summaryField(
                context,
                icon: Icons.storefront_outlined,
                label: 'BUSINESS NAME',
                value: widget.stall,
              ),
              _summaryCategoryField(
                context,
                icon: Icons.category_outlined,
                label: 'STALL CATEGORY',
                category: widget.category,
              ),
              _summaryField(
                context,
                icon: Icons.phone_outlined,
                label: 'CONTACT NUMBER',
                value: () {
                  final latestVendors = ref.watch(appDataProvider).vendors;
                  final vendor = latestVendors.cast<Vendor?>().firstWhere(
                        (v) =>
                            v?.id ==
                                'VND-${widget.id.replaceAll(RegExp(r'[^0-9]'), '')}' ||
                            v?.name.trim().toLowerCase() ==
                                widget.applicant.trim().toLowerCase(),
                        orElse: () => null,
                      );
                  if (vendor != null && vendor.phone.isNotEmpty) {
                    return vendor.phone;
                  }
                  final idNum = int.tryParse(
                    widget.id.replaceAll(RegExp(r'[^0-9]'), ''),
                  );
                  if (idNum != null && idNum >= 92834 && idNum < 92834 + 25) {
                    return '+63 921 555 ${1000 + (idNum - 92834)}';
                  }
                  return '+63 921 555 0123';
                }(),
              ),
              _summaryField(
                context,
                icon: Icons.email_outlined,
                label: 'EMAIL ADDRESS',
                value: () {
                  final latestVendors = ref.watch(appDataProvider).vendors;
                  final vendor = latestVendors.cast<Vendor?>().firstWhere(
                        (v) =>
                            v?.id ==
                                'VND-${widget.id.replaceAll(RegExp(r'[^0-9]'), '')}' ||
                            v?.name.trim().toLowerCase() ==
                                widget.applicant.trim().toLowerCase(),
                        orElse: () => null,
                      );
                  if (vendor != null && vendor.email.isNotEmpty) {
                    return vendor.email;
                  }
                  return '${widget.applicant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '.')}@gmail.com';
                }(),
              ),
              if (renewal != null) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () {
                    final targetId =
                        'VND-${widget.id.replaceAll(RegExp(r'[^0-9]'), '')}';
                    Navigator.pop(context);
                    context.go('/accounts?accountId=$targetId&open=1');
                  },
                  icon: const Icon(Icons.person_outline_rounded, size: 15),
                  label: const Text('View Account Profile'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (renewal != null) ...[
          const SizedBox(height: 14),
          _buildRenewalHistoryCard(context),
        ],
        if (app?.rejectionReason != null &&
            app!.rejectionReason!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.dangerContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            child: _item(
              app.status == ApplicationStatus.invalidDocs
                  ? 'REQUIRED DOCUMENTS / NOTES'
                  : 'REJECTION REASON',
              app.rejectionReason!,
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryField(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colors = semanticColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: colors.mutedText),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: colors.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCategoryField(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String category,
  }) {
    final colors = semanticColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: colors.mutedText),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: colors.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          CategoryBadge(category: category),
        ],
      ),
    );
  }

  Widget _buildRenewalHistoryCard(BuildContext context) {
    final colors = semanticColors(context);
    final renewal = widget.renewal!;
    final allRenewals = ref.watch(appDataProvider.select((s) => s.renewals));
    final matchingRenewals = allRenewals
        .where((r) =>
            (r.applicant.toLowerCase() == widget.applicant.toLowerCase() ||
                r.stallName.toLowerCase() == widget.stall.toLowerCase()) &&
            r.id != widget.id)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.subtleBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 13,
                    color: colors.secondaryText,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'RENEWAL HISTORY',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: colors.secondaryText,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Good Standing',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _showAllRenewalHistoryModal(
                      context,
                      renewal: renewal,
                      matchingRenewals: matchingRenewals,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View All',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: colors.accent,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 12,
                            color: colors.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _historyItem(
            context,
            cycle: '${renewal.expiryDate.year} Renewal (Current)',
            dateStr: renewal.submittedAt != null
                ? 'Submitted ${shortDate.format(renewal.submittedAt!)}'
                : 'Submitted recently',
            statusLabel: enumLabel(renewal.status),
            statusKind: renewal.status == RenewalStatus.approved
                ? BadgeKind.success
                : renewal.status == RenewalStatus.expired
                    ? BadgeKind.danger
                    : BadgeKind.warning,
            isCurrent: true,
            onTap: () => _showCycleDetailDialog(
              context,
              cycle: '${renewal.expiryDate.year} Renewal (Current)',
              dateStr: renewal.submittedAt != null
                  ? 'Submitted ${shortDate.format(renewal.submittedAt!)}'
                  : 'Submitted recently',
              statusLabel: enumLabel(renewal.status),
              statusKind: renewal.status == RenewalStatus.approved
                  ? BadgeKind.success
                  : renewal.status == RenewalStatus.expired
                      ? BadgeKind.danger
                      : BadgeKind.warning,
              docs: renewal.documents.isNotEmpty
                  ? renewal.documents
                  : seedKycDocuments(renewal.submittedAt ?? DateTime.now()),
            ),
          ),
          if (matchingRenewals.isNotEmpty)
            for (int i = 0; i < matchingRenewals.length; i++)
              _historyItem(
                context,
                cycle: '${matchingRenewals[i].expiryDate.year} Annual License',
                dateStr: matchingRenewals[i].submittedAt != null
                    ? 'Submitted ${shortDate.format(matchingRenewals[i].submittedAt!)}'
                    : 'Valid until ${shortDate.format(matchingRenewals[i].expiryDate)}',
                statusLabel: enumLabel(matchingRenewals[i].status),
                statusKind: matchingRenewals[i].status == RenewalStatus.approved
                    ? BadgeKind.success
                    : matchingRenewals[i].status == RenewalStatus.expired
                        ? BadgeKind.danger
                        : BadgeKind.neutral,
                isCurrent: false,
                isLast: i == matchingRenewals.length - 1,
                onTap: () => _showCycleDetailDialog(
                  context,
                  cycle:
                      '${matchingRenewals[i].expiryDate.year} Annual License',
                  dateStr: matchingRenewals[i].submittedAt != null
                      ? 'Submitted ${shortDate.format(matchingRenewals[i].submittedAt!)}'
                      : 'Valid until ${shortDate.format(matchingRenewals[i].expiryDate)}',
                  statusLabel: enumLabel(matchingRenewals[i].status),
                  statusKind:
                      matchingRenewals[i].status == RenewalStatus.approved
                          ? BadgeKind.success
                          : matchingRenewals[i].status == RenewalStatus.expired
                              ? BadgeKind.danger
                              : BadgeKind.neutral,
                  docs: matchingRenewals[i].documents.isNotEmpty
                      ? matchingRenewals[i].documents
                      : seedKycDocuments(matchingRenewals[i].submittedAt ??
                          matchingRenewals[i].expiryDate),
                ),
              )
          else ...[
            _historyItem(
              context,
              cycle: '${renewal.expiryDate.year - 1} Annual License',
              dateStr: 'Approved on Oct 14, ${renewal.expiryDate.year - 1}',
              statusLabel: 'Approved',
              statusKind: BadgeKind.success,
              isCurrent: false,
              onTap: () => _showCycleDetailDialog(
                context,
                cycle: '${renewal.expiryDate.year - 1} Annual License',
                dateStr: 'Approved on Oct 14, ${renewal.expiryDate.year - 1}',
                statusLabel: 'Approved',
                statusKind: BadgeKind.success,
                docs: seedKycDocuments(
                    DateTime(renewal.expiryDate.year - 1, 10, 14)),
              ),
            ),
            _historyItem(
              context,
              cycle: '${renewal.expiryDate.year - 2} Annual License',
              dateStr: 'Approved on Oct 08, ${renewal.expiryDate.year - 2}',
              statusLabel: 'Approved',
              statusKind: BadgeKind.success,
              isCurrent: false,
              onTap: () => _showCycleDetailDialog(
                context,
                cycle: '${renewal.expiryDate.year - 2} Annual License',
                dateStr: 'Approved on Oct 08, ${renewal.expiryDate.year - 2}',
                statusLabel: 'Approved',
                statusKind: BadgeKind.success,
                docs: seedKycDocuments(
                    DateTime(renewal.expiryDate.year - 2, 10, 8)),
              ),
            ),
            _historyItem(
              context,
              cycle: 'Initial Stall Grant',
              dateStr: 'Verified on Oct 12, 2023',
              statusLabel: 'Verified',
              statusKind: BadgeKind.neutral,
              isCurrent: false,
              isLast: true,
              onTap: () => _showCycleDetailDialog(
                context,
                cycle: 'Initial Stall Grant',
                dateStr: 'Verified on Oct 12, 2023',
                statusLabel: 'Verified',
                statusKind: BadgeKind.neutral,
                docs: seedKycDocuments(DateTime(2023, 10, 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyItem(
    BuildContext context, {
    required String cycle,
    required String dateStr,
    required String statusLabel,
    required BadgeKind statusKind,
    required bool isCurrent,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    final colors = semanticColors(context);
    final dotColor = isCurrent
        ? const Color(0xFF3B82F6)
        : statusKind == BadgeKind.success
            ? const Color(0xFF10B981)
            : colors.mutedText;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 26,
                color: colors.subtleBorder,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        cycle,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight:
                              isCurrent ? FontWeight.w800 : FontWeight.w600,
                          color: colors.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    StatusBadge(label: statusLabel, kind: statusKind),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          color: colors.mutedText,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      Text(
                        'View Docs >',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: content,
        ),
      );
    }
    return content;
  }

  void _showCycleDetailDialog(
    BuildContext context, {
    required String cycle,
    required String dateStr,
    required String statusLabel,
    required BadgeKind statusKind,
    required List<KycDocument> docs,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final colors = semanticColors(ctx);
        final narrow = MediaQuery.sizeOf(ctx).width < 600;

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: EdgeInsets.all(narrow ? 16 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  cycle,
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: colors.primaryText,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                    label: statusLabel, kind: statusKind),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.applicant} • ${widget.stall} • $dateStr',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 14),
                  Text(
                    'Archived Cycle Documents (${docs.length} Uploads)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: SingleChildScrollView(
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: narrow ? 1 : 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.4,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, idx) {
                          final doc = docs[idx];
                          final isPdf =
                              doc.filename.toLowerCase().endsWith('.pdf');
                          final isWord =
                              doc.filename.toLowerCase().endsWith('.docx') ||
                                  doc.filename.toLowerCase().endsWith('.doc');

                          return InkWell(
                            onTap: () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => DocumentViewerModal(
                                  documents: docs,
                                  initialIndex: idx,
                                  applicantName: widget.applicant,
                                  stallName: widget.stall,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.inputSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.subtleBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isPdf
                                          ? const Color(0xFFEF4444)
                                              .withValues(alpha: 0.12)
                                          : isWord
                                              ? const Color(0xFF3B82F6)
                                                  .withValues(alpha: 0.12)
                                              : const Color(0xFF10B981)
                                                  .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isPdf
                                          ? Icons.picture_as_pdf_rounded
                                          : isWord
                                              ? Icons.description_rounded
                                              : Icons.image_rounded,
                                      size: 18,
                                      color: isPdf
                                          ? const Color(0xFFEF4444)
                                          : isWord
                                              ? const Color(0xFF3B82F6)
                                              : const Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          doc.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: colors.primaryText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          doc.filename,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            color: colors.mutedText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                    color: colors.mutedText,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAllRenewalHistoryModal(
    BuildContext context, {
    required RenewalRequest renewal,
    required List<RenewalRequest> matchingRenewals,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final colors = semanticColors(ctx);
        final narrow = MediaQuery.sizeOf(ctx).width < 640;

        final records = <Map<String, dynamic>>[
          {
            'cycle': '${renewal.expiryDate.year} Renewal (Current)',
            'dateStr': renewal.submittedAt != null
                ? 'Submitted ${shortDate.format(renewal.submittedAt!)}'
                : 'Submitted recently',
            'statusLabel': enumLabel(renewal.status),
            'statusKind': renewal.status == RenewalStatus.approved
                ? BadgeKind.success
                : renewal.status == RenewalStatus.expired
                    ? BadgeKind.danger
                    : BadgeKind.warning,
            'isCurrent': true,
            'docs': renewal.documents.isNotEmpty
                ? renewal.documents
                : seedKycDocuments(renewal.submittedAt ?? DateTime.now()),
          },
          if (matchingRenewals.isNotEmpty)
            for (final r in matchingRenewals)
              {
                'cycle': '${r.expiryDate.year} Annual License',
                'dateStr': r.submittedAt != null
                    ? 'Submitted ${shortDate.format(r.submittedAt!)}'
                    : 'Valid until ${shortDate.format(r.expiryDate)}',
                'statusLabel': enumLabel(r.status),
                'statusKind': r.status == RenewalStatus.approved
                    ? BadgeKind.success
                    : r.status == RenewalStatus.expired
                        ? BadgeKind.danger
                        : BadgeKind.neutral,
                'isCurrent': false,
                'docs': r.documents.isNotEmpty
                    ? r.documents
                    : seedKycDocuments(r.submittedAt ?? r.expiryDate),
              }
          else ...[
            {
              'cycle': '${renewal.expiryDate.year - 1} Annual License',
              'dateStr': 'Approved on Oct 14, ${renewal.expiryDate.year - 1}',
              'statusLabel': 'Approved',
              'statusKind': BadgeKind.success,
              'isCurrent': false,
              'docs': seedKycDocuments(
                  DateTime(renewal.expiryDate.year - 1, 10, 14)),
            },
            {
              'cycle': '${renewal.expiryDate.year - 2} Annual License',
              'dateStr': 'Approved on Oct 08, ${renewal.expiryDate.year - 2}',
              'statusLabel': 'Approved',
              'statusKind': BadgeKind.success,
              'isCurrent': false,
              'docs': seedKycDocuments(
                  DateTime(renewal.expiryDate.year - 2, 10, 8)),
            },
            {
              'cycle': 'Initial Stall Grant',
              'dateStr': 'Verified on Oct 12, 2023',
              'statusLabel': 'Verified',
              'statusKind': BadgeKind.neutral,
              'isCurrent': false,
              'docs': seedKycDocuments(DateTime(2023, 10, 12)),
            },
          ],
        ];

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
            child: Padding(
              padding: EdgeInsets.all(narrow ? 16 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history_rounded,
                              size: 20, color: colors.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Complete Renewal History',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colors.primaryText,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All historical cycles, licenses, and inspection records for ${widget.applicant} (${widget.stall}).',
                    style: TextStyle(fontSize: 12, color: colors.mutedText),
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final rec = records[idx];
                        final List<KycDocument> docs =
                            rec['docs'] as List<KycDocument>;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.inputSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: rec['isCurrent'] == true
                                  ? const Color(0xFF3B82F6)
                                      .withValues(alpha: 0.5)
                                  : colors.subtleBorder,
                              width: rec['isCurrent'] == true ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: rec['isCurrent'] == true
                                      ? const Color(0xFF3B82F6)
                                          .withValues(alpha: 0.12)
                                      : colors.cardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  rec['isCurrent'] == true
                                      ? Icons.update_rounded
                                      : Icons.verified_outlined,
                                  size: 18,
                                  color: rec['isCurrent'] == true
                                      ? const Color(0xFF3B82F6)
                                      : colors.secondaryText,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          rec['cycle'] as String,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: colors.primaryText,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        StatusBadge(
                                          label: rec['statusLabel'] as String,
                                          kind: rec['statusKind'] as BadgeKind,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${rec['dateStr']} • ${docs.length} uploaded document(s)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  _showCycleDetailDialog(
                                    context,
                                    cycle: rec['cycle'] as String,
                                    dateStr: rec['dateStr'] as String,
                                    statusLabel: rec['statusLabel'] as String,
                                    statusKind: rec['statusKind'] as BadgeKind,
                                    docs: docs,
                                  );
                                },
                                icon: const Icon(Icons.folder_open_rounded,
                                    size: 14),
                                label: const Text('View Documents',
                                    style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _item(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8.5)),
            const SizedBox(height: 3),
            Text(
              value,
              style:
                  const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );

  Future<void> _moreDocs() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => const _PromptInputDialogWidget(
        title: 'Request Additional Documents',
        hintText:
            'e.g. Please upload a clear Mayor\'s Permit and valid Sanitary Clearance...',
        confirmLabel: 'Send Request',
        minLines: 2,
        maxLines: 4,
        defaultOnEmpty: 'Additional documents required',
      ),
    );
    if (value == null || !mounted) return;
    setState(() => processing = true);
    if (widget.application != null) {
      await ref.read(appDataProvider.notifier).updateApplication(
            widget.id,
            ApplicationStatus.invalidDocs,
            rejectionReason: value,
          );
      ref.read(notificationProvider.notifier).addNotification(
            title: 'Additional Documents Requested',
            message:
                'Requested document update from ${widget.applicant}: "$value"',
            type: NotificationType.vendorApplication,
            target: NotificationTarget(
              type: NotificationTargetType.application,
              id: widget.id,
            ),
            actionLabel: 'View Status',
          );
    }
    if (widget.renewal != null) {
      await ref
          .read(appDataProvider.notifier)
          .updateRenewal(widget.id, RenewalStatus.reviewing);
      ref.read(notificationProvider.notifier).addNotification(
            title: 'Additional Documents Requested',
            message:
                'Requested document update from ${widget.applicant}: "$value"',
            type: NotificationType.renewal,
            target: NotificationTarget(
              type: NotificationTargetType.renewal,
              id: widget.id,
            ),
            actionLabel: 'View Status',
          );
    }
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Additional documents requested from ${widget.applicant}.',
          ),
        ),
      );
    }
  }
}

class _PromptInputDialogWidget extends StatefulWidget {
  const _PromptInputDialogWidget({
    required this.title,
    this.hintText,
    required this.confirmLabel,
    this.maxLines = 1,
    this.minLines = 1,
    this.defaultOnEmpty = '',
    this.isRequired = false,
  });

  final String title;
  final String? hintText;
  final String confirmLabel;
  final int maxLines;
  final int minLines;
  final String defaultOnEmpty;
  final bool isRequired;

  @override
  State<_PromptInputDialogWidget> createState() =>
      _PromptInputDialogWidgetState();
}

class _PromptInputDialogWidgetState extends State<_PromptInputDialogWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    if (widget.isRequired) {
      _controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    if (widget.isRequired) {
      _controller.removeListener(_onTextChanged);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !widget.isRequired || _controller.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hintText,
          errorText: widget.isRequired && _controller.text.trim().isEmpty
              ? 'Reason is required'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSubmit
              ? () {
                  final text = _controller.text.trim();
                  if (text.isEmpty && widget.defaultOnEmpty.isNotEmpty) {
                    Navigator.pop(context, widget.defaultOnEmpty);
                  } else {
                    Navigator.pop(context, text);
                  }
                }
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
