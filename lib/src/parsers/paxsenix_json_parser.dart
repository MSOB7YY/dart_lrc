// by claude
part of lrc;

/// Parses the syllable synced json lyrics served by the paxsenix lyrics api (Lyrically, SongSync),
/// either the list of lines alone or the whole response holding it in `content`.
///
/// A line is `{text: [{text, part, timestamp, endtime}], background, backgroundText, agent, timestamp, endtime}`
/// with times in milliseconds, `part` marks a syllable that the next one continues without a space.
class PaxsenixJsonParser {
  /// Cheap check that doesn't decode, [parse] can still return null.
  static bool isValid(String content) {
    final start = _jsonStart(content);
    return start >= 0 && content.contains('"endtime"', start);
  }

  /// Returns null if [content] is not json of this shape or has no lines.
  static Lrc? parse(String content) {
    final start = _jsonStart(content);
    if (start < 0) return null;
    final source = start == 0 ? content : content.substring(start);
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (_) {
      return null;
    }
    final rawLines = decoded is Map ? decoded['content'] : decoded;
    if (rawLines is! List) return null;
    final isWordSynced = decoded is! Map || decoded['type'] != 'Line';

    final lyrics = <LrcLine>[];
    final backgroundWordsLists = <List>[];
    final persons = <int>{};
    var latestTimestamp = Duration.zero;
    var shouldSortLyrics = false;

    void addLine(LrcLine line) {
      final timestamp = line.timestamp;
      if (timestamp < latestTimestamp) shouldSortLyrics = true;
      latestTimestamp = timestamp;
      lyrics.add(line);
    }

    for (final rawLine in rawLines) {
      if (rawLine is! Map) continue;
      final words = rawLine['text'];
      if (words is! List) continue;
      final backgroundWords = rawLine['backgroundText'];
      if (backgroundWords is List && backgroundWords.isNotEmpty) backgroundWordsLists.add(backgroundWords);
      // -- lines without `backgroundText` mark themselves as background vocals instead
      final isBackgroundLine = backgroundWords == null && rawLine['background'] == true;
      final agent = rawLine['agent'];
      final person = isBackgroundLine ? 0 : _agentToPerson(agent);
      final lineStartMS = rawLine['timestamp'];
      final line = _buildLine(words, lineStartMS, person, isWordSynced, lyrics.length);
      if (line == null) continue;
      if (person != null && person > 0) persons.add(person);
      addLine(line);
    }
    for (final backgroundWords in backgroundWordsLists) {
      final line = _buildLine(backgroundWords, null, 0, true, lyrics.length);
      if (line != null) addLine(line);
    }
    if (lyrics.isEmpty) return null;

    if (shouldSortLyrics) lyrics.sort(LrcParser._compareLines);

    final personCount = persons.isEmpty ? 1 : persons.length;
    return Lrc(
      type: isWordSynced ? LrcTypes.enhanced : LrcTypes.simple,
      lyrics: lyrics,
      personCount: personCount,
    );
  }

  static LrcLine? _buildLine(List words, Object? lineStartMS, int? person, bool isWordSynced, int originalIndex) {
    final parts = <LrcLinePart>[];
    final readableBuffer = StringBuffer();
    final taggedBuffer = isWordSynced ? StringBuffer() : null;
    final lastIndex = words.length - 1;
    for (var i = 0; i <= lastIndex; i++) {
      final word = words[i];
      if (word is! Map) continue;
      if (word case {'text': String text, 'timestamp': int startMS, 'endtime': int endMS}) {
        final isJoinedToNext = i == lastIndex || word['part'] == true;
        final lyrics = isJoinedToNext ? text : '$text ';
        readableBuffer.write(lyrics);
        taggedBuffer?.write('<${SubtitleParser._msToInlineTimestamp(startMS)}>');
        taggedBuffer?.write(lyrics);
        parts.add(LrcLinePart(
          startTimestamp: Duration(milliseconds: startMS),
          endTimestamp: Duration(milliseconds: endMS),
          lyrics: lyrics,
        ));
      }
    }
    if (parts.isEmpty) return null;

    final lastEndMS = parts.last.endTimestamp.inMilliseconds;
    taggedBuffer?.write('<${SubtitleParser._msToInlineTimestamp(lastEndMS)}>');
    final readableText = readableBuffer.toString();
    final lyrics = taggedBuffer?.toString() ?? readableText;
    final timestamp = lineStartMS is int ? Duration(milliseconds: lineStartMS) : parts[0].startTimestamp;
    return LrcLine(
      timestamp: timestamp,
      originalIndex: originalIndex,
      lyrics: lyrics,
      readableText: readableText,
      type: isWordSynced ? LrcTypes.enhanced : LrcTypes.simple,
      parts: parts,
      person: person,
      isRTL: LrcParser.isLrcLineRTL(readableText),
    );
  }

  static int? _agentToPerson(Object? agent) {
    if (agent is! String || agent.length < 2 || agent.codeUnitAt(0) != 0x76 /* v */) return null;
    return int.tryParse(agent.substring(1));
  }

  static int _jsonStart(String content) {
    final start = LrcParser._contentStart(content);
    final length = content.length;
    if (start == length) return -1;
    final opening = content.codeUnitAt(start);
    if (opening == 0x7B /* { */) return start;
    if (opening != 0x5B /* [ */) return -1;
    var next = start + 1;
    while (next < length && LrcParser._isEmptyCodeUnit(content.codeUnitAt(next))) {
      next++;
    }
    if (next == length || content.codeUnitAt(next) != 0x7B /* { */) return -1;
    return start;
  }
}
