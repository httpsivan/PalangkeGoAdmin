import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_extensions.dart';
import '../utils/formatters.dart';
import '../widgets/admin_widgets.dart';
import '../../models/app_models.dart';

class DocumentViewerModal extends StatefulWidget {
  const DocumentViewerModal({
    super.key,
    required this.documents,
    this.initialIndex = 0,
    required this.applicantName,
    required this.stallName,
  });

  final List<KycDocument> documents;
  final int initialIndex;
  final String applicantName;
  final String stallName;

  @override
  State<DocumentViewerModal> createState() => _DocumentViewerModalState();
}

class _DocumentViewerModalState extends State<DocumentViewerModal> {
  late int currentIndex;
  final TransformationController _transformationController =
      TransformationController();
  double _currentScale = 1.0;
  int _pdfCurrentPage = 1;
  String _idSide = 'front';

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex.clamp(0, widget.documents.length - 1);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    setState(() {
      _currentScale = 1.0;
      _transformationController.value = Matrix4.identity();
    });
  }

  void _zoomIn() {
    setState(() {
      _currentScale = (_currentScale + 0.25).clamp(1.0, 3.5);
      _transformationController.value =
          Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentScale = (_currentScale - 0.25).clamp(1.0, 3.5);
      _transformationController.value =
          Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.documents.length) return;
    setState(() {
      currentIndex = index;
      _pdfCurrentPage = 1;
      _idSide = 'front';
      _resetZoom();
    });
  }

  String _getFileTypeLabel(KycDocument doc) {
    final ext = doc.filename.split('.').last.toLowerCase();
    final mime = doc.mimeType.toLowerCase();
    final size = doc.fileSizeFormatted ?? '245 KB';
    if (ext == 'pdf' || mime.contains('pdf')) return 'PDF Document • $size';
    if (ext == 'docx' || ext == 'doc' || mime.contains('word')) {
      return 'Word Document • $size';
    }
    if (ext == 'png' || mime.contains('png')) return 'PNG Image • $size';
    if (ext == 'jpg' || ext == 'jpeg' || mime.contains('jpeg')) {
      return 'JPG Image • $size';
    }
    return '${ext.toUpperCase()} File • $size';
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.documents[currentIndex];
    final colors = semanticColors(context);
    final ext = doc.filename.split('.').last.toLowerCase();
    final isImage = ext == 'png' ||
        ext == 'jpg' ||
        ext == 'jpeg' ||
        doc.mimeType.startsWith('image/');
    final isPdf = ext == 'pdf' || doc.mimeType == 'application/pdf';
    final isWord =
        ext == 'doc' || ext == 'docx' || doc.mimeType.contains('word');

    return Dialog(
      backgroundColor: colors.cardBackground,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 760),
        child: Column(
          children: [
            // HEADER BAR
            _buildHeader(context, doc, colors),
            const Divider(height: 1),

            // DOCUMENT CONTENT PREVIEW AREA
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      child: _buildDocumentBody(
                          context, doc, isImage, isPdf, isWord),
                    ),
                  ),

                  // Floating Zoom Controls for Images
                  if (isImage && doc.assetPath != null)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.zoom_out_rounded,
                                  color: Colors.white, size: 18),
                              onPressed: _zoomOut,
                              tooltip: 'Zoom Out',
                            ),
                            Text(
                              '${(_currentScale * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.zoom_in_rounded,
                                  color: Colors.white, size: 18),
                              onPressed: _zoomIn,
                              tooltip: 'Zoom In',
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: _resetZoom,
                              child: const Text(
                                'Reset',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // FOOTER BAR WITH NAVIGATION & ACTIONS
            const Divider(height: 1),
            _buildFooter(context, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, KycDocument doc, AppSemanticColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              doc.filename.endsWith('.pdf')
                  ? Icons.picture_as_pdf_rounded
                  : doc.filename.contains('doc')
                      ? Icons.description_rounded
                      : Icons.image_rounded,
              color: colors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      doc.hasBackSide ||
                              doc.name.toLowerCase().contains('government id')
                          ? '${doc.name} (${_idSide == 'front' ? 'Front Side' : 'Back Side'})'
                          : doc.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.subtleBorder.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Document ${currentIndex + 1} of ${widget.documents.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.secondaryText,
                        ),
                      ),
                    ),
                    if (doc.hasBackSide ||
                        doc.name.toLowerCase().contains('government id')) ...[
                      const SizedBox(width: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.subtleBorder.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  colors.subtleBorder.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _idSide = 'front'),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _idSide == 'front'
                                      ? colors.accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.badge_rounded,
                                      size: 13,
                                      color: _idSide == 'front'
                                          ? Colors.white
                                          : colors.secondaryText,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Front',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _idSide == 'front'
                                            ? Colors.white
                                            : colors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _idSide = 'back'),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _idSide == 'back'
                                      ? colors.accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.flip_to_back_rounded,
                                      size: 13,
                                      color: _idSide == 'back'
                                          ? Colors.white
                                          : colors.secondaryText,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Back',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _idSide == 'back'
                                            ? Colors.white
                                            : colors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${doc.filename}  •  Uploaded ${shortDate.format(doc.uploadedAt)}  •  ${_getFileTypeLabel(doc)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close Viewer',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AppSemanticColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(
            'Applicant: ${widget.applicantName} (${widget.stallName})',
            style: TextStyle(
              fontSize: 12,
              color: colors.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: currentIndex > 0 ? () => _goTo(currentIndex - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            label: const Text('Previous'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: currentIndex < widget.documents.length - 1
                ? () => _goTo(currentIndex + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentBody(
    BuildContext context,
    KycDocument doc,
    bool isImage,
    bool isPdf,
    bool isWord,
  ) {
    if (isImage) {
      return _buildImageViewer(context, doc);
    }

    if (isPdf) {
      return _buildPdfViewer(context, doc);
    }

    if (isWord) {
      return _buildWordViewer(context, doc);
    }

    return _buildFallbackView(context, doc);
  }

  Widget _buildImageViewer(BuildContext context, KycDocument doc) {
    final isGovId =
        doc.hasBackSide || doc.name.toLowerCase().contains('government id');

    if (isGovId && _idSide == 'back') {
      final hasBack = doc.isBackSubmitted &&
          (doc.idBackAssetPath != null || doc.idBackUrl != null);
      if (!hasBack) {
        return _buildMissingBackSidePlaceholder(context, doc);
      }
    }

    final targetAsset = (isGovId && _idSide == 'back')
        ? (doc.idBackAssetPath ?? doc.assetPath)
        : (doc.idFrontAssetPath ?? doc.assetPath);

    if (targetAsset != null) {
      return InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.8,
        maxScale: 4.0,
        child: Center(
          child: Image.asset(
            targetAsset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                _buildGovernmentIdCardImage(doc, isFront: _idSide == 'front'),
          ),
        ),
      );
    }

    final targetUrl = (isGovId && _idSide == 'back')
        ? (doc.idBackUrl ?? doc.fileUrl)
        : (doc.idFrontUrl ?? doc.fileUrl);
    if (targetUrl != null && targetUrl.isNotEmpty) {
      return InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.8,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            targetUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildImageLoadError(context),
          ),
        ),
      );
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.8,
      maxScale: 4.0,
      child: Center(
        child: _buildGovernmentIdCardImage(doc, isFront: _idSide == 'front'),
      ),
    );
  }

  Widget _buildImageLoadError(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, size: 48),
            const SizedBox(height: 8),
            Text('Could not load document image',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );

  Widget _buildMissingBackSidePlaceholder(
      BuildContext context, KycDocument doc) {
    final colors = semanticColors(context);
    return Center(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.subtleBorder, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flip_to_back_rounded,
                size: 48,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Back Side Not Yet Submitted',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The applicant submitted the Front Side of their ${doc.name}, but the Back Side is missing or pending re-upload.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: colors.secondaryText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.subtleBorder.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Text(
                    'Use "Request Additional Documents" below to notify vendor.',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGovernmentIdCardImage(KycDocument doc, {bool isFront = true}) {
    return Container(
      width: 520,
      height: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
      ),
      child: isFront
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.badge_rounded,
                            color: Color(0xFF38BDF8), size: 28),
                        SizedBox(width: 10),
                        Text(
                          'REPUBLIC OF THE PHILIPPINES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PHILSYS ID • FRONT',
                        style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 100,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded,
                            size: 64, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.applicantName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID NO: PHIL-${(widget.applicantName.hashCode.abs() % 899999 + 100000)}',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('NATIONAL IDENTITY CARD (FRONT CAPTURE)',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10)),
                          const SizedBox(height: 2),
                          const Text('ISSUED: JAN 05, 2022  •  EXPIRY: NEVER',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 9.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('OFFICIAL IDENTIFICATION FRONT CAPTURE',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                    Icon(Icons.verified_user_rounded,
                        color: Color(0xFF22C55E), size: 20),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.flip_to_back_rounded,
                            color: Color(0xFF38BDF8), size: 24),
                        SizedBox(width: 10),
                        Text(
                          'PHILIPPINE IDENTIFICATION SYSTEM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PHILSYS ID • BACK',
                        style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white24),
                const SizedBox(height: 16),
                const Text('PERMANENT RESIDENCE ADDRESS:',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                    'Penafrancia Avenue, Barangay Dayangdang, Naga City, Camarines Sur, 4400',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('EMERGENCY CONTACT:',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('+63 917 555 0192',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Container(
                      width: 100,
                      height: 40,
                      color: Colors.white12,
                      child: const Center(
                        child: Icon(Icons.qr_code_2_rounded,
                            color: Colors.white70, size: 32),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('OFFICIAL IDENTIFICATION BACK CAPTURE',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                    Icon(Icons.shield_outlined,
                        color: Color(0xFF38BDF8), size: 18),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildPdfViewer(BuildContext context, KycDocument doc) {
    final isMayorsPermit = doc.name.toLowerCase().contains('mayor') ||
        doc.filename.toLowerCase().contains('mayor');
    final isSanitary = doc.name.toLowerCase().contains('sanitary') ||
        doc.filename.toLowerCase().contains('sanitary');
    final isMarketClearance = doc.name.toLowerCase().contains('market') ||
        doc.filename.toLowerCase().contains('clearance');

    final totalPages =
        (isMayorsPermit || isSanitary || isMarketClearance) ? 1 : 2;

    return Column(
      children: [
        // Real PDF Viewer Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1E293B),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded,
                  color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 10),
              Text(
                doc.filename,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PDF VIEW',
                  style: TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              // Page controls
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded,
                        color: Colors.white, size: 20),
                    onPressed: _pdfCurrentPage > 1
                        ? () => setState(() => _pdfCurrentPage--)
                        : null,
                    tooltip: 'Previous Page',
                  ),
                  Text(
                    'Page $_pdfCurrentPage of $totalPages',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 20),
                    onPressed: _pdfCurrentPage < totalPages
                        ? () => setState(() => _pdfCurrentPage++)
                        : null,
                    tooltip: 'Next Page',
                  ),
                ],
              ),
              const VerticalDivider(
                  color: Colors.white24, indent: 6, endIndent: 6),
              // Zoom controls
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        color: Colors.white, size: 18),
                    onPressed: _zoomOut,
                    tooltip: 'Zoom Out',
                  ),
                  Text(
                    '${(_currentScale * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: Colors.white, size: 18),
                    onPressed: _zoomIn,
                    tooltip: 'Zoom In',
                  ),
                  TextButton(
                    onPressed: _resetZoom,
                    child: const Text(
                      'Reset',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // PDF Workspace Canvas
        Expanded(
          child: Container(
            color: const Color(0xFF404040),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.8,
                  maxScale: 3.5,
                  child: Container(
                    width: 680,
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: isMayorsPermit
                        ? _buildMayorsPermitPdf()
                        : isSanitary
                            ? _buildSanitaryPermitPdf()
                            : isMarketClearance
                                ? _buildMarketClearancePdf()
                                : (_pdfCurrentPage == 1
                                    ? _buildPdfPage1()
                                    : _buildPdfPage2()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMayorsPermitPdf() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Official Header Seal
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0F172A),
              ),
              child: const Icon(Icons.account_balance_rounded,
                  color: Color(0xFFF59E0B), size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'REPUBLIC OF THE PHILIPPINES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'CITY GOVERNMENT OF NAGA',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'OFFICE OF THE CITY MAYOR  •  BUSINESS PERMITS & LICENSING DIVISION',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(height: 3, color: const Color(0xFF1E3A8A)),
        const SizedBox(height: 4),
        Container(height: 1, color: const Color(0xFFF59E0B)),
        const SizedBox(height: 24),

        // Certificate Title
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'BUSINESS & MAYOR\'S PERMIT',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PERMIT NO: NP-2026-${(widget.applicantName.hashCode.abs() % 89999 + 10000)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const Text(
              'TAX YEAR: 2026',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'THIS IS TO CERTIFY that pursuant to the provisions of the Naga City Revenue Code and existing local ordinances, permission is hereby granted to:',
            style: TextStyle(fontSize: 12, height: 1.5, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 20),

        // Details Container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              _permitDetailRow(
                  'BUSINESS STALL NAME', widget.stallName.toUpperCase()),
              const Divider(height: 16),
              _permitDetailRow(
                  'PERMITTEE / OWNER', widget.applicantName.toUpperCase()),
              const Divider(height: 16),
              _permitDetailRow('STALL LOCATION',
                  'NAGA CITY PEOPLE\'S MALL, ${widget.stallName} Area'),
              const Divider(height: 16),
              _permitDetailRow('DATE ISSUED', 'JANUARY 12, 2026'),
              const Divider(height: 16),
              _permitDetailRow('VALID UNTIL', 'DECEMBER 31, 2026'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Compliance checks
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            border: Border.all(color: const Color(0xFF86EFAC)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _checkBadge('Municipal Tax: PAID'),
              _checkBadge('Sanitary Pass: OK'),
              _checkBadge('Fire Inspection: CERTIFIED'),
              _checkBadge('Market Clearance: APPROVED'),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // Signatures
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 40,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.qr_code_2_rounded,
                        size: 36, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'VERIFICATION QR / BARCODE',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Column(
              children: [
                const Text(
                  'HON. NELSON S. LEGACION',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Text(
                  'City Mayor, Naga City',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Container(width: 180, height: 1, color: Colors.black45),
                const SizedBox(height: 2),
                const Text(
                  'APPROVED BY AUTHORITY OF THE MAYOR',
                  style: TextStyle(
                      fontSize: 8.5,
                      color: Colors.black45,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSanitaryPermitPdf() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'REPUBLIC OF THE PHILIPPINES',
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        const Text(
          'CITY HEALTH OFFICE — NAGA CITY',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF065F46)),
        ),
        const Text(
          'Sanitation & Food Safety Inspection Division',
          style: TextStyle(fontSize: 10, color: Colors.black54),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF065F46),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'SANITARY PERMIT TO OPERATE',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Permit No: CHO-SP-2026-${(widget.applicantName.hashCode.abs() % 8999 + 1000)}',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46)),
        ),
        const SizedBox(height: 20),
        Text(
          'Issued to ${widget.applicantName.toUpperCase()} for operating ${widget.stallName.toUpperCase()} located at Naga City People\'s Mall.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, height: 1.5),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            border: Border.all(color: const Color(0xFFA7F3D0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: const [
              Text(
                'SANITATION RATING: CLASS A (EXCELLENT)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF047857)),
              ),
              SizedBox(height: 6),
              Text(
                'Full compliance with Presidential Decree No. 856 (Code on Sanitation of the Philippines). Inspection passed with 100% score.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Date Issued: Jan 10, 2026',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Column(
              children: const [
                Text('DR. VITO C. BORROMEO',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('City Health Officer',
                    style: TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMarketClearancePdf() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('CITY GOVERNMENT OF NAGA',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        const Text(
          'OFFICE OF THE MARKET MASTER',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B)),
        ),
        const Text('Naga City People\'s Mall Administration',
            style: TextStyle(fontSize: 10, color: Colors.black54)),
        const SizedBox(height: 20),
        Container(height: 2, color: const Color(0xFF1E293B)),
        const SizedBox(height: 20),
        const Text(
          'STALL HOLDER MARKET CLEARANCE',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 16),
        Text(
          'This certifies that ${widget.applicantName.toUpperCase()} operating ${widget.stallName.toUpperCase()} has settled all market rental fees, utility obligations, and possesses zero outstanding market administrative violations.',
          style: const TextStyle(fontSize: 12.5, height: 1.5),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _permitDetailRow('CLEARANCE STATUS', 'ACTIVE / IN GOOD STANDING'),
              const SizedBox(height: 8),
              _permitDetailRow('RENTAL OBLIGATIONS', 'PAID UP TO DATE'),
              const SizedBox(height: 8),
              _permitDetailRow('MARKET RULES COMPLIANCE', '100% COMPLIANT'),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            children: const [
              Text('RAMON J. FLORENDO',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('Market Enterprise & Promotions Officer',
                  style: TextStyle(fontSize: 10, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _permitDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Colors.black54)),
        Text(value,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Colors.black87)),
      ],
    );
  }

  static Widget _checkBadge(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded,
            color: Color(0xFF16A34A), size: 14),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF15803D))),
      ],
    );
  }

  Widget _buildPdfPage1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: const Color(0xFFFFCC00),
              child: const Text(
                'STI',
                style: TextStyle(
                  color: Color(0xFF003399),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Text(
              'OFFICIAL CAPSTONE REQUEST',
              style: TextStyle(
                fontSize: 10,
                color: Colors.black54,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Text('February 25, 2026',
            style: TextStyle(color: Colors.black87, fontSize: 13)),
        const SizedBox(height: 16),
        const Text(
          'RAMON J. FLORENDO\nMarket Enterprise and Promotions Officer\nNaga City People\'s Mall\nGeneral Luna St., Naga City, Philippines, 4400',
          style: TextStyle(
              color: Colors.black87,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        const Text('Dear Mr. Florendo,\n\nGreetings!',
            style: TextStyle(color: Colors.black87, fontSize: 13)),
        const SizedBox(height: 14),
        const Text(
          'We are third-year Bachelor of Science in Information Technology students from STI College Naga, currently undertaking our capstone project titled "PalengkeGo: A Mobile Application for Wet Market Shopping at Naga City People\'s Mall". This project is a requirement for the completion of our Bachelor of Science in Information Technology degree at STI College Naga.\n\n'
          'PalengkeGo is a mobile application designed to address the time inefficiency experienced by consumers in local markets. Through the application, customers can browse available products from registered vendors, covering fruits, vegetables, fish, and meat, and place pre-orders directly from their smartphones. Customers may then choose to pick up their order at the vendor\'s stall or have it delivered.\n\n'
          'In this regard, we would like to formally request the Naga City People\'s Mall to be the official client of our capstone project. As our client, the Naga City People\'s Mall will serve as the primary basis and beneficiary of the system we are developing.',
          style: TextStyle(color: Colors.black87, fontSize: 12.5, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildPdfPage2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'developed will not be used for any commercial purpose without the express consent of the Naga City People\'s Mall and STI College Naga.\n\n'
          'We are hopeful that you will consider our request favorably. Should you have any questions or require further clarification regarding our capstone project, please do not hesitate to contact us. We are also willing to schedule a meeting at your most convenient time to discuss the details of this partnership further.\n\n'
          'Thank you very much for your time and consideration. We look forward to your positive response.',
          style: TextStyle(color: Colors.black87, fontSize: 12.5, height: 1.5),
        ),
        const SizedBox(height: 28),
        const Text('Respectfully yours,',
            style: TextStyle(color: Colors.black87, fontSize: 13)),
        const SizedBox(height: 20),
        const Text(
          'KIRREN MICHAEL FRAGINAL — Proponent, 4th Year BSIT\n'
          'IVAN NAVARRO — Proponent, 4th Year BSIT\n'
          'AERIANEL SCHYLLE L. PALMERO — Proponent, 4th Year BSIT\n'
          'AKISHA MEKEL SAN MIGUEL — Proponent, 4th Year BSIT',
          style: TextStyle(
              color: Colors.black87,
              fontSize: 12,
              height: 1.6,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
        const Text(
            'Noted by:\n\nHARVEY P. PLAZO\nCapstone Adviser, STI College Naga\n\nJOHN DARRELL D. ANADON, MBA\nBSIT Program Head, STI College Naga',
            style:
                TextStyle(color: Colors.black87, fontSize: 12.5, height: 1.4)),
      ],
    );
  }

  Widget _buildWordViewer(BuildContext context, KycDocument doc) {
    return Column(
      children: [
        // Microsoft Word Reader Ribbon Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1E40AF),
          child: Row(
            children: [
              const Icon(Icons.description_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                doc.filename,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'WORD READER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'Page 1 of 1',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              const VerticalDivider(
                  color: Colors.white24, indent: 6, endIndent: 6),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        color: Colors.white, size: 18),
                    onPressed: _zoomOut,
                    tooltip: 'Zoom Out',
                  ),
                  Text(
                    '${(_currentScale * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: Colors.white, size: 18),
                    onPressed: _zoomIn,
                    tooltip: 'Zoom In',
                  ),
                  TextButton(
                    onPressed: _resetZoom,
                    child: const Text(
                      'Reset',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Word Document Canvas Workspace
        Expanded(
          child: Container(
            color: const Color(0xFFE2E8F0),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.8,
                  maxScale: 3.5,
                  child: Container(
                    width: 680,
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildFireCertificationWordContent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFireCertificationWordContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // BFP Header logo / seal
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFDC2626),
              ),
              child: const Icon(Icons.local_fire_department_rounded,
                  color: Colors.yellowAccent, size: 34),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'REPUBLIC OF THE PHILIPPINES',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Colors.black54),
                ),
                Text(
                  'BUREAU OF FIRE PROTECTION',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB91C1C),
                      letterSpacing: 0.5),
                ),
                Text(
                  'NAGA CITY CENTRAL FIRE STATION — REGION V',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(height: 3, color: const Color(0xFFB91C1C)),
        const SizedBox(height: 20),

        // Certificate title
        const Text(
          'FIRE SAFETY INSPECTION CERTIFICATE',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF991B1B),
            letterSpacing: 1.2,
          ),
        ),
        const Text(
          '(FSIC FOR BUSINESS PERMIT)',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FSIC NO: BFP-R05-NCFS-2026-${(widget.applicantName.hashCode.abs() % 89999 + 10000)}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB91C1C)),
            ),
            const Text(
              'DATE: JAN 18, 2026',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'TO WHOM IT MAY CONCERN:\n\n'
            'By virtue of the provisions of Republic Act No. 9514 (Fire Code of the Philippines of 2008) and its Revised Implementing Rules and Regulations, this CERTIFICATE is hereby granted to:',
            style: TextStyle(fontSize: 12, height: 1.5, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 18),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            border: Border.all(color: const Color(0xFFFCA5A5)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              _permitDetailRow(
                  'ESTABLISHMENT / STALL', widget.stallName.toUpperCase()),
              const Divider(height: 14),
              _permitDetailRow(
                  'OWNER / REPRESENTATIVE', widget.applicantName.toUpperCase()),
              const Divider(height: 14),
              _permitDetailRow('LOCATION', 'NAGA CITY PEOPLE\'S MALL'),
              const Divider(height: 14),
              _permitDetailRow('SAFETY EQUIPMENT',
                  '2x 10lbs ABC DRY CHEMICAL EXTINGUISHERS'),
              const Divider(height: 14),
              _permitDetailRow('VALID UNTIL', 'DECEMBER 31, 2026'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'This certification is issued after complete physical inspection of the stall unit, verification of electrical wirings, fire extinguisher placement, and confirmation that all fire hazard standards are fully satisfied.',
          style: TextStyle(fontSize: 11.5, height: 1.5, color: Colors.black87),
        ),
        const SizedBox(height: 36),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'BFP SEAL VERIFIED',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('INSPECTED BY: BFP NAGA INSPECTORS',
                    style: TextStyle(fontSize: 9, color: Colors.black54)),
              ],
            ),
            Column(
              children: const [
                Text(
                  'CINSP MARCELINO P. ALVAREZ, BFP',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7F1D1D),
                  ),
                ),
                Text(
                  'City Fire Marshal, Naga City',
                  style: TextStyle(fontSize: 10.5, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFallbackView(BuildContext context, KycDocument doc) {
    final colors = semanticColors(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined,
              size: 64, color: colors.mutedText),
          const SizedBox(height: 16),
          Text(
            'Unable to preview this file inline',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.primaryText),
          ),
          const SizedBox(height: 6),
          Text(
            '${doc.filename} • Read-only preview mode.',
            style: TextStyle(fontSize: 12, color: colors.secondaryText),
          ),
        ],
      ),
    );
  }
}
