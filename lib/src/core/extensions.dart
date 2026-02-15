part of lrc;

/// Handy extensions on lists of LrcLine
extension LrcLineExtensions on List<LrcLine> {
  /// Creates a stream for each lyric using their durations
  Stream<LrcStream> toStream() async* {
    for (var i = 0; i < length; i++) {
      var lineCurrent = this[i];
      var lineNext = (i + 1 < length) ? this[i + 1] : null;
      var durationToNext = (lineNext != null)
          ? Duration(
              milliseconds: lineNext.timestamp.inMilliseconds -
                  lineCurrent.timestamp.inMilliseconds)
          : null;
      yield LrcStream(
          duration: durationToNext,
          previous: (i != 0) ? this[i - 1] : null,
          current: lineCurrent,
          next: lineNext,
          position: i,
          length: length - 1);
      if (durationToNext != null) {
        await Future.delayed(durationToNext);
      }
    }
  }
}

extension LrcExtensions on Lrc {
  ({
    List<LrcLine> uiLyricsLines,
    Map<Duration, int> highlightTimestampsMap,
  }) forUiDisplay(
    double multiplier, {
    Duration durationDifferenceToInsertEmptyLine = const Duration(seconds: 1),
    bool romanize = false,
  }) {
    final originalLyrics = lyrics;
    final offset = this.offset ?? 0;
    final uiLyricsLines = <LrcLine>[];
    final highlightTimestampsMap = <Duration, int>{}; // timestamp: index
    var indexExtra = 0;
    for (var index = 0; index < originalLyrics.length; index++) {
      final item = originalLyrics[index];

      final lineTimeStamp = item.timestamp - Duration(milliseconds: offset);
      final calculatedForSpedUpVersions =
          multiplier == 0 ? lineTimeStamp : (lineTimeStamp * multiplier);
      final newLrcLine =
          item.withTimeStamp(newTimestamp: calculatedForSpedUpVersions);
      highlightTimestampsMap[calculatedForSpedUpVersions] ??=
          index + indexExtra;
      uiLyricsLines.add(newLrcLine);
      final parts = newLrcLine.parts;
      if (parts != null) {
        try {
          final nextLine = index == originalLyrics.length - 1
              ? null
              : originalLyrics[index + 1];
          if (nextLine != null) {
            final partEndTimestamp = parts.last.endTimestamp;
            if ((nextLine.timestamp - partEndTimestamp) >
                durationDifferenceToInsertEmptyLine) {
              // -- insert empty line to allow dynamic lrc view to hide lrc during long transitions
              indexExtra++;
              final emptyLineIndex = index + indexExtra;

              uiLyricsLines.add(
                LrcLine(
                  timestamp: partEndTimestamp,
                  originalIndex: emptyLineIndex + 0.1,
                  lyrics: '',
                  readableText: '',
                  type: LrcTypes.simple,
                  parts: const [],
                  person: null,
                ),
              );
              highlightTimestampsMap[partEndTimestamp] ??= emptyLineIndex;
            }
          }
        } catch (_) {}
      }
      if (romanize) {
        final romanized = _romanized(item, index, calculatedForSpedUpVersions);
        if (romanized != null) {
          uiLyricsLines.add(romanized);
        }
      }
    }
    return (
      uiLyricsLines: uiLyricsLines,
      highlightTimestampsMap: highlightTimestampsMap,
    );
  }
}

const _kanaKit = KanaKit(
  config: KanaKitConfig(
    passRomaji: true,
    passKanji: false,
    upcaseKatakana: true,
  ),
);

String? _toRomajiOrNull(String txt) {
  if (txt.isNotEmpty) {
    return _kanaKit.toRomaji(txt);
  }
  return null;
}

String _toRomajiOrOriginal(String txt) {
  return _toRomajiOrNull(txt) ?? txt;
}

LrcLine? _romanized(LrcLine line, int index, Duration lineTimestamp) {
  LrcLine? romanizedLine;
  final parts = line.parts;
  if (parts != null && parts.isNotEmpty) {
    var hasRomajiPart = false;
    final romanizedParts = <LrcLinePart>[];
    for (final p in parts) {
      final romanizedPart = _toRomajiOrNull(p.lyrics);
      if (romanizedPart != null && romanizedPart != p.lyrics) {
        hasRomajiPart = true;
      }
      // -- always add to retain order
      romanizedParts.add(
        LrcLinePart(
          startTimestamp: p.startTimestamp,
          endTimestamp: p.endTimestamp,
          lyrics: romanizedPart ?? p.lyrics,
        ),
      );
    }
    if (hasRomajiPart) {
      romanizedLine = LrcLine(
        timestamp: lineTimestamp,
        originalIndex: index - 0.1,
        lyrics: _toRomajiOrOriginal(line.lyrics),
        readableText: romanizedParts.map((e) => e.lyrics).join(),
        type: line.type,
        parts: romanizedParts,
        person: line.person,
      );
    }
  } else {
    final txt = line.lyrics;
    final romanized = _toRomajiOrNull(txt);
    if (romanized != null && romanized != txt) {
      romanizedLine = LrcLine(
        timestamp: lineTimestamp,
        originalIndex: index - 0.1,
        lyrics: romanized,
        readableText: romanized,
        type: line.type,
        parts: parts,
        person: line.person,
      );
    }
  }

  return romanizedLine;
}

/// Handy extensions on strings
extension StringExtensions on String {
  /// Handy extension method that parses the string to an [Lrc]
  Lrc toLrc() => LrcParser.parse(this);

  /// Handy extension getter if the given string is a valid LRC
  bool get isValidLrc => LrcParser.isValid(this);
}

extension LrcFileExtensions on File {
  String readLrcStringSync() {
    try {
      return readAsStringSync(encoding: utf8);
    } on FileSystemException catch (_) {
      try {
        return readAsStringSync(encoding: utf16);
      } catch (_) {}
    }
    return '';
  }

  Future<String> readLrcString() async {
    try {
      return await readAsString(encoding: utf8);
    } on FileSystemException catch (_) {
      try {
        return await readAsString(encoding: utf16);
      } catch (_) {}
    }
    return '';
  }
}
