part of lrc;

// optimizations by claude
/// Parses Multi-timestamped lyrics lines effectively.
class _LRCMultiTimestampParser {
  const _LRCMultiTimestampParser();

  static const _ScannedTimestamp _kNoTimestamp = (end: -1, micros: 0);

  static Duration? extractMainTimestamp(String line) {
    final (:end, :micros) = _findLineTimestamp(line, 0);
    if (end < 0) return null;
    return Duration(microseconds: micros);
  }

  /// Converts multi-timestamped lyrics lines into a pair of `lineText` & `timestamps` list
  static _MultiTimeStampDetails? parseLine(String line) {
    List<Duration>? timestamps;
    var textStart = 0;
    while (true) {
      final (:end, :micros) = _findLineTimestamp(line, textStart);
      if (end < 0) break;
      (timestamps ??= <Duration>[]).add(Duration(microseconds: micros));
      textStart = end;
    }
    if (timestamps == null) return null;

    return _MultiTimeStampDetails.trimmed(
      lineText: line.substring(textStart),
      timestamps: timestamps,
    );
  }

  static _ScannedTimestamp _findLineTimestamp(String line, int from) {
    var open = line.indexOf('[', from);
    while (open >= 0) {
      final scanned = _scanTimestamp(line, open + 1, 0x5D /* ] */);
      if (scanned.end >= 0) return scanned;
      open = line.indexOf('[', open + 1);
    }
    return _kNoTimestamp;
  }

  /// `mm:ss` or `mm:ss.fraction` starting at [start], closed by [closeCodeUnit].
  static _ScannedTimestamp _scanTimestamp(String s, int start, int closeCodeUnit) {
    final length = s.length;
    var i = start;
    var minutes = 0;
    while (i < length) {
      final digit = s.codeUnitAt(i) - 0x30;
      if (digit < 0 || digit > 9) break;
      minutes = minutes * 10 + digit;
      i++;
    }
    if (i == start || i >= length || s.codeUnitAt(i) != 0x3A /* : */) return _kNoTimestamp;

    final secondsStart = ++i;
    var seconds = 0;
    while (i < length) {
      final digit = s.codeUnitAt(i) - 0x30;
      if (digit < 0 || digit > 9) break;
      seconds = seconds * 10 + digit;
      i++;
    }
    if (i == secondsStart || i >= length) return _kNoTimestamp;

    var fractionMicros = 0;
    if (s.codeUnitAt(i) == 0x2E /* . */) {
      final fractionStart = ++i;
      var fraction = 0;
      while (i < length) {
        final digit = s.codeUnitAt(i) - 0x30;
        if (digit < 0 || digit > 9) break;
        if (i - fractionStart < 6) fraction = fraction * 10 + digit;
        i++;
      }
      final fractionLength = i - fractionStart;
      if (fractionLength == 0 || i >= length) return _kNoTimestamp;
      fractionMicros = fractionLength >= 6 ? fraction : fraction * _microsScale[fractionLength];
    }
    if (s.codeUnitAt(i) != closeCodeUnit) return _kNoTimestamp;

    final micros = minutes * Duration.microsecondsPerMinute + seconds * Duration.microsecondsPerSecond + fractionMicros;
    return (end: i + 1, micros: micros);
  }

  static const _microsScale = [1000000, 100000, 10000, 1000, 100, 10];
}

class _MultiTimeStampDetails {
  final String lineText;
  final List<Duration> timestamps;

  _MultiTimeStampDetails.trimmed({
    required String lineText,
    required this.timestamps,
  }) : lineText = lineText.trim();
}

typedef _ScannedTimestamp = ({int end, int micros});
