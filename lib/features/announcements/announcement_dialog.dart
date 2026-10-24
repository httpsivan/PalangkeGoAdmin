import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/widgets/formatted_text.dart';
import '../../data/repositories/mock_repository.dart';
import '../../models/app_models.dart';

const _maxFeatureImageBytes = 5 * 1024 * 1024; // 5 MB
const _maxPopupGalleryImages = 10;

class AnnouncementDialog extends ConsumerStatefulWidget {
  const AnnouncementDialog({
    super.key,
    this.announcementToEdit,
    this.initialTitle,
    this.initialBody,
    this.initialAudience,
    this.initialNotify = true,
  });

  final Announcement? announcementToEdit;
  final String? initialTitle;
  final String? initialBody;
  final String? initialAudience;
  final bool initialNotify;

  @override
  ConsumerState<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends ConsumerState<AnnouncementDialog> {
  bool get isEditMode => widget.announcementToEdit != null;

  late final String _initialTitleText = widget.announcementToEdit?.title ??
      widget.initialTitle ??
      'New Market Guidelines';

  late final String _initialBodyText = (widget.announcementToEdit?.summary ??
          widget.initialBody ??
          'Updated safety protocols for the upcoming weekend market.')
      .replaceAll('*', '');

  late final String _initialAudienceText = normalizeAudience(
    widget.announcementToEdit?.audience ?? widget.initialAudience,
  );

  late final String _initialDurationText = () {
    final item = widget.announcementToEdit;
    if (item != null) {
      if (item.expiresAt == null) return 'Permanent (No Expiry)';
      final days = item.expiresAt!.difference(item.createdAt).inDays;
      if (days <= 1) return '1 Day';
      if (days <= 3) return '3 Days';
      if (days <= 7) return '7 Days (1 Week)';
      if (days <= 14) return '14 Days (2 Weeks)';
      if (days <= 30) return '30 Days (1 Month)';
      return 'Custom Range (Calendar)';
    }
    return 'Permanent (No Expiry)';
  }();

  late final bool _initialNotifyState = widget.announcementToEdit != null
      ? widget.announcementToEdit!.notificationType
          .toLowerCase()
          .contains('push')
      : widget.initialNotify;

  late final titleController = TextEditingController(text: _initialTitleText);
  late final bodyController =
      FormattedTextEditingController(text: _initialBodyText);
  late final facebookUrlController = TextEditingController(
    text: widget.announcementToEdit?.facebookUrl ?? '',
  );
  late bool showAsPopup = widget.announcementToEdit?.showAsPopup ?? false;

  static String normalizeAudience(String? raw) {
    if (raw == null) return 'All Users';
    final lower = raw.trim().toLowerCase();
    if (lower == 'vendors' ||
        lower == 'vendor' ||
        lower == 'stall holders' ||
        lower == 'stallholders' ||
        lower == 'stall holder') {
      return 'Stall Holders';
    }
    if (lower == 'customers' || lower == 'customer') {
      return 'Customers';
    }
    return 'All Users';
  }

  static String normalizeDuration(String? raw) {
    if (raw == null) return 'Permanent (No Expiry)';
    if (raw == '1 Day') return '1 Day';
    if (raw == '3 Days') return '3 Days';
    if (raw == '7 Days' || raw == '7 Days (1 Week)') return '7 Days (1 Week)';
    if (raw == '14 Days' || raw == '14 Days (2 Weeks)') {
      return '14 Days (2 Weeks)';
    }
    if (raw == '30 Days' || raw == '30 Days (1 Month)') {
      return '30 Days (1 Month)';
    }
    if (raw == 'Permanent' || raw == 'Permanent (No Expiry)') {
      return 'Permanent (No Expiry)';
    }
    if (raw == 'Custom Range (Calendar)') return 'Custom Range (Calendar)';
    return 'Permanent (No Expiry)';
  }

  late String audience = _initialAudienceText;
  late String selectedDuration = _initialDurationText;
  late bool notify = _initialNotifyState;

  bool loading = false;
  bool isPreviewMode = false;
  String? titleError;
  String? bodyError;

  Uint8List? image;
  List<Uint8List> popupImageBytes = [];
  List<String> popupImageUrls = [];
  List<Uint8List> _initialPopupImageBytes = [];
  List<String> _initialPopupImageUrls = [];
  Uint8List? originalImageBytes;
  Uint8List? _initialImageBytes;
  String? imageUrl;
  String? _initialImageUrl;
  String? imageName;
  int? imageSizeBytes;
  int? imageWidth;
  int? imageHeight;

  DateTimeRange? customDateRange;

  @override
  void initState() {
    super.initState();
    if (widget.announcementToEdit != null) {
      final item = widget.announcementToEdit!;
      image = item.showAsPopup ? null : item.imageBytes;
      originalImageBytes = item.showAsPopup ? null : item.imageBytes;
      _initialImageBytes = item.showAsPopup ? null : item.imageBytes;
      imageUrl = item.showAsPopup ? null : item.imageUrl;
      _initialImageUrl = item.showAsPopup ? null : item.imageUrl;
      popupImageBytes = [...item.popupImageBytes];
      popupImageUrls = [...item.popupImageUrls];
      _initialPopupImageBytes = [...item.popupImageBytes];
      _initialPopupImageUrls = [...item.popupImageUrls];
      if (image != null) {
        imageSizeBytes = image!.lengthInBytes;
        ui
            .instantiateImageCodec(image!)
            .then((codec) => codec.getNextFrame())
            .then((frame) {
          if (mounted) {
            setState(() {
              imageWidth = frame.image.width;
              imageHeight = frame.image.height;
            });
          }
        }).catchError((_) {});
      }
    }
    titleController.addListener(_onFormFieldChanged);
    bodyController.addListener(_onFormFieldChanged);
  }

  void _onFormFieldChanged() {
    if (mounted) {
      if (titleError != null && titleController.text.trim().isNotEmpty) {
        setState(() => titleError = null);
      }
      if (bodyError != null && bodyController.text.trim().isNotEmpty) {
        setState(() => bodyError = null);
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    titleController.removeListener(_onFormFieldChanged);
    bodyController.removeListener(_onFormFieldChanged);
    titleController.dispose();
    bodyController.dispose();
    facebookUrlController.dispose();
    super.dispose();
  }

  bool get isDirty {
    if (titleController.text.trim() != _initialTitleText.trim()) return true;
    if (bodyController.text.trim() != _initialBodyText.trim()) return true;
    if (audience != _initialAudienceText) return true;
    if (selectedDuration != _initialDurationText) return true;
    if (customDateRange != null) return true;
    if (notify != _initialNotifyState) return true;
    if (showAsPopup != (widget.announcementToEdit?.showAsPopup ?? false)) {
      return true;
    }
    final existing = widget.announcementToEdit;
    if (showAsPopup &&
        existing != null &&
        (existing.imageBytes != null ||
            (existing.imageUrl?.isNotEmpty ?? false))) {
      return true;
    }
    if (facebookUrlController.text.trim() !=
        (widget.announcementToEdit?.facebookUrl ?? '')) {
      return true;
    }
    if (!listEquals(popupImageUrls, _initialPopupImageUrls) ||
        !listEquals(popupImageBytes, _initialPopupImageBytes)) {
      return true;
    }
    if (image != _initialImageBytes) return true;
    if (imageUrl != _initialImageUrl) return true;
    return false;
  }

  Future<bool> _confirmClose() async {
    if (!isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 8),
            Text('Discard Unsaved Changes?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'You have unsaved edits in this announcement. Are you sure you want to exit without saving?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard Changes'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _wrapTag(String openTag, String closeTag) {
    final text = bodyController.text;
    final sel = bodyController.selection;
    final start = sel.start;
    final end = sel.end;

    if (start < 0) return;

    if (start == end) {
      final insert = '$openTag$closeTag';
      bodyController.text =
          text.substring(0, start) + insert + text.substring(start);
      bodyController.selection =
          TextSelection.collapsed(offset: start + openTag.length);
      return;
    }

    final selected = text.substring(start, end);

    if (selected.toLowerCase().startsWith(openTag.toLowerCase()) &&
        selected.toLowerCase().endsWith(closeTag.toLowerCase()) &&
        selected.length >= openTag.length + closeTag.length) {
      final unwrapped =
          selected.substring(openTag.length, selected.length - closeTag.length);
      bodyController.text =
          text.substring(0, start) + unwrapped + text.substring(end);
      bodyController.selection = TextSelection(
          baseOffset: start, extentOffset: start + unwrapped.length);
      return;
    }

    if (start >= openTag.length && (text.length - end) >= closeTag.length) {
      final before = text.substring(start - openTag.length, start);
      final after = text.substring(end, end + closeTag.length);
      if (before.toLowerCase() == openTag.toLowerCase() &&
          after.toLowerCase() == closeTag.toLowerCase()) {
        final newStart = start - openTag.length;
        final newEnd = end + closeTag.length;
        bodyController.text =
            text.substring(0, newStart) + selected + text.substring(newEnd);
        bodyController.selection = TextSelection(
            baseOffset: newStart, extentOffset: newStart + selected.length);
        return;
      }
    }

    final wrapped = '$openTag$selected$closeTag';
    bodyController.text =
        text.substring(0, start) + wrapped + text.substring(end);
    bodyController.selection = TextSelection(
      baseOffset: start + openTag.length,
      extentOffset: start + openTag.length + selected.length,
    );
  }

  void _toggleBold() => _wrapTag('<b>', '</b>');
  void _toggleItalic() => _wrapTag('<i>', '</i>');
  void _toggleUnderline() => _wrapTag('<u>', '</u>');

  void _toggleBullet() {
    final text = bodyController.text;
    final sel = bodyController.selection;
    if (sel.start < 0 || sel.end < 0) return;

    final start = math.min(sel.start, sel.end);
    final end = math.max(sel.start, sel.end);

    final rangeStart = text.lastIndexOf('\n', start - 1) + 1;
    var rangeEnd = text.indexOf('\n', end);
    if (rangeEnd < 0) rangeEnd = text.length;

    final lines = text.substring(rangeStart, rangeEnd).split('\n');
    final prefixPattern = RegExp(r'^(\s*(?:•|\d+\.)\s*)+');

    final allBulleted =
        lines.every((l) => l.trim().isEmpty || RegExp(r'^\s*•').hasMatch(l)) &&
            lines.any((l) => l.trim().isNotEmpty);

    final newLines = <String>[];
    for (final line in lines) {
      final match = prefixPattern.firstMatch(line);
      final stripped = match != null ? line.substring(match.end) : line;
      if (allBulleted) {
        newLines.add(stripped);
      } else {
        newLines.add(stripped.isEmpty ? '' : '• $stripped');
      }
    }

    final replacement = newLines.join('\n');
    bodyController.text =
        text.substring(0, rangeStart) + replacement + text.substring(rangeEnd);
    if (start == end) {
      final lineDiff =
          replacement.length - text.substring(rangeStart, rangeEnd).length;
      final newOffset =
          (start + lineDiff).clamp(rangeStart, rangeStart + replacement.length);
      bodyController.selection = TextSelection.collapsed(offset: newOffset);
    } else {
      bodyController.selection = TextSelection(
        baseOffset: rangeStart,
        extentOffset: rangeStart + replacement.length,
      );
    }
  }

  void _toggleNumberedList() {
    final text = bodyController.text;
    final sel = bodyController.selection;
    if (sel.start < 0 || sel.end < 0) return;

    final start = math.min(sel.start, sel.end);
    final end = math.max(sel.start, sel.end);

    final rangeStart = text.lastIndexOf('\n', start - 1) + 1;
    var rangeEnd = text.indexOf('\n', end);
    if (rangeEnd < 0) rangeEnd = text.length;

    final lines = text.substring(rangeStart, rangeEnd).split('\n');
    final prefixPattern = RegExp(r'^(\s*(?:•|\d+\.)\s*)+');

    final allNumbered = lines.every(
            (l) => l.trim().isEmpty || RegExp(r'^\s*\d+\.').hasMatch(l)) &&
        lines.any((l) => l.trim().isNotEmpty);

    final newLines = <String>[];
    var num = 1;
    for (final line in lines) {
      final match = prefixPattern.firstMatch(line);
      final stripped = match != null ? line.substring(match.end) : line;
      if (allNumbered) {
        newLines.add(stripped);
      } else {
        newLines.add(stripped.isEmpty ? '' : '$num. $stripped');
        if (stripped.isNotEmpty) num++;
      }
    }

    final replacement = newLines.join('\n');
    bodyController.text =
        text.substring(0, rangeStart) + replacement + text.substring(rangeEnd);
    if (start == end) {
      final lineDiff =
          replacement.length - text.substring(rangeStart, rangeEnd).length;
      final newOffset =
          (start + lineDiff).clamp(rangeStart, rangeStart + replacement.length);
      bodyController.selection = TextSelection.collapsed(offset: newOffset);
    } else {
      bodyController.selection = TextSelection(
        baseOffset: rangeStart,
        extentOffset: rangeStart + replacement.length,
      );
    }
  }

  Future<void> _insertLink() async {
    final sel = bodyController.selection;
    final selectedText = sel.start >= 0 && sel.start != sel.end
        ? bodyController.text.substring(sel.start, sel.end)
        : '';

    final labelController = TextEditingController(text: selectedText);
    final urlController = TextEditingController(text: 'https://');

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Insert Link',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Link Text / Label',
                hintText: 'e.g. PalengkeGo Guidelines',
              ),
              autofocus: selectedText.isEmpty,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://palengkego.ph',
              ),
              autofocus: selectedText.isNotEmpty,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F522E)),
            onPressed: () => Navigator.pop(
              ctx,
              (labelController.text.trim(), urlController.text.trim()),
            ),
            child: const Text('Insert Link'),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      labelController.dispose();
      urlController.dispose();
    });

    if (result == null) return;
    final (label, url) = result;
    if (url.isEmpty || url == 'https://') return;

    final displayLabel = label.isEmpty ? url : label;
    final htmlLink = '<a href="$url">$displayLabel</a>';
    final text = bodyController.text;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.start >= 0 ? sel.end : text.length;

    bodyController.text =
        text.substring(0, start) + htmlLink + text.substring(end);
    bodyController.selection =
        TextSelection.collapsed(offset: start + htmlLink.length);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _aspectRatioString(int width, int height) {
    if (width <= 0 || height <= 0) return '';
    final ratio = width / height;
    if ((ratio - 2.0).abs() < 0.05) return '2:1 (1200×600)';
    if ((ratio - 16 / 9).abs() < 0.05) return '16:9';
    if ((ratio - 4 / 3).abs() < 0.05) return '4:3';
    if ((ratio - 1.0).abs() < 0.05) return '1:1';
    return '${ratio.toStringAsFixed(2)}:1';
  }

  Future<void> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (!mounted || bytes == null) return;
    if (bytes.lengthInBytes > _maxFeatureImageBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feature image size must be 5MB or smaller.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final cropped = await _showImageCropper(bytes);
    if (cropped == null) return;

    try {
      final codec = await ui.instantiateImageCodec(cropped);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        originalImageBytes = bytes;
        image = cropped;
        imageName = file?.name;
        imageSizeBytes = cropped.lengthInBytes;
        imageWidth = frame.image.width;
        imageHeight = frame.image.height;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        originalImageBytes = bytes;
        image = cropped;
        imageName = file?.name;
        imageSizeBytes = cropped.lengthInBytes;
        imageWidth = 1200;
        imageHeight = 600;
      });
    }
  }

  void _clearAnnouncementCardImage() {
    image = null;
    originalImageBytes = null;
    imageUrl = null;
    imageName = null;
    imageSizeBytes = null;
    imageWidth = null;
    imageHeight = null;
  }

  void _setShowAsPopup(bool value) {
    setState(() {
      showAsPopup = value;
      if (value) _clearAnnouncementCardImage();
    });
  }

  Future<void> pickPopupImages() async {
    final remaining =
        _maxPopupGalleryImages - popupImageUrls.length - popupImageBytes.length;
    if (remaining <= 0) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (!mounted || result == null) return;
    if (result.files.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A popup can contain up to 10 images.')),
      );
      return;
    }
    final selected = <Uint8List>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      if (bytes.lengthInBytes > _maxFeatureImageBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${file.name} is larger than 5 MB.')),
        );
        return;
      }
      selected.add(bytes);
    }
    if (selected.isNotEmpty) {
      setState(() => popupImageBytes.addAll(selected));
    }
  }

  Widget _popupImageTile(
          {required Widget image, required VoidCallback onRemove}) =>
      SizedBox(
        width: 88,
        height: 112,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image,
            ),
            Positioned(
              top: 2,
              right: 2,
              child: IconButton.filledTonal(
                tooltip: 'Remove image',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 16),
              ),
            ),
          ],
        ),
      );

  Future<void> editImage() async {
    Uint8List? bytes = originalImageBytes ?? image;
    if (bytes == null && imageUrl != null && imageUrl!.isNotEmpty) {
      try {
        if (imageUrl!.startsWith('assets/')) {
          final data = await DefaultAssetBundle.of(context).load(imageUrl!);
          bytes = data.buffer.asUint8List();
          originalImageBytes = bytes;
        }
      } catch (_) {}
    }
    if (bytes == null) return;
    final cropped = await _showImageCropper(bytes);
    if (mounted && cropped != null) {
      try {
        final codec = await ui.instantiateImageCodec(cropped);
        final frame = await codec.getNextFrame();
        setState(() {
          image = cropped;
          imageSizeBytes = cropped.lengthInBytes;
          imageWidth = frame.image.width;
          imageHeight = frame.image.height;
        });
      } catch (_) {
        setState(() {
          image = cropped;
          imageSizeBytes = cropped.lengthInBytes;
        });
      }
    }
  }

  void _showRealSizeDialog(BuildContext context) {
    final hasImg = image != null || (imageUrl != null && imageUrl!.isNotEmpty);
    if (!hasImg) return;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 720),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.photo_size_select_actual_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              imageName ?? 'Feature Image - Real Size Preview',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dimensions: ${imageWidth ?? 0} × ${imageHeight ?? 0} px • File Size: ${_formatBytes(imageSizeBytes ?? (image?.lengthInBytes ?? 0))}${imageWidth != null && imageHeight != null ? ' • Aspect: ${_aspectRatioString(imageWidth!, imageHeight!)}' : ''}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        tooltip: 'Close preview',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white24),
                Flexible(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14)),
                    child: Container(
                      color: const Color(0xFF020617),
                      alignment: Alignment.center,
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5.0,
                        child: image != null
                            ? Image.memory(
                                image!,
                                fit: BoxFit.contain,
                              )
                            : Image.asset(
                                imageUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Image.network(
                                  imageUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_outlined,
                                          semanticLabel: 'Image unavailable')),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _showImageCropper(Uint8List bytes) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AnnouncementImageCropDialog(bytes: bytes),
    );
  }

  static Widget _buildFloatingDatePicker(BuildContext context, Widget? child) {
    final media = MediaQuery.of(context);
    final dialogWidth = (media.size.width * 0.9).clamp(320.0, 480.0);
    final dialogHeight = (media.size.height * 0.85).clamp(420.0, 560.0);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: MediaQuery(
            data: media.copyWith(
              size: Size(dialogWidth, dialogHeight),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: const Color(0xFF0F522E),
                    ),
                datePickerTheme: DatePickerThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 12,
                ),
              ),
              child: child!,
            ),
          ),
        ),
      ),
    );
  }

  String get _customDurationLabel {
    final range = customDateRange;
    if (range == null) return '';
    final days = range.end.difference(range.start).inDays;
    final dateFormat = DateFormat('MMM d, yyyy');
    return '${dateFormat.format(range.start)} – ${dateFormat.format(range.end)} '
        '($days ${days == 1 ? 'day' : 'days'})';
  }

  bool _validate() {
    final titleText = titleController.text.trim();
    final bodyText = bodyController.text.trim();

    String? tErr;
    String? bErr;

    if (titleText.isEmpty) {
      tErr = 'Announcement title is required.';
    }
    if (bodyText.isEmpty) {
      bErr = 'Message body is required.';
    } else if (bodyText.length > 1000) {
      bErr = 'Message body cannot exceed 1,000 characters.';
    }

    setState(() {
      titleError = tErr;
      bodyError = bErr;
    });

    return tErr == null && bErr == null;
  }

  Future<void> save(bool draft) async {
    if (!draft && !_validate()) return;
    if (draft &&
        titleController.text.trim().isEmpty &&
        bodyController.text.trim().isEmpty) {
      setState(() {
        titleError = 'Please add a title or body to save draft.';
      });
      return;
    }

    setState(() => loading = true);
    final data = ref.read(appDataProvider);
    final profile = ref.read(adminProfileProvider);
    final recipients = switch (audience) {
      'Stall Holders' || 'Vendors' => data.vendors.length,
      'Customers' => data.customers.length,
      _ => data.vendors.length + data.customers.length,
    };

    final now = DateTime.now();
    DateTime? computedExpiresAt;
    if (selectedDuration.startsWith('1 Day')) {
      computedExpiresAt = now.add(const Duration(days: 1));
    } else if (selectedDuration.startsWith('3 Days')) {
      computedExpiresAt = now.add(const Duration(days: 3));
    } else if (selectedDuration.startsWith('7 Days')) {
      computedExpiresAt = now.add(const Duration(days: 7));
    } else if (selectedDuration.startsWith('14 Days')) {
      computedExpiresAt = now.add(const Duration(days: 14));
    } else if (selectedDuration.startsWith('30 Days')) {
      computedExpiresAt = now.add(const Duration(days: 30));
    } else if (selectedDuration == 'Custom Range (Calendar)' &&
        customDateRange != null) {
      final end = customDateRange!.end;
      computedExpiresAt = DateTime(end.year, end.month, end.day, 23, 59, 59);
    } else {
      computedExpiresAt = null;
    }

    if (widget.announcementToEdit != null) {
      final existing = widget.announcementToEdit!;
      final updated = existing.copyWith(
        title: titleController.text.trim(),
        summary: bodyController.text.trim(),
        audience: audience,
        isDraft: draft,
        expiresAt: computedExpiresAt,
        notificationType: notify ? 'Push notification' : 'In-app notice',
        state: draft
            ? 'Draft'
            : (existing.state == 'Draft' ? 'Sent' : existing.state),
        imageBytes: image,
        imageUrl: imageUrl,
        showAsPopup: showAsPopup,
        facebookUrl: facebookUrlController.text.trim(),
        popupImageUrls: popupImageUrls,
        popupImageBytes: popupImageBytes,
        clearImage: showAsPopup ||
            (image == null && (imageUrl == null || imageUrl!.isEmpty)),
      );
      await ref.read(appDataProvider.notifier).updateAnnouncement(updated);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Announcement updated successfully.'),
            ],
          ),
          backgroundColor: const Color(0xFF0F522E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await ref.read(appDataProvider.notifier).addAnnouncement(
            Announcement(
              id: 'ANN-${DateTime.now().millisecondsSinceEpoch}',
              title: titleController.text.trim(),
              summary: bodyController.text.trim(),
              audience: audience,
              createdAt: DateTime.now(),
              expiresAt: computedExpiresAt,
              isDraft: draft,
              notificationType: notify ? 'Push notification' : 'In-app notice',
              state: draft ? 'Draft' : 'Queued locally',
              createdBy: profile.name,
              recipientCount: recipients,
              deliveredCount: draft ? 0 : (notify ? recipients : 0),
              imageBytes: image,
              imageUrl: imageUrl,
              showAsPopup: showAsPopup,
              facebookUrl: facebookUrlController.text.trim(),
              popupImageUrls: popupImageUrls,
              popupImageBytes: popupImageBytes,
            ),
          );
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save announcement: $error')),
      );
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              draft
                  ? 'Announcement saved as draft successfully.'
                  : 'Announcement saved and queued for broadcast.',
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F522E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final narrow = mediaWidth < 720;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final badgeLabel = isEditMode
        ? (widget.announcementToEdit!.isDraft
            ? 'Editing Draft'
            : 'Editing Post')
        : 'Draft Mode';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldClose = await _confirmClose();
        if (shouldClose && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: narrow ? 12 : 24,
          vertical: narrow ? 16 : 28,
        ),
        child: Center(
          child: Container(
            width: 750,
            constraints: BoxConstraints(
              maxWidth: 750,
              maxHeight:
                  math.min(760.0, MediaQuery.sizeOf(context).height * 0.92),
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF123D31)
                              : const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          color: isDark
                              ? const Color(0xFF24C58A)
                              : const Color(0xFF0F522E),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text(
                              isEditMode
                                  ? 'Edit Announcement'
                                  : 'Compose New Announcement',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF493619)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF785418)
                                      : const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFFFBF55)
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          if (await _confirmClose() && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),

                // Scrollable Body Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Information Header
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 18,
                              color: isDark
                                  ? const Color(0xFF24C58A)
                                  : const Color(0xFF0F522E),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Basic Information',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Title Field
                        Text(
                          'Announcement Title',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: titleController,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. New Market Guidelines',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor:
                                isDark ? const Color(0xFF0F172A) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: titleError != null
                                    ? const Color(0xFFEF4444)
                                    : (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: titleError != null
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF0F522E),
                                width: 1.5,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFEF4444)),
                            ),
                          ),
                        ),
                        if (titleError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            titleError!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w500),
                          ),
                        ],

                        const SizedBox(height: 18),

                        // Two Column Layout
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stackVertical = constraints.maxWidth < 480;

                            final audienceWidget = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.people_outline_rounded,
                                      size: 16,
                                      color: isDark
                                          ? const Color(0xFF24C58A)
                                          : const Color(0xFF0F522E),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Target Audience',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: normalizeAudience(audience),
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF24C58A)
                                            : const Color(0xFF0F522E),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  items: const [
                                    'All Users',
                                    'Stall Holders',
                                    'Customers'
                                  ]
                                      .map(
                                        (val) => DropdownMenuItem(
                                          value: val,
                                          child: Text(val,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() =>
                                          audience = normalizeAudience(val));
                                    }
                                  },
                                ),
                              ],
                            );

                            final durationWidget = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 15,
                                      color: isDark
                                          ? const Color(0xFF24C58A)
                                          : const Color(0xFF0F522E),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Announcement Duration',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      normalizeDuration(selectedDuration),
                                  isExpanded: true,
                                  menuMaxHeight: 260,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF24C58A)
                                            : const Color(0xFF0F522E),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  items: const [
                                    '1 Day',
                                    '3 Days',
                                    '7 Days (1 Week)',
                                    '14 Days (2 Weeks)',
                                    '30 Days (1 Month)',
                                    'Permanent (No Expiry)',
                                    'Custom Range (Calendar)',
                                  ]
                                      .map(
                                        (val) => DropdownMenuItem(
                                          value: val,
                                          child: Text(val,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) async {
                                    if (val == null) return;
                                    if (val == 'Custom Range (Calendar)') {
                                      final now = DateTime.now();
                                      final start = DateUtils.dateOnly(now);
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: customDateRange?.end ??
                                            now.add(const Duration(days: 7)),
                                        firstDate: start,
                                        lastDate:
                                            now.add(const Duration(days: 365)),
                                        barrierColor: Colors.black
                                            .withValues(alpha: 0.45),
                                        builder: _buildFloatingDatePicker,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          selectedDuration =
                                              'Custom Range (Calendar)';
                                          customDateRange = DateTimeRange(
                                            start: start,
                                            end: DateTime(
                                                picked.year,
                                                picked.month,
                                                picked.day,
                                                23,
                                                59,
                                                59),
                                          );
                                        });
                                      }
                                    } else {
                                      setState(() => selectedDuration = val);
                                    }
                                  },
                                ),
                                if (customDateRange != null &&
                                    selectedDuration ==
                                        'Custom Range (Calendar)') ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    'Active: $_customDurationLabel',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFF24C58A)
                                          : const Color(0xFF0F522E),
                                    ),
                                  ),
                                ],
                              ],
                            );

                            if (stackVertical) {
                              return Column(
                                children: [
                                  audienceWidget,
                                  const SizedBox(height: 14),
                                  durationWidget,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: audienceWidget),
                                const SizedBox(width: 16),
                                Expanded(child: durationWidget),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 18),

                        Material(
                          color: Colors.transparent,
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Show as an in-app popup'),
                            subtitle: const Text(
                              'Display this announcement once per day to its audience.',
                            ),
                            value: showAsPopup,
                            onChanged: _setShowAsPopup,
                          ),
                        ),
                        if (showAsPopup) ...[
                          const SizedBox(height: 6),
                          TextField(
                            controller: facebookUrlController,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Facebook post link (optional)',
                              hintText: 'https://www.facebook.com/...',
                              prefixIcon: Icon(Icons.link),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Popup Gallery (up to 10 images)',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: popupImageUrls.length +
                                            popupImageBytes.length >=
                                        _maxPopupGalleryImages
                                    ? null
                                    : pickPopupImages,
                                icon: const Icon(
                                    Icons.add_photo_alternate_outlined),
                                label: const Text('Add photos'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'These images appear as swipeable slides in the app popup. Each image must be 5 MB or smaller.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          if (popupImageUrls.isNotEmpty ||
                              popupImageBytes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...popupImageUrls.asMap().entries.map(
                                      (entry) => _popupImageTile(
                                        image: Image.network(
                                          entry.value,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.broken_image),
                                        ),
                                        onRemove: () => setState(() =>
                                            popupImageUrls.removeAt(entry.key)),
                                      ),
                                    ),
                                ...popupImageBytes.asMap().entries.map(
                                      (entry) => _popupImageTile(
                                        image: Image.memory(
                                          entry.value,
                                          fit: BoxFit.cover,
                                        ),
                                        onRemove: () => setState(() =>
                                            popupImageBytes
                                                .removeAt(entry.key)),
                                      ),
                                    ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],

                        if (!showAsPopup) ...[
                          // Feature Image Section
                          Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFF24C58A)
                                    : const Color(0xFF0F522E),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Feature Image (Optional)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          (image == null &&
                                  (imageUrl == null || imageUrl!.isEmpty))
                              ? InkWell(
                                  onTap: pick,
                                  borderRadius: BorderRadius.circular(10),
                                  child: CustomPaint(
                                    painter: _DashedBorderPainter(
                                      color: isDark
                                          ? const Color(0xFF24C58A)
                                          : const Color(0xFF86EFAC),
                                      radius: 10,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 20, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.cloud_upload_outlined,
                                            color: Color(0xFF16A34A),
                                            size: 30,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Drag and drop an image, or click to upload',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1E293B),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Recommended size: 1200 × 600px (Max 5MB)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? Colors.white54
                                                  : const Color(0xFF64748B),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: colors.subtleBorder),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      AspectRatio(
                                        aspectRatio: (imageWidth != null &&
                                                imageHeight != null &&
                                                imageHeight! > 0)
                                            ? (imageWidth! / imageHeight!)
                                            : (1200 / 600),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            InkWell(
                                              onTap: () =>
                                                  _showRealSizeDialog(context),
                                              child: image != null
                                                  ? Image.memory(
                                                      image!,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Image.asset(
                                                      imageUrl!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, __, ___) =>
                                                              Image.network(
                                                        imageUrl!,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __,
                                                                ___) =>
                                                            const Center(
                                                                child: Icon(
                                                                    Icons
                                                                        .broken_image_outlined,
                                                                    semanticLabel:
                                                                        'Image unavailable')),
                                                      ),
                                                    ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.75),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${imageWidth ?? 1200} × ${imageHeight ?? 600} px',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        color: isDark
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFF8FAFC),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                imageName ??
                                                    'Feature Image Loaded',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF334155),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              onPressed: editImage,
                                              icon: Icon(
                                                Icons.crop_rounded,
                                                size: 14,
                                                color: isDark
                                                    ? const Color(0xFF24C58A)
                                                    : const Color(0xFF0F522E),
                                              ),
                                              label: Text(
                                                'Edit Picture',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF0F522E),
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: isDark
                                                      ? const Color(0xFF33415E)
                                                      : const Color(0xFFCBD5E1),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            OutlinedButton.icon(
                                              onPressed: pick,
                                              icon: Icon(
                                                Icons.refresh_rounded,
                                                size: 14,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF334155),
                                              ),
                                              label: Text(
                                                'Replace Image',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF334155),
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: isDark
                                                      ? const Color(0xFF33415E)
                                                      : const Color(0xFFCBD5E1),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            OutlinedButton.icon(
                                              onPressed: () => setState(() {
                                                _clearAnnouncementCardImage();
                                              }),
                                              icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 14,
                                                  color: Color(0xFFEF4444)),
                                              label: const Text('Remove',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Color(0xFFEF4444))),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: isDark
                                                      ? const Color(0xFF7F1D1D)
                                                      : const Color(0xFFFCA5A5),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                          const SizedBox(height: 18),
                        ],

                        // Message Body Rich Text Editor Section
                        Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color: isDark
                                  ? const Color(0xFF24C58A)
                                  : const Color(0xFF0F522E),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Message Body',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        Container(
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: bodyError != null
                                  ? const Color(0xFFEF4444)
                                  : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Toolbar Header
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(9)),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        onPressed: _toggleBold,
                                        tooltip: 'Bold',
                                        icon: Icon(
                                          Icons.format_bold_rounded,
                                          size: 17,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _toggleItalic,
                                        tooltip: 'Italic',
                                        icon: Icon(
                                          Icons.format_italic_rounded,
                                          size: 17,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _toggleUnderline,
                                        tooltip: 'Underline',
                                        icon: Icon(
                                          Icons.format_underlined_rounded,
                                          size: 17,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _toggleBullet,
                                        tooltip: 'Bulleted List',
                                        icon: Icon(
                                          Icons.format_list_bulleted_rounded,
                                          size: 17,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _toggleNumberedList,
                                        tooltip: 'Numbered List',
                                        icon: Icon(
                                          Icons.format_list_numbered_rounded,
                                          size: 17,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _insertLink,
                                        tooltip: 'Insert Link',
                                        icon: Icon(
                                          Icons.link_rounded,
                                          size: 17,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      TextButton.icon(
                                        onPressed: () => setState(() =>
                                            isPreviewMode = !isPreviewMode),
                                        icon: Icon(
                                          isPreviewMode
                                              ? Icons.edit_outlined
                                              : Icons.visibility_outlined,
                                          size: 15,
                                          color: isDark
                                              ? const Color(0xFF24C58A)
                                              : const Color(0xFF0F522E),
                                        ),
                                        label: Text(
                                          isPreviewMode ? 'Edit' : 'Preview',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? const Color(0xFF24C58A)
                                                : const Color(0xFF0F522E),
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Text Area / Preview
                              if (!isPreviewMode)
                                TextField(
                                  controller: bodyController,
                                  minLines: 4,
                                  maxLines: 6,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.45,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    fillColor: Colors.transparent,
                                    filled: true,
                                    contentPadding: const EdgeInsets.all(12),
                                    hintText:
                                        'Enter announcement message content...',
                                    hintStyle: TextStyle(
                                      fontSize: 13.5,
                                      color: isDark
                                          ? Colors.white38
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  constraints:
                                      const BoxConstraints(minHeight: 110),
                                  child: FormattedSelectableText(
                                    bodyController.text.isEmpty
                                        ? '*(Empty message body)*'
                                        : bodyController.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.45,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),

                              // Character Counter & Error Row
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 4, 12, 8),
                                child: Row(
                                  children: [
                                    if (bodyError != null)
                                      Expanded(
                                        child: Text(
                                          bodyError!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFEF4444),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      )
                                    else
                                      const Spacer(),
                                    Text(
                                      '${bodyController.text.length} / 1,000 characters',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: bodyController.text.length > 1000
                                            ? const Color(0xFFEF4444)
                                            : (isDark
                                                ? Colors.white54
                                                : const Color(0xFF64748B)),
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
                ),

                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final notifyRow = ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: constraints.maxWidth),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: notify,
                                activeColor: isDark
                                    ? const Color(0xFF24C58A)
                                    : const Color(0xFF0F522E),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) =>
                                    setState(() => notify = val ?? false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Send push notification to mobile app',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Tooltip(
                              message:
                                  'Sends an instant push notification to all users on the mobile app upon saving.',
                              child: Icon(
                                Icons.info_outline,
                                size: 15,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      );

                      final isSaveDisabled =
                          loading || (isEditMode && !isDirty);

                      final buttons = [
                        OutlinedButton.icon(
                          onPressed: loading ? null : () => save(true),
                          icon: Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF334155),
                          ),
                          label: const Text('Save as Draft'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor:
                                isDark ? const Color(0xFF0F172A) : Colors.white,
                            foregroundColor:
                                isDark ? Colors.white : const Color(0xFF334155),
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: isSaveDisabled ? null : () => save(false),
                          icon: loading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  isEditMode
                                      ? Icons.check_rounded
                                      : Icons.send_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                          label: Text(
                            loading
                                ? 'Saving…'
                                : (isEditMode
                                    ? 'Save Changes'
                                    : 'Send Announcement'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF10B981)
                                : const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                            disabledForegroundColor: isDark
                                ? Colors.white38
                                : const Color(0xFF94A3B8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ];

                      return Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          notifyRow,
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: buttons,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnnouncementImageCropDialog extends StatefulWidget {
  const AnnouncementImageCropDialog({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<AnnouncementImageCropDialog> createState() =>
      _AnnouncementImageCropDialogState();
}

enum _CropDragTarget { none, move, topLeft, topRight, bottomLeft, bottomRight }

class _AnnouncementImageCropDialogState
    extends State<AnnouncementImageCropDialog> {
  late final Future<ui.Image> _decodedImage = _decodeImage(widget.bytes);

  Rect? _imageRect;
  Rect? _cropRect;
  _CropDragTarget _activeDrag = _CropDragTarget.none;
  _CropDragTarget _hoverTarget = _CropDragTarget.none;
  Size? _lastCanvasSize;

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  void _initGeometry(Size canvasSize, ui.Image source) {
    if (_lastCanvasSize == canvasSize && _imageRect != null) return;
    _lastCanvasSize = canvasSize;

    final imageAspect = source.width / source.height;
    final canvasAspect = canvasSize.width / canvasSize.height;
    Rect imgRect;
    if (imageAspect > canvasAspect) {
      final drawWidth = canvasSize.width;
      final drawHeight = drawWidth / imageAspect;
      final top = (canvasSize.height - drawHeight) / 2;
      imgRect = Rect.fromLTWH(0, top, drawWidth, drawHeight);
    } else {
      final drawHeight = canvasSize.height;
      final drawWidth = drawHeight * imageAspect;
      final left = (canvasSize.width - drawWidth) / 2;
      imgRect = Rect.fromLTWH(left, 0, drawWidth, drawHeight);
    }
    _imageRect = imgRect;

    double initW;
    double initH;
    if (imgRect.width / imgRect.height > 2.0) {
      initH = imgRect.height * 0.96;
      initW = initH * 2.0;
    } else {
      initW = imgRect.width * 0.96;
      initH = initW / 2.0;
    }
    final initL = imgRect.left + (imgRect.width - initW) / 2;
    final initT = imgRect.top + (imgRect.height - initH) / 2;
    _cropRect = Rect.fromLTWH(initL, initT, initW, initH);
  }

  _CropDragTarget _hitTest(Offset pos) {
    if (_cropRect == null) return _CropDragTarget.none;
    const handleRadius = 26.0;
    final rect = _cropRect!;

    if ((pos - rect.topLeft).distance <= handleRadius) {
      return _CropDragTarget.topLeft;
    }
    if ((pos - rect.topRight).distance <= handleRadius) {
      return _CropDragTarget.topRight;
    }
    if ((pos - rect.bottomLeft).distance <= handleRadius) {
      return _CropDragTarget.bottomLeft;
    }
    if ((pos - rect.bottomRight).distance <= handleRadius) {
      return _CropDragTarget.bottomRight;
    }
    if (rect.contains(pos)) {
      return _CropDragTarget.move;
    }
    return _CropDragTarget.none;
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _activeDrag = _hitTest(details.localPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_imageRect == null ||
        _cropRect == null ||
        _activeDrag == _CropDragTarget.none) {
      return;
    }
    final delta = details.delta;
    final img = _imageRect!;
    var cur = _cropRect!;
    const minWidth = 100.0;

    switch (_activeDrag) {
      case _CropDragTarget.move:
        final maxL = img.right - cur.width;
        final maxT = img.bottom - cur.height;
        final newL = (cur.left + delta.dx).clamp(img.left, maxL);
        final newT = (cur.top + delta.dy).clamp(img.top, maxT);
        cur = Rect.fromLTWH(newL, newT, cur.width, cur.height);
        break;

      case _CropDragTarget.bottomRight:
        final maxW = img.right - cur.left;
        final maxH = img.bottom - cur.top;
        var newW = (cur.width + delta.dx).clamp(minWidth, maxW);
        var newH = newW / 2.0;
        if (newH > maxH) {
          newH = maxH;
          newW = newH * 2.0;
        }
        cur = Rect.fromLTWH(cur.left, cur.top, newW, newH);
        break;

      case _CropDragTarget.bottomLeft:
        final maxW = cur.right - img.left;
        final maxH = img.bottom - cur.top;
        var newW = (cur.width - delta.dx).clamp(minWidth, maxW);
        var newH = newW / 2.0;
        if (newH > maxH) {
          newH = maxH;
          newW = newH * 2.0;
        }
        cur = Rect.fromLTWH(cur.right - newW, cur.top, newW, newH);
        break;

      case _CropDragTarget.topRight:
        final maxW = img.right - cur.left;
        final maxH = cur.bottom - img.top;
        var newW = (cur.width + delta.dx).clamp(minWidth, maxW);
        var newH = newW / 2.0;
        if (newH > maxH) {
          newH = maxH;
          newW = newH * 2.0;
        }
        cur = Rect.fromLTWH(cur.left, cur.bottom - newH, newW, newH);
        break;

      case _CropDragTarget.topLeft:
        final maxW = cur.right - img.left;
        final maxH = cur.bottom - img.top;
        var newW = (cur.width - delta.dx).clamp(minWidth, maxW);
        var newH = newW / 2.0;
        if (newH > maxH) {
          newH = maxH;
          newW = newH * 2.0;
        }
        cur = Rect.fromLTWH(cur.right - newW, cur.bottom - newH, newW, newH);
        break;

      case _CropDragTarget.none:
        break;
    }

    setState(() {
      _cropRect = cur;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _activeDrag = _CropDragTarget.none;
    });
  }

  Future<void> _confirmCrop(ui.Image source) async {
    if (_imageRect == null || _cropRect == null) return;
    final img = _imageRect!;
    final crop = _cropRect!;

    final scaleX = source.width / img.width;
    final scaleY = source.height / img.height;

    final srcLeft =
        ((crop.left - img.left) * scaleX).clamp(0.0, source.width.toDouble());
    final srcTop =
        ((crop.top - img.top) * scaleY).clamp(0.0, source.height.toDouble());
    final srcWidth =
        (crop.width * scaleX).clamp(1.0, source.width.toDouble() - srcLeft);
    final srcHeight =
        (crop.height * scaleY).clamp(1.0, source.height.toDouble() - srcTop);

    const outputWidth = 1200;
    const outputHeight = 600;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(srcLeft, srcTop, srcWidth, srcHeight),
      const Rect.fromLTWH(0, 0, 1200.0, 600.0),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(outputWidth, outputHeight);
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    cropped.dispose();

    if (!mounted || data == null) return;
    if (data.lengthInBytes > _maxFeatureImageBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The cropped image exceeds 5MB. Reduce crop size.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(Uint8List.fromList(data.buffer.asUint8List()));
  }

  MouseCursor get _cursor => switch (_hoverTarget) {
        _CropDragTarget.move => SystemMouseCursors.move,
        _CropDragTarget.topLeft ||
        _CropDragTarget.bottomRight =>
          SystemMouseCursors.resizeUpLeftDownRight,
        _CropDragTarget.topRight ||
        _CropDragTarget.bottomLeft =>
          SystemMouseCursors.resizeUpRightDownLeft,
        _CropDragTarget.none => SystemMouseCursors.basic,
      };

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogWidth = math.min(
      740.0,
      math.max(340.0, MediaQuery.sizeOf(context).width - 64.0),
    );
    const canvasHeight = 380.0;

    return AlertDialog(
      title: const Text('Crop Feature Image'),
      content: SizedBox(
        width: dialogWidth,
        child: FutureBuilder<ui.Image>(
          future: _decodedImage,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('This image format is not supported.');
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final source = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Drag inside the grid to reposition • Drag corner handles to resize',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: canvasHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.subtleBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _initGeometry(
                        Size(constraints.maxWidth, canvasHeight),
                        source,
                      );
                      if (_imageRect == null || _cropRect == null) {
                        return const SizedBox.shrink();
                      }

                      return MouseRegion(
                        cursor: _cursor,
                        onHover: (event) {
                          final target = _hitTest(event.localPosition);
                          if (target != _hoverTarget) {
                            setState(() => _hoverTarget = target);
                          }
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          child: CustomPaint(
                            size: Size(constraints.maxWidth, canvasHeight),
                            painter: _GalleryCropPainter(
                              source: source,
                              imageRect: _imageRect!,
                              cropRect: _cropRect!,
                              accentColor: isDark
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF0F522E),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.infoContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: colors.info.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.aspect_ratio_rounded,
                              size: 14, color: colors.info),
                          const SizedBox(width: 5),
                          Text(
                            'Target: 1200 × 600 px (2:1)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.info,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isDark ? colors.secondaryText : colors.primaryText,
                      ),
                      onPressed: () {
                        setState(() {
                          _lastCanvasSize = null;
                        });
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('Reset Crop',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor:
                isDark ? const Color(0xFFFF7A84) : const Color(0xFFEF4444),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        FutureBuilder<ui.Image>(
          future: _decodedImage,
          builder: (context, snapshot) => FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor:
                  isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              disabledForegroundColor:
                  isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
            onPressed:
                snapshot.hasData ? () => _confirmCrop(snapshot.data!) : null,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text(
              'Apply Crop',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryCropPainter extends CustomPainter {
  const _GalleryCropPainter({
    required this.source,
    required this.imageRect,
    required this.cropRect,
    required this.accentColor,
  });

  final ui.Image source;
  final Rect imageRect;
  final Rect cropRect;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      imageRect,
      paint,
    );

    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(cropRect),
      ),
      dimPaint,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(cropRect, borderPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final w3 = cropRect.width / 3;
    final h3 = cropRect.height / 3;
    canvas.drawLine(Offset(cropRect.left + w3, cropRect.top),
        Offset(cropRect.left + w3, cropRect.bottom), gridPaint);
    canvas.drawLine(Offset(cropRect.left + w3 * 2, cropRect.top),
        Offset(cropRect.left + w3 * 2, cropRect.bottom), gridPaint);
    canvas.drawLine(Offset(cropRect.left, cropRect.top + h3),
        Offset(cropRect.right, cropRect.top + h3), gridPaint);
    canvas.drawLine(Offset(cropRect.left, cropRect.top + h3 * 2),
        Offset(cropRect.right, cropRect.top + h3 * 2), gridPaint);

    final handlePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    final handleStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const r = 8.0;
    for (final corner in [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight
    ]) {
      canvas.drawCircle(corner, r, handlePaint);
      canvas.drawCircle(corner, r, handleStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _GalleryCropPainter oldDelegate) {
    return oldDelegate.source != source ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.cropRect != cropRect ||
        oldDelegate.accentColor != accentColor;
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    this.radius = 10,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromLTRBR(
      0.75,
      0.75,
      size.width - 0.75,
      size.height - 0.75,
      Radius.circular(radius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path metricsPath = Path();

    for (final ui.PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double length = math.min(6, metric.length - distance);
        metricsPath.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += 10;
      }
    }
    canvas.drawPath(metricsPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
