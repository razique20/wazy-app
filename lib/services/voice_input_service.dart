import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Status of a voice recognition session.
enum VoiceStatus {
  /// Recognizer is idle, no session active.
  idle,

  /// User granted / confirmed permission; listening has begun.
  listening,

  /// Microphone picked up sound and words are arriving.
  detected,

  /// Session ended (user tap, 30s auto-stop, or error after partial results).
  stopped,

  /// Permanent failure: permission denied, recognizer unavailable, or
  /// platform error. [VoiceInputService.lastError] holds a human message.
  unavailable,
}

/// A single live transcription update emitted by [VoiceInputService].
class VoiceUpdate {
  /// Words confirmed by the recognizer so far.
  final String text;

  /// Unconfirmed partial words still being revised.
  final String partialText;

  /// True while the session is active.
  final bool isListening;

  const VoiceUpdate({
    required this.text,
    required this.partialText,
    required this.isListening,
  });
}

/// Hands-free natural language quick add via voice.
///
/// Wraps the `speech_to_text` plugin and post-processes transcripts so the
/// downstream [NaturalLanguageParserService] can parse them: iOS/Android
/// recognizers frequently transcribe spoken amounts as words ("four hundred
/// fifty dirhams") or drop punctuation, so [normalizeTranscript] converts
/// word-numbers to digits, spelled currency to "AED", and tidies spacing.
class VoiceInputService {
  VoiceInputService._();

  static final VoiceInputService instance = VoiceInputService._();

  /// Injectable factory for tests — lets unit tests stub the plugin layer.
  @visibleForTesting
  SpeechToText speechToTextFactory() => SpeechToText();

  SpeechToText? _stt;
  bool _available = false;
  VoiceStatus _currentStatus = VoiceStatus.idle;

  /// Latest human-readable failure message, for snackbars/tooltips.
  String? lastError;

  final StreamController<VoiceStatus> _statusController =
      StreamController<VoiceStatus>.broadcast();

  final StreamController<VoiceUpdate> _transcriptController =
      StreamController<VoiceUpdate>.broadcast();

  /// Broadcast stream of status transitions.
  Stream<VoiceStatus> get statusStream => _statusController.stream;

  /// Broadcast stream of live transcript updates.
  Stream<VoiceUpdate> get transcriptStream => _transcriptController.stream;

  VoiceStatus get status => _currentStatus;

  bool get isListening => _currentStatus == VoiceStatus.listening ||
      _currentStatus == VoiceStatus.detected;

  /// Ensure the recognizer is initialized and permission granted.
  Future<bool> initialize() async {
    if (_stt != null && _available) return true;
    try {
      _stt ??= speechToTextFactory();
      _available = await _stt!.initialize(
        onError: (error) {
          lastError = error.errorMsg;
          _setStatus(VoiceStatus.unavailable);
        },
        onStatus: (st) {
          // Platform reports 'done'/'notListening' when the session ends.
          if ((st == 'done' || st == 'notListening') && isListening) {
            _setStatus(VoiceStatus.stopped);
          }
        },
      );
      if (!_available) {
        lastError = 'Speech recognition is not available on this device.';
        _currentStatus = VoiceStatus.unavailable;
      }
      return _available;
    } catch (e) {
      lastError = 'Could not start speech recognition: $e';
      _currentStatus = VoiceStatus.unavailable;
      return false;
    }
  }

  /// Begin listening. Returns true when a session actually started.
  ///
  /// [localeId] optionally pins the recognition locale (e.g. 'en_AE');
  /// defaults to the device locale.
  Future<bool> startListening({String? localeId}) async {
    if (isListening) return true;
    if (!await initialize()) return false;

    _setStatus(VoiceStatus.listening);
    try {
      await _stt!.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (result.finalResult) {
            // Final, confirmed transcription for this session.
            if (words.isNotEmpty && _currentStatus == VoiceStatus.listening) {
              _setStatus(VoiceStatus.detected);
            }
            _transcriptController.add(VoiceUpdate(
              text: words,
              partialText: '',
              isListening: false,
            ));
            _setStatus(VoiceStatus.stopped);
          } else if (words.isNotEmpty) {
            // Live partial; plugin semantics: recognizedWords replaces each tick.
            if (_currentStatus == VoiceStatus.listening) {
              _setStatus(VoiceStatus.detected);
            }
            _transcriptController.add(VoiceUpdate(
              text: '',
              partialText: words,
              isListening: true,
            ));
          }
        },
        localeId: localeId,
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
      );
      return true;
    } catch (e) {
      lastError = 'Could not start listening: $e';
      _setStatus(VoiceStatus.unavailable);
      return false;
    }
  }

  void _setStatus(VoiceStatus s) {
    if (_currentStatus == s) return;
    _currentStatus = s;
    if (!_statusController.isClosed) {
      _statusController.add(s);
    }
  }

  /// Manually end the session (user tapped stop / tapped mic again).
  Future<void> stopListening() async {
    if (!isListening) return;
    try {
      await _stt?.stop();
    } finally {
      _setStatus(VoiceStatus.stopped);
    }
  }

  /// Fully cancel the session and discard pending partial text.
  Future<void> cancel() async {
    try {
      await _stt?.cancel();
    } finally {
      _setStatus(VoiceStatus.stopped);
    }
  }

  // --------------------------------------------------------------------------
  // Transcript normalization: spoken numbers & currency → parser-friendly text
  // --------------------------------------------------------------------------

  /// English word → digit mapping used to normalize speech transcripts.
  static const Map<String, int> _wordNumbers = {
    'zero': 0, 'oh': 0,
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
    'seven': 7, 'eight': 8, 'nine': 9,
    'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19,
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
    'seventy': 70, 'eighty': 80, 'ninety': 90,
  };

  static const Map<String, int> _wordMultipliers = {
    'hundred': 100, 'thousand': 1000, 'k': 1000, 'million': 1000000,
    'lakh': 100000, 'crore': 10000000,
  };

  /// Regex covering word-numbers, multipliers and compound numerals.
  ///
  /// The leading token must be a number word; subsequent tokens may also be
  /// the connector "and" ("four hundred and fifty"). The trailing \b keeps
  /// this from matching inside longer words ("onions" contains "one").
  static final RegExp _numberPhrase = RegExp(
    r'\b((?:zero|oh|one|two|three|four|five|six|seven|eight|nine|ten|eleven|'
    r'twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|'
    r'twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|'
    r'million|lakh|crore|k)(?:[\s-]*(?:zero|oh|one|two|three|four|five|six|'
    r'seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|'
    r'seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|'
    r'eighty|ninety|hundred|thousand|million|lakh|crore|k|and))*)\b',
    caseSensitive: false,
  );

  /// Normalizes a raw speech transcript into text the NL parser understands:
  /// word-numbers → digits ("four hundred fifty" → "450"),
  /// "dirhams/dirham/dhs/dh" → "AED", hyphens between number words collapsed,
  /// and whitespace collapsed.
  static String normalizeTranscript(String transcript) {
    var text = transcript.trim();
    if (text.isEmpty) return text;

    // 1. Collapse hyphens between number words ("forty-five" → "forty five").
    //    Replacement keeps the captured number word ('forty') and drops only
    //    the hyphen; a plain ' ' replacement would erase the word itself.
    text = text.replaceAllMapped(
      RegExp(
        r'(\b(?:zero|oh|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|lakh|crore|k))\s*-\s*(?=(?:zero|oh|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|lakh|crore|k)\b)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)} ',
    );

    // 2. Convert word-number phrases to digits.
    text = text.replaceAllMapped(_numberPhrase, (m) {
      final value = parseWordNumber(m.group(1)!);
      return value == null ? m.group(0)! : '$value';
    });

    // 3. Spelled currency → AED (before digit-conversion so "forty dirhams"
    //    becomes "40 dirhams" then "40 AED").
    text = text.replaceAll(
      RegExp(r'\b(dirhams|dirham|dhs|dhms|dhm)\b', caseSensitive: false),
      'AED',
    );

    // 4. Collapse whitespace and tidy punctuation spacing.
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// Parses a word-number phrase ("four hundred fifty", "two thousand", etc.)
  /// to its integer value. Returns null when tokens are not numeric words.
  static int? parseWordNumber(String phrase) {
    final tokens =
        phrase.toLowerCase().split(RegExp(r'[\s-]+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;

    var total = 0;
    var current = 0;
    var sawNumberWord = false;

    for (final token in tokens) {
      if (token == 'and') {
        // British-style connector: "four hundred and fifty". Only valid
        // between number words.
        if (!sawNumberWord) return null;
        continue;
      }
      if (_wordNumbers.containsKey(token)) {
        current += _wordNumbers[token]!;
        sawNumberWord = true;
      } else if (_wordMultipliers.containsKey(token)) {
        final multiplier = _wordMultipliers[token]!;
        if (multiplier >= 100) {
          if (current == 0) current = 1; // "hundred" alone
          total += current * multiplier;
          current = 0;
        }
        sawNumberWord = true;
      } else {
        return null; // non-numeric token — not a number phrase
      }
    }

    if (!sawNumberWord) return null;
    return total + current;
  }
}
