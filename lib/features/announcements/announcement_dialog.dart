import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/widgets/formatted_text.dart';
import '../../data/repositories/mock_repository.dart';
import '../../models/app_models.dart';

const _maxFeatureImageBytes = 50 * 1024 * 1024;

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

  late final title = TextEditingController(
    text: widget.announcementToEdit?.title ??
        widget.initialTitle ??
        'Public Market Holiday Notice',
  );
  late final body = FormattedTextEditingController(
    text: (widget.announcementToEdit?.summary ??
            widget.initialBody ??
            'Good day! Please be informed that the PalengkeGo services will be temporarily unavailable on Friday due to the scheduled holiday maintenance. Stall holders are advised to settle transactions early. Thank you!')
        .replaceAll('*', ''),
  );
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

  late String audience = normalizeAudience(
    widget.announcementToEdit?.audience ?? widget.initialAudience,
  );
  late bool notify = widget.announcementToEdit != null
      ? widget.announcementToEdit!.notificationType.toLowerCase().contains('push')
      : widget.initialNotify;
  bool loading = false;
  Uint8List? image;
  Uint8List? originalImageBytes;
  String? imageUrl;
  String? imageName;
  int? imageSizeBytes;
  int? imageWidth;
  int? imageHeight;

  @override
  void initState() {
    super.initState();
    if (widget.announcementToEdit != null) {
      final item = widget.announcementToEdit!;
      image = item.imageBytes;
      originalImageBytes = item.imageBytes;
      imageUrl = item.imageUrl;
      if (image != null) {
        imageSizeBytes = image!.lengthInBytes;
        ui.instantiateImageCodec(image!).then((codec) => codec.getNextFrame()).then((frame) {
          if (mounted) {
            setState(() {
              imageWidth = frame.image.width;
              imageHeight = frame.image.height;
            });
          }
        }).catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  /// Wraps selection with openTag (e.g. `<b>`) and closeTag (e.g. `</b>`).
  /// Unwraps if already present.
  void _wrapTag(String openTag, String closeTag) {
    final text = body.text;
    final sel = body.selection;
    final start = sel.start;
    final end = sel.end;

    if (start < 0) return;

    if (start == end) {
      final insert = '$openTag$closeTag';
      body.text = text.substring(0, start) + insert + text.substring(start);
      body.selection = TextSelection.collapsed(offset: start + openTag.length);
      return;
    }

    final selected = text.substring(start, end);

    // 1. Direct wrapping check
    if (selected.toLowerCase().startsWith(openTag.toLowerCase()) &&
        selected.toLowerCase().endsWith(closeTag.toLowerCase()) &&
        selected.length >= openTag.length + closeTag.length) {
      final unwrapped = selected.substring(openTag.length, selected.length - closeTag.length);
      body.text = text.substring(0, start) + unwrapped + text.substring(end);
      body.selection = TextSelection(baseOffset: start, extentOffset: start + unwrapped.length);
      return;
    }

    // 2. Surrounding check
    if (start >= openTag.length && (text.length - end) >= closeTag.length) {
      final before = text.substring(start - openTag.length, start);
      final after = text.substring(end, end + closeTag.length);
      if (before.toLowerCase() == openTag.toLowerCase() &&
          after.toLowerCase() == closeTag.toLowerCase()) {
        final newStart = start - openTag.length;
        final newEnd = end + closeTag.length;
        body.text = text.substring(0, newStart) + selected + text.substring(newEnd);
        body.selection = TextSelection(baseOffset: newStart, extentOffset: newStart + selected.length);
        return;
      }
    }

    // 3. Wrap selection
    final wrapped = '$openTag$selected$closeTag';
    body.text = text.substring(0, start) + wrapped + text.substring(end);
    body.selection = TextSelection(
      baseOffset: start + openTag.length,
      extentOffset: start + openTag.length + selected.length,
    );
  }

  void _toggleBold() => _wrapTag('<b>', '</b>');
  void _toggleItalic() => _wrapTag('<i>', '</i>');

  void _toggleBullet() {
    final text = body.text;
    final sel = body.selection;
    if (sel.start < 0) return;

    final lineStart = text.lastIndexOf('\n', sel.start - 1) + 1;
    var lineEnd = text.indexOf('\n', sel.start);
    if (lineEnd < 0) lineEnd = text.length;

    final line = text.substring(lineStart, lineEnd);

    if (line.startsWith('• ')) {
      body.text = text.substring(0, lineStart) + line.substring(2) + text.substring(lineEnd);
      body.selection = TextSelection.collapsed(offset: (sel.start - 2).clamp(lineStart, body.text.length));
    } else {
      body.text = '${text.substring(0, lineStart)}• $line${text.substring(lineEnd)}';
      body.selection = TextSelection.collapsed(offset: sel.start + 2);
    }
  }

  Future<void> _insertLink() async {
    final sel = body.selection;
    final selectedText = sel.start >= 0 && sel.start != sel.end
        ? body.text.substring(sel.start, sel.end)
        : '';

    final labelController = TextEditingController(text: selectedText);
    final urlController = TextEditingController(text: 'https://');

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert Link', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Link Text / Label',
                hintText: 'e.g. PalengkeGo Portal',
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              (labelController.text.trim(), urlController.text.trim()),
            ),
            child: const Text('Insert Link'),
          ),
        ],
      ),
    );

    labelController.dispose();
    urlController.dispose();

    if (result == null) return;
    final (label, url) = result;
    if (url.isEmpty || url == 'https://') return;

    final displayLabel = label.isEmpty ? url : label;
    final htmlLink = '<a href="$url">$displayLabel</a>';
    final text = body.text;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.start >= 0 ? sel.end : text.length;

    body.text = text.substring(0, start) + htmlLink + text.substring(end);
    body.selection = TextSelection.collapsed(offset: start + htmlLink.length);
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
            content: Text('Feature images must be 50 MB or smaller.')),
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

  Future<void> editImage() async {
    final bytes = originalImageBytes ?? image;
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
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        tooltip: 'Close preview',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white24),
                Flexible(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(14)),
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

  Widget _actionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.68),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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

  static Widget _buildFloatingDatePicker(
      BuildContext context, Widget? child) {
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
                      primary: const Color(0xFF10B981),
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

  late String selectedDuration = () {
    final item = widget.announcementToEdit;
    if (item != null) {
      if (item.expiresAt == null) return 'Permanent (No Expiry)';
      final days = item.expiresAt!.difference(item.createdAt).inDays;
      if (days <= 1) return '1 Day';
      if (days <= 3) return '3 Days';
      if (days <= 7) return '7 Days';
      if (days <= 14) return '14 Days';
      if (days <= 30) return '30 Days';
      return 'Custom Range (Calendar)';
    }
    return '7 Days';
  }();

  DateTimeRange? customDateRange;

  Future<void> save(bool draft) async {
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and message before saving.')),
      );
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
    if (selectedDuration == '1 Day') {
      computedExpiresAt = now.add(const Duration(days: 1));
    } else if (selectedDuration == '3 Days') {
      computedExpiresAt = now.add(const Duration(days: 3));
    } else if (selectedDuration == '7 Days') {
      computedExpiresAt = now.add(const Duration(days: 7));
    } else if (selectedDuration == '14 Days') {
      computedExpiresAt = now.add(const Duration(days: 14));
    } else if (selectedDuration == '30 Days') {
      computedExpiresAt = now.add(const Duration(days: 30));
    } else if (selectedDuration == 'Custom Range (Calendar)' &&
        customDateRange != null) {
      computedExpiresAt = customDateRange!.end;
    } else {
      computedExpiresAt = null;
    }

    if (widget.announcementToEdit != null) {
      final existing = widget.announcementToEdit!;
      final updated = existing.copyWith(
        title: title.text.trim(),
        summary: body.text.trim(),
        audience: audience,
        isDraft: draft,
        expiresAt: computedExpiresAt,
        notificationType: notify ? 'Push notification' : 'In-app notice',
        state: draft
            ? 'Draft'
            : (existing.state == 'Draft' ? 'Sent' : existing.state),
        imageBytes: image,
        imageUrl: imageUrl,
        clearImage: image == null && (imageUrl == null || imageUrl!.isEmpty),
      );
      await ref.read(appDataProvider.notifier).updateAnnouncement(updated);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement updated successfully.')),
      );
      return;
    }

    await ref.read(appDataProvider.notifier).addAnnouncement(
          Announcement(
            id: 'ANN-${DateTime.now().millisecondsSinceEpoch}',
            title: title.text.trim(),
            summary: body.text.trim(),
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
          ),
        );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          draft
              ? 'Announcement saved as draft locally.'
              : 'Announcement queued locally; backend delivery is not configured.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 12 : 80,
        vertical: narrow ? 12 : 36,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: math.min(680.0, MediaQuery.sizeOf(context).height * 0.8),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 22, narrow ? 16 : 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    isEditMode
                        ? 'Edit Announcement'
                        : 'Compose New Announcement',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.go('/announcements');
                        },
                        icon: const Icon(Icons.history_rounded, size: 16),
                        label: const Text(
                          'View History',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      StatusBadge(
                        label: isEditMode
                            ? (widget.announcementToEdit!.isDraft
                                ? 'EDITING DRAFT'
                                : 'EDITING POST')
                            : 'DRAFT MODE',
                        kind: isEditMode
                            ? (widget.announcementToEdit!.isDraft
                                ? BadgeKind.neutral
                                : BadgeKind.warning)
                            : BadgeKind.success,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 17),
              const Divider(),
              const SizedBox(height: 15),
              const Text(
                'Announcement Title',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              TextField(controller: title),
              const SizedBox(height: 15),
              LayoutBuilder(
                builder: (context, constraints) {
                  final useColumn = constraints.maxWidth < 480;
                  final audienceWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target Audience',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: normalizeAudience(audience),
                        items: const ['All Users', 'Stall Holders', 'Customers']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => audience = normalizeAudience(value)),
                      ),
                    ],
                  );

                  final durationWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Announcement Duration',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedDuration,
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
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          if (value == 'Custom Range (Calendar)') {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: customDateRange?.end ??
                                  now.add(const Duration(days: 7)),
                              firstDate: DateTime(2024),
                              lastDate: now.add(const Duration(days: 365)),
                              barrierColor: Colors.black.withValues(alpha: 0.45),
                              builder: _buildFloatingDatePicker,
                            );
                            if (picked != null) {
                              setState(() {
                                selectedDuration = 'Custom Range (Calendar)';
                                customDateRange = DateTimeRange(
                                  start: now,
                                  end: DateTime(
                                      picked.year, picked.month, picked.day, 23, 59, 59),
                                );
                              });
                            }
                          } else {
                            setState(() => selectedDuration = value);
                          }
                        },
                      ),
                    ],
                  );

                  if (useColumn) {
                    return Column(
                      children: [
                        audienceWidget,
                        const SizedBox(height: 15),
                        durationWidget,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: audienceWidget),
                      const SizedBox(width: 14),
                      Expanded(child: durationWidget),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Feature Image (Optional)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  if ((image != null || imageUrl != null) && imageWidth != null && imageHeight != null)
                    Text(
                      'Real Size: $imageWidth × $imageHeight px • ${_formatBytes(imageSizeBytes ?? (image?.lengthInBytes ?? 0))}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              (image == null && (imageUrl == null || imageUrl!.isEmpty))
                  ? InkWell(
                      onTap: pick,
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        width: double.infinity,
                        height: 94,
                        decoration: BoxDecoration(
                          color: colors.infoContainer.withValues(alpha: .48),
                          border: Border.all(
                              color: colors.info.withValues(alpha: .35)),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: .7),
                              size: 26,
                            ),
                            Text(
                              'Drag and drop or click to upload',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: .7),
                              ),
                            ),
                            Text(
                              'Recommended size: 1200×600px (Max 50MB)',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: .45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: colors.subtleBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(
                        aspectRatio: (imageWidth != null && imageHeight != null && imageHeight! > 0)
                            ? (imageWidth! / imageHeight!)
                            : (1200 / 600),
                        child: Stack(
                          alignment: Alignment.center,
                          fit: StackFit.expand,
                          children: [
                            Tooltip(
                              message: 'Click to view real size in full preview',
                              child: InkWell(
                                onTap: () => _showRealSizeDialog(context),
                                child: image != null
                                    ? Image.memory(
                                        image!,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.asset(
                                        imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Image.network(
                                          imageUrl!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                              ),
                            ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.photo_size_select_actual_outlined,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Real Size: ${imageWidth ?? 0} × ${imageHeight ?? 0} px • ${_formatBytes(imageSizeBytes ?? (image?.lengthInBytes ?? 0))}${imageWidth != null && imageHeight != null ? ' (${_aspectRatioString(imageWidth!, imageHeight!)})' : ''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.68),
                              shape: const CircleBorder(),
                              child: IconButton(
                                onPressed: () => setState(() {
                                  image = null;
                                  originalImageBytes = null;
                                  imageUrl = null;
                                  imageName = null;
                                  imageSizeBytes = null;
                                  imageWidth = null;
                                  imageHeight = null;
                                }),
                                tooltip: 'Remove feature image',
                                icon: const Icon(Icons.close_rounded),
                                iconSize: 18,
                                color: Colors.white,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Wrap(
                              spacing: 6,
                              children: [
                                _actionPill(
                                  icon: Icons.zoom_in_rounded,
                                  label: 'View Real Size',
                                  onTap: () => _showRealSizeDialog(context),
                                ),
                                _actionPill(
                                  icon: Icons.crop_rounded,
                                  label: 'Edit/Crop',
                                  onTap: editImage,
                                ),
                                _actionPill(
                                  icon: Icons.refresh_rounded,
                                  label: 'Change',
                                  onTap: pick,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              const Text(
                'Message Body',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.subtleBorder),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 36,
                      color: colors.tableHeader,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _toggleBold,
                            tooltip: 'Bold',
                            icon: const Icon(
                              Icons.format_bold_rounded,
                              size: 17,
                            ),
                          ),
                          IconButton(
                            onPressed: _toggleItalic,
                            tooltip: 'Italic',
                            icon: const Icon(
                              Icons.format_italic_rounded,
                              size: 17,
                            ),
                          ),
                          IconButton(
                            onPressed: _toggleBullet,
                            tooltip: 'Bullet list',
                            icon: const Icon(
                              Icons.format_list_bulleted_rounded,
                              size: 17,
                            ),
                          ),
                          IconButton(
                            onPressed: _insertLink,
                            tooltip: 'Insert link',
                            icon: const Icon(Icons.link_rounded, size: 17),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: body,
                      minLines: 4,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        fillColor: Colors.transparent,
                        filled: true,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final notifyRow = ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: notify,
                            onChanged: (value) =>
                                setState(() => notify = value ?? false),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Flexible(
                          child: Text(
                            'Send push notification to mobile app',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  );

                  final buttons = [
                    OutlinedButton(
                      onPressed: loading ? null : () => save(true),
                      child: Text(
                        isEditMode ? 'Save as Draft' : 'Drafts',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: loading ? null : () => save(false),
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
                              size: 14,
                            ),
                      label: Text(
                        isEditMode ? 'Save Changes' : 'Send Announcement',
                        style: const TextStyle(fontSize: 11),
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
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: buttons,
                      ),
                    ],
                  );
                },
              ),
            ],
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

    // 1. Calculate imageRect: fit source into canvasSize with natural aspect ratio (NEVER STRETCHED)
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

    // 2. Initialize 2:1 cropRect inside imgRect
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
          content: Text(
            'The cropped image is over 50 MB. Reduce the crop area and try again.',
          ),
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
                              accentColor: colors.accent,
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
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.infoContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: colors.info.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.aspect_ratio_rounded,
                            size: 14,
                            color: colors.info,
                          ),
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
                      onPressed: () {
                        setState(() {
                          _lastCanvasSize = null;
                        });
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text(
                        'Reset Crop',
                        style: TextStyle(fontSize: 11),
                      ),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FutureBuilder<ui.Image>(
          future: _decodedImage,
          builder: (context, snapshot) => FilledButton.icon(
            onPressed:
                snapshot.hasData ? () => _confirmCrop(snapshot.data!) : null,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Apply Crop'),
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
    // 1. Draw source image into imageRect maintaining 100% true aspect ratio (NEVER STRETCHED)
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      imageRect,
      Paint()..filterQuality = FilterQuality.high,
    );

    // 2. Darkened scrim overlay outside cropRect
    final scrimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(cropRect);
    canvas.drawPath(
      scrimPath,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );

    // 3. Crisp white crop border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(cropRect, borderPaint);

    // 4. Rule of Thirds grid lines inside cropRect
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final thirdW = cropRect.width / 3.0;
    final thirdH = cropRect.height / 3.0;

    // Vertical grid lines
    canvas.drawLine(
      Offset(cropRect.left + thirdW, cropRect.top),
      Offset(cropRect.left + thirdW, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + thirdW * 2, cropRect.top),
      Offset(cropRect.left + thirdW * 2, cropRect.bottom),
      gridPaint,
    );

    // Horizontal grid lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdH),
      Offset(cropRect.right, cropRect.top + thirdH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdH * 2),
      Offset(cropRect.right, cropRect.top + thirdH * 2),
      gridPaint,
    );

    // 5. Gallery-style thick corner handles (L-shaped corner brackets)
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.square;

    const cornerLen = 20.0;

    // Top-Left
    canvas.drawLine(
      cropRect.topLeft,
      cropRect.topLeft + const Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      cropRect.topLeft,
      cropRect.topLeft + const Offset(0, cornerLen),
      cornerPaint,
    );

    // Top-Right
    canvas.drawLine(
      cropRect.topRight,
      cropRect.topRight - const Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      cropRect.topRight,
      cropRect.topRight + const Offset(0, cornerLen),
      cornerPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      cropRect.bottomLeft,
      cropRect.bottomLeft + const Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      cropRect.bottomLeft,
      cropRect.bottomLeft - const Offset(0, cornerLen),
      cornerPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      cropRect.bottomRight,
      cropRect.bottomRight - const Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      cropRect.bottomRight,
      cropRect.bottomRight - const Offset(0, cornerLen),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GalleryCropPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect ||
      oldDelegate.imageRect != imageRect ||
      oldDelegate.source != source;
}
