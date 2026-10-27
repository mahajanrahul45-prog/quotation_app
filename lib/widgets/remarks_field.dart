import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// One recognizer per application; only the active field receives its results.
class RemarksDictation {
  static final instance = RemarksDictation();
  final speech = SpeechToText();
  VoidCallback? statusChanged;
  void Function(String)? error;
  Object? owner;
  Future<bool> initialize() => speech.initialize(
    onStatus: (_) => statusChanged?.call(),
    onError: (e) => error?.call(e.errorMsg),
  );
  Future<void> release(Object target) async {
    if (owner != target) return;
    final notifyPrevious = statusChanged;
    owner = null;
    statusChanged = null;
    error = null;
    notifyPrevious?.call();
    await speech.cancel();
  }
}

class RemarksField extends StatefulWidget {
  const RemarksField({
    super.key,
    this.controller,
    this.initialValue = '',
    required this.label,
    this.languageCode = 'en',
    this.onChanged,
    this.minLines = 1,
    this.maxLines = 3,
    this.enabled = true,
  });
  final TextEditingController? controller;
  final String initialValue, label, languageCode;
  final ValueChanged<String>? onChanged;
  final int minLines, maxLines;
  final bool enabled;
  @override
  State<RemarksField> createState() => _RemarksFieldState();
}

class _RemarksFieldState extends State<RemarksField> {
  late final _controller =
      widget.controller ?? TextEditingController(text: widget.initialValue);
  final _focus = FocusNode();
  final _dictation = RemarksDictation.instance;
  bool _starting = false;
  bool get _listening =>
      _dictation.owner == this && _dictation.speech.isListening;
  bool get _hindi => widget.languageCode == 'hi';
  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) unawaited(_dictation.release(this));
    });
  }

  @override
  void didUpdateWidget(RemarksField old) {
    super.didUpdateWidget(old);
    if (old.languageCode != widget.languageCode) {
      unawaited(_dictation.release(this));
    }
    if (widget.controller == null &&
        old.initialValue != widget.initialValue &&
        !_listening) {
      _controller.text = widget.initialValue;
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _toggle() async {
    if (_starting) return;
    if (_listening) {
      await _dictation.speech.stop();
      if (mounted) setState(() {});
      return;
    }
    setState(() => _starting = true);
    try {
      if (_dictation.owner != null) await _dictation.release(_dictation.owner!);
      if (!mounted) return;
      _dictation.owner = this;
      _dictation.statusChanged = () {
        if (mounted) setState(() {});
      };
      _dictation.error = (_) => _message(
        _hindi
            ? 'आवाज़ नहीं पहचानी गई। माइक्रोफ़ोन की अनुमति और भाषा जाँचें, फिर दोबारा प्रयास करें।'
            : 'Could not recognize speech. Check microphone permission and speech language, then try again.',
      );
      if (!await _dictation.initialize()) {
        _message(
          _hindi
              ? 'आवाज़ से लिखना उपलब्ध नहीं है। माइक्रोफ़ोन की अनुमति दें या कीबोर्ड से लिखें।'
              : 'Dictation unavailable. Allow microphone access or continue typing. On Windows you can also use Win+H.',
        );
        return;
      }
      if (!mounted || _dictation.owner != this) return;
      final locales = await _dictation.speech.locales();
      final language = widget.languageCode;
      final candidates = locales
          .where(
            (l) =>
                l.localeId
                    .replaceAll('_', '-')
                    .toLowerCase()
                    .startsWith('$language-') ||
                l.localeId == language,
          )
          .toList();
      if (candidates.isEmpty) {
        _message(
          _hindi
              ? 'इस डिवाइस में हिंदी आवाज़ पहचान उपलब्ध नहीं है। हिंदी भाषा स्थापित करें या लिखें।'
              : 'English speech recognition is unavailable on this device. Install an English speech language or type your remarks.',
        );
        return;
      }
      final locale =
          candidates
              .where(
                (l) =>
                    l.localeId.replaceAll('_', '-').toLowerCase() ==
                    '$language-in',
              )
              .firstOrNull ??
          candidates.first;
      _focus.requestFocus();
      final original = _controller.text;
      final selection = _controller.selection;
      final start = selection.isValid ? selection.start : original.length;
      final end = selection.isValid ? selection.end : original.length;
      final before = original.substring(0, start),
          after = original.substring(end);
      await _dictation.speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: locale.localeId,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!mounted ||
              _dictation.owner != this ||
              result.recognizedWords.isEmpty) {
            return;
          }
          final prefix =
              before.isNotEmpty &&
                  !before.endsWith(' ') &&
                  !before.endsWith('\n')
              ? '$before '
              : before;
          final suffix = after.isNotEmpty && !after.startsWith(' ')
              ? ' $after'
              : after;
          final value = '$prefix${result.recognizedWords}$suffix';
          _controller.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(
              offset: prefix.length + result.recognizedWords.length,
            ),
          );
          widget.onChanged?.call(value);
        },
      );
    } catch (_) {
      _message(
        _hindi
            ? 'आवाज़ से लिखना शुरू नहीं हो सका। अनुमति जाँचें या कीबोर्ड से लिखें।'
            : 'Could not start dictation. Check permissions or continue typing.',
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void dispose() {
    // Do not call this State's listener while it is being unmounted.
    if (_dictation.owner == this) _dictation.statusChanged = null;
    unawaited(_dictation.release(this));
    _focus.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _controller,
    focusNode: _focus,
    enabled: widget.enabled,
    readOnly: _listening,
    minLines: widget.minLines,
    maxLines: widget.maxLines,
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      labelText: widget.label,
      border: const OutlineInputBorder(),
      helperText: _listening
          ? (_hindi
                ? 'सुन रहे हैं… रोकने के लिए माइक्रोफ़ोन दबाएँ'
                : 'Listening… tap microphone to stop')
          : null,
      suffixIcon: IconButton(
        tooltip: _listening
            ? (_hindi ? 'सुनना रोकें' : 'Stop dictation')
            : (_hindi ? 'बोलकर लिखें' : 'Tap to dictate'),
        onPressed: widget.enabled && !_starting ? _toggle : null,
        color: _listening ? Theme.of(context).colorScheme.error : null,
        icon: _starting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none),
      ),
    ),
  );
}
