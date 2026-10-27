import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/service_report_language.dart';
import '../utils/browser_camera_stub.dart'
    if (dart.library.js_interop) '../utils/browser_camera_web.dart'
    as camera;

/// One portable evidence photo for an inspection point.
class InspectionPhoto extends StatefulWidget {
  const InspectionPhoto({
    super.key,
    required this.photoBase64,
    required this.onChanged,
    required this.point,
    required this.languageCode,
  });
  final String photoBase64, point, languageCode;
  final ValueChanged<String> onChanged;
  @override
  State<InspectionPhoto> createState() => _InspectionPhotoState();
}

class _InspectionPhotoState extends State<InspectionPhoto> {
  bool _busy = false;
  String t(String text) =>
      ServiceReportLanguage(widget.languageCode).text(text);
  Uint8List? get _bytes {
    try {
      return widget.photoBase64.isEmpty
          ? null
          : base64Decode(widget.photoBase64);
    } on FormatException {
      return null;
    }
  }

  Future<void> _pick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(t('Inspection photo')),
              subtitle: Text(t(widget.point)),
            ),
            if (kIsWeb ||
                [
                  TargetPlatform.android,
                  TargetPlatform.iOS,
                ].contains(defaultTargetPlatform))
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(t('Take photo')),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t('Choose from library')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _busy = true);
    try {
      Uint8List? bytes;
      if (kIsWeb && source == ImageSource.camera) {
        bytes = await camera.captureBrowserPhoto(context, t);
      } else {
        final image = await ImagePicker().pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 75,
        );
        bytes = await image?.readAsBytes();
      }
      if (bytes == null) return;
      // Normalize to PNG so saved photos work in both PDF renderers.
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 800,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null || data.lengthInBytes > 2 * 1024 * 1024) {
            throw StateError(t('Photo is too large. Choose a smaller image.'));
          }
          if (mounted) {
            widget.onChanged(
              base64Encode(
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              ),
            );
          }
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('Could not attach photo')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _preview(Uint8List bytes) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t(widget.point),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: t('Close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text(t('Could not load photo')),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : _pick,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    bytes == null
                        ? Icons.add_photo_alternate_outlined
                        : Icons.photo_camera_outlined,
                  ),
            label: Text(t(bytes == null ? 'Add photo' : 'Replace photo')),
          ),
        ),
        if (bytes != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label: '${t('View photo')}: ${t(widget.point)}',
                  button: true,
                  child: InkWell(
                    onTap: () => _preview(bytes),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        bytes,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => SizedBox(
                          height: 80,
                          child: Center(child: Text(t('Could not load photo'))),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: t('Remove photo'),
                onPressed: _busy ? null : () => widget.onChanged(''),
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
