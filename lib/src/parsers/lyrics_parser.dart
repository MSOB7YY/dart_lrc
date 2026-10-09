// by claude
part of lrc;

/// Parses lyrics of any supported format. The format is guessed from the start of the content so only its parser runs,
/// the rest are tried in [_LyricsFormat] order only when that one fails, and plain text is rejected without running any.
class LyricsParser {
  static bool isValid(String content) {
    final guess = _guessFormat(content);
    if (guess != null && guess.isValid(content)) return true;
    if (!_mayHaveTimings(content)) return false;
    for (final format in _LyricsFormat.values) {
      if (format != guess && format.isValid(content)) return true;
    }
    return false;
  }

  /// Returns null when [content] has no timed lines in any supported format.
  static Lrc? parse(String content) {
    final guess = _guessFormat(content);
    if (guess != null) {
      final lrc = guess.tryParse(content);
      if (lrc != null) return lrc;
    }
    if (!_mayHaveTimings(content)) return null;
    for (final format in _LyricsFormat.values) {
      if (format == guess) continue;
      final lrc = format.tryParse(content);
      if (lrc != null) return lrc;
    }
    return null;
  }

  static _LyricsFormat? _guessFormat(String content) {
    final start = LrcParser._contentStart(content);
    if (start == content.length) return null;
    final first = content.codeUnitAt(start);
    if (first == 0x7B /* { */ || first == 0x5B /* [ */) {
      if (PaxsenixJsonParser._jsonStart(content) >= 0) return _LyricsFormat.paxsenixJson;
    }
    if (first == 0x3C /* < */) {
      final isQrcXml = content.contains(QrcParser._kXmlContentAttribute, start);
      return isQrcXml ? _LyricsFormat.qrc : _LyricsFormat.ttml;
    }
    final isSubtitle = _isDigit(first) || // srt, sbv
        content.startsWith('WEBVTT', start) ||
        content.startsWith('[Script Info]', start);
    if (isSubtitle) return _LyricsFormat.subtitle;
    if (first != 0x5B /* [ */) return null;

    final timingOpen = _indexOfTimingOpen(content, start);
    if (timingOpen < 0) return null;
    final qrcTiming = QrcParser._scanTiming(content, timingOpen + 1, 0x5D /* ] */);
    return qrcTiming.end >= 0 ? _LyricsFormat.qrc : _LyricsFormat.lrc;
  }

  /// Something every format needs before it can have a timed line, looked for in a single pass.
  static bool _mayHaveTimings(String content) {
    final length = content.length;
    for (var i = 0; i < length; i++) {
      final isTimingStart = switch (content.codeUnitAt(i)) {
        0x5B /* [ */ => i + 1 < length && _isDigit(content.codeUnitAt(i + 1)), // lrc, qrc
        0x2D /* - */ => content.startsWith('-->', i), // srt, vtt
        0x62 /* b */ => content.startsWith('begin', i), // ttml
        0x44 /* D */ => content.startsWith('Dialogue:', i), // ssa
        0x3A /* : */ => _isClockMinutesAt(content, i), // sbv
        _ => false,
      };
      if (isTimingStart) return true;
    }
    return false;
  }

  /// `[` followed by a digit.
  static int _indexOfTimingOpen(String content, int from) {
    final lastIndex = content.length - 1;
    var open = content.indexOf('[', from);
    while (open >= 0 && open < lastIndex) {
      final next = content.codeUnitAt(open + 1);
      if (_isDigit(next)) return open;
      open = content.indexOf('[', open + 1);
    }
    return -1;
  }

  /// `:mm:` of a `h:mm:ss` timestamp.
  static bool _isClockMinutesAt(String content, int colon) {
    if (colon + 3 >= content.length) return false;
    return _isDigit(content.codeUnitAt(colon + 1)) && _isDigit(content.codeUnitAt(colon + 2)) && content.codeUnitAt(colon + 3) == 0x3A /* : */;
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
}

/// Declared in the order [LyricsParser] falls back through.
enum _LyricsFormat {
  lrc,
  ttml,
  subtitle,
  paxsenixJson,
  qrc,
  ;

  bool isValid(String content) => switch (this) {
        _LyricsFormat.lrc => LrcParser.isValid(content),
        _LyricsFormat.ttml => TtmlParser.isValid(content),
        _LyricsFormat.subtitle => SubtitleParser.isValid(content),
        _LyricsFormat.paxsenixJson => PaxsenixJsonParser.isValid(content),
        _LyricsFormat.qrc => QrcParser.isValid(content),
      };

  /// Null when [content] is not of this format or has no lines.
  Lrc? tryParse(String content) {
    // -- not [TtmlParser.isValid], its xml extractor reads `<p>` elements that check misses
    if (this == _LyricsFormat.ttml && !content.contains('begin')) return null;
    try {
      final lrc = switch (this) {
        _LyricsFormat.lrc => LrcParser.parse(content),
        _LyricsFormat.ttml => TtmlParser.parse(content),
        _LyricsFormat.subtitle => SubtitleParser.parse(content),
        _LyricsFormat.paxsenixJson => PaxsenixJsonParser.parse(content),
        _LyricsFormat.qrc => QrcParser.parse(content),
      };
      if (lrc != null && lrc.lyrics.isNotEmpty) return lrc;
    } catch (_) {}
    return null;
  }
}
