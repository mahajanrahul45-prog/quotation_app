import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Future<Uint8List?> captureBrowserPhoto(
  BuildContext context,
  String Function(String) translate,
) => showDialog<Uint8List>(
  context: context,
  builder: (_) => _BrowserCamera(translate: translate),
);

class _BrowserCamera extends StatefulWidget {
  const _BrowserCamera({required this.translate});
  final String Function(String) translate;
  @override
  State<_BrowserCamera> createState() => _BrowserCameraState();
}

class _BrowserCameraState extends State<_BrowserCamera> {
  web.MediaStream? _stream;
  web.HTMLVideoElement? _video;
  bool _ready = false;
  String? _error;
  String t(String text) => widget.translate(text);

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  static void _stop(web.MediaStream stream) {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  Future<void> _open() async {
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              video: {
                'facingMode': {'ideal': 'environment'},
              }.jsify()!,
              audio: false.toJS,
            ),
          )
          .toDart;
      if (!mounted) {
        _stop(stream);
        return;
      }
      _stream = stream;
      await _play();
    } catch (_) {
      _failed();
    }
  }

  void _failed() {
    final stream = _stream;
    if (stream != null) _stop(stream);
    _stream = null;
    _video?.pause();
    _video?.srcObject = null;
    if (mounted) {
      setState(
        () => _error = t(
          'Could not open the camera. Allow camera access in your browser, or choose a photo from your library.',
        ),
      );
    }
  }

  Future<void> _play() async {
    final video = _video;
    final stream = _stream;
    if (video == null || stream == null || !mounted) return;
    try {
      video.srcObject = stream;
      await video.play().toDart;
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      _failed();
    }
  }

  void _capture() {
    final video = _video;
    if (video == null || video.videoWidth == 0 || video.videoHeight == 0) {
      return;
    }
    final canvas = web.HTMLCanvasElement();
    canvas.width = math.min(1024, video.videoWidth);
    canvas.height = (canvas.width * video.videoHeight / video.videoWidth)
        .round();
    final drawing = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    drawing.drawImage(video, 0, 0, canvas.width, canvas.height);
    final bytes = base64Decode(canvas.toDataURL('image/png').split(',').last);
    Navigator.pop(context, bytes);
  }

  @override
  void dispose() {
    _video?.pause();
    _video?.srcObject = null;
    final stream = _stream;
    if (stream != null) _stop(stream);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t('Take photo')),
    content: SizedBox(
      width: 560,
      child: _error != null
          ? Text(_error!)
          : AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  HtmlElementView.fromTagName(
                    tagName: 'video',
                    onElementCreated: (element) {
                      final video = element as web.HTMLVideoElement;
                      video.muted = true;
                      video.autoplay = true;
                      video.setAttribute('playsinline', '');
                      video.style.width = '100%';
                      video.style.height = '100%';
                      video.style.objectFit = 'contain';
                      _video = video;
                      unawaited(_play());
                    },
                  ),
                  if (!_ready) Center(child: Text(t('Opening camera...'))),
                ],
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t('Cancel')),
      ),
      FilledButton.icon(
        onPressed: _ready && _error == null ? _capture : null,
        icon: const Icon(Icons.camera_alt),
        label: Text(t('Capture photo')),
      ),
    ],
  );
}
