part of lrc;

/// Parses Multi-timestamped lyrics lines effectively.
class _LRCMultiTimestampParser {
  const _LRCMultiTimestampParser();

  /// supports 2-digit minutes, 2-digit seconds & optional 1-2-3-digit hundreds.
  static final _durRegex =
      RegExp(r'\[([0-9]{1,}):(\d{1,})(\.[0-9]{1,})?\]\s*(.*)?');

  static String? extractMainTimestamp(String line) {
    final m = _durRegex.firstMatch(line);
    if (m == null) return null;
    try {
      final minutes = m.group(1);
      if (minutes != null) {
        final seconds = m.group(2) ?? '00';
        final hundreds = m.group(3) ?? '00';
        return '$minutes:$seconds$hundreds';
      }
    } catch (_) {}
    return null;
  }

  /// Converts multi-timestamped lyrics lines into a pair of `lineText` & `timestamps` list
  static _MultiTimeStampDetails parseLine(String line) {
    var lineText = line;
    final timestamps = <Duration>[];

    while (true) {
      final m = _durRegex.firstMatch(lineText);
      if (m != null && m.group(1) != null) {
        final timestamp = _durationFromStrings(
          minutes: m.group(1),
          seconds: m.group(2),
          hundreds: m.group(3)?.substring(1),
        );
        timestamps.add(timestamp);
        lineText = m.group(4) ?? '';
        if (lineText.isEmpty) break;
      } else {
        break;
      }
    }

    return _MultiTimeStampDetails.trimmed(
      lineText: lineText,
      timestamps: timestamps,
    );
  }

  static Duration _durationFromStrings({
    required String? minutes,
    required String? seconds,
    required String? hundreds,
  }) {
    if (hundreds != null) {
      var zerosToAdd = 6 - hundreds.length;
      while (zerosToAdd > 0) {
        hundreds = hundreds! + '0';
        zerosToAdd--;
      }
    }

    final m = minutes == null ? null : int.tryParse(minutes);
    final s = seconds == null ? null : int.tryParse(seconds);
    final micros = hundreds == null ? null : int.tryParse(hundreds);

    return Duration(
      minutes: m ?? 0,
      seconds: s ?? 0,
      microseconds: micros ?? 0,
    );
  }
}

class _MultiTimeStampDetails {
  final String lineText;
  final List<Duration> timestamps;

  _MultiTimeStampDetails.trimmed({
    required String lineText,
    required this.timestamps,
  }) : lineText = lineText.trim();
}
