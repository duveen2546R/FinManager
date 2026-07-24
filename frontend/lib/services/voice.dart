import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

// Voice input (speech_to_text) wrapper that fails gracefully when the native
// speech module isn't available on the device.
class VoiceInput {
  static final SpeechToText _speech = SpeechToText();
  static bool _available = false;
  static bool _initialized = false;

  static bool get isAvailable => _available;

  // Must be awaited once before start(); safe to call repeatedly.
  static Future<bool> init() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _speech.initialize(
        onStatus: (_) {},
        onError: (_) {},
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  // Start listening. onResult receives (partial + final) transcripts,
  // onEnd fires when recognition stops.
  static Future<void> start({
    required void Function(String transcript) onResult,
    required void Function() onEnd,
  }) async {
    if (!_available) return;
    try {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
          if (result.finalResult) onEnd();
        },
        listenOptions:
            SpeechListenOptions(partialResults: true, localeId: 'en_US'),
      );
    } catch (_) {
      onEnd();
    }
  }

  static Future<void> stop() async {
    if (!_available) return;
    try {
      await _speech.stop();
    } catch (_) {}
  }
}

// Text-to-speech for spoken AI replies.
class TtsService {
  static final FlutterTts _tts = FlutterTts();

  static Future<void> speak(String text) async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  static Future<void> stop() async {
    await _tts.stop();
  }
}
