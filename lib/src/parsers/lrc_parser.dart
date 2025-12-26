part of lrc;

class LrcParser {
  static List<String> _splitLines(String data) {
    var lines = <String>[];
    var end = data.length;
    var sliceStart = 0;
    var char = 0;
    for (var i = 0; i < end; i++) {
      var previousChar = char;
      char = data.codeUnitAt(i);
      if (char != 13) {
        if (char != 10) continue;
        if (previousChar == 13) {
          sliceStart = i + 1;
          continue;
        }
      }
      lines.add(data.substring(sliceStart, i));
      sliceStart = i + 1;
    }
    if (sliceStart < end) lines.add(data.substring(sliceStart, end));
    return lines;
  }

  static List<String> splitMultiLanguageLine(String lyric) {
    return lyric.split(RegExp(r'(\s{2,}|\|)(?=\S)'));
  }

  static Iterable<LrcLinePart> extractTimeStampPartFromLine(String line,
      {Duration? startTimeStamp}) sync* {
    var isFirst = true;
    var latestTimeStamp = startTimeStamp;
    for (var j in RegExp(r'([^<\]]*)<(([0-9]{1,}):([0-9]{1,})\.([0-9]{1,})?)>')
        .allMatches(line)) {
      final lyrics = j.group(1) ?? '';
      final endTimestamp = Duration(
        minutes: int.tryParse(j.group(3)!) ?? 0,
        seconds: int.tryParse(j.group(4)!) ?? 0,
        milliseconds: (int.tryParse(j.group(5)!) ?? 0),
      );
      final startTimestamp = latestTimeStamp;
      latestTimeStamp = endTimestamp;
      if (startTimestamp == null) {
        // we set the start for the next part
        continue;
      }
      if (isFirst) {
        // -- skip first part that has `v1:` etc
        if (lyrics.length < 5 &&
            lyrics.startsWith('v') &&
            (lyrics.endsWith(':') || lyrics.endsWith(': '))) {
          continue;
        }
      }
      yield LrcLinePart(
        startTimestamp: startTimestamp,
        endTimestamp: endTimestamp,
        lyrics: lyrics,
      );
      isFirst = false;
    }
  }

  /// Parses an LRC from a string. Throws a `FormatExeption`
  /// if the inputted string is not valid.
  static Lrc parse(String content) {
    if (!isValid(content)) {
      throw FormatException('The inputted string is not a valid LRC file');
    }

    // split string into lines, code from Linesplitter().convert(data)
    var lines = _splitLines(content);

    // temporary storer variables
    String? artist,
        album,
        title,
        length,
        author,
        creator,
        offset,
        program,
        version,
        language;
    LrcTypes? type;
    var lyrics = <LrcLine>[];

    final personToIndex = <String, int>{};
    var registeredTimestamps = <Duration>{};
    var shouldSortLyrics = false;

    String? setIfMatchTag(String toMatch, String tag) =>
        (RegExp(r'^\[' + tag + r':.*\]$').hasMatch(toMatch))
            ? toMatch.substring(tag.length + 2, toMatch.length - 1).trim()
            : null;

    // loop thru each lines
    for (var i = 0; i < lines.length; i++) {
      var l = lines[i];
      artist ??= setIfMatchTag(l, 'ar');
      album ??= setIfMatchTag(l, 'al');
      title ??= setIfMatchTag(l, 'ti');
      author ??= setIfMatchTag(l, 'au');
      length ??= setIfMatchTag(l, 'length');
      creator ??= setIfMatchTag(l, 'by');
      offset ??= setIfMatchTag(l, 'offset');
      program ??= setIfMatchTag(l, 're');
      version ??= setIfMatchTag(l, 've');
      language ??= setIfMatchTag(l, 'la');

      if (_LRCMultiTimestampParser._durRegex.hasMatch(l)) {
        var lineType = LrcTypes.simple;
        List<LrcLinePart>? parts;

        final lrclineDetails = _LRCMultiTimestampParser.parseLine(l);
        final lyric = lrclineDetails.lineText;
        final timestamps = lrclineDetails.timestamps;

        if (shouldSortLyrics == false) {
          if (timestamps.length > 1) {
            // -- means it has multi timestamps
            shouldSortLyrics = true;
          }
          if (timestamps
              .any((element) => registeredTimestamps.contains(element))) {
            // -- means it has multi language in the end of the file
            shouldSortLyrics = true;
          }
        }

        int? person;

        // checkers for different types of LRCs
        if (lyric.contains(RegExp(r'^\w:'))) {
          //if extended
          type = (type == LrcTypes.enhanced)
              ? LrcTypes.extended_enhanced
              : LrcTypes.extended;

          final personText = lyric[0];
          person = personToIndex[personText] ??= personToIndex.length + 1;

          parts = [];
          parts.add(LrcLinePart(
            startTimestamp: timestamps.first,
            endTimestamp: timestamps.first,
            lyrics: lyric.substring(2),
          ));

          lineType = LrcTypes.extended;
        } else if (lyric
            .contains(RegExp(r'<[0-9]{1,}:[0-9]{1,}(\.[0-9]{1,})?>'))) {
          // if enhanced
          type = (type == LrcTypes.extended)
              ? LrcTypes.extended_enhanced
              : LrcTypes.enhanced;
          parts = [];
          lineType = LrcTypes.enhanced;

          final indexOfLT = lyric.indexOf('<');
          final personText = indexOfLT < 0 ? '' : lyric.substring(0, indexOfLT);
          person = personToIndex[personText] ??= personText.startsWith('v1:')
              ? 1
              : personText.startsWith('v2:')
                  ? 2
                  : personText.startsWith('v3:')
                      ? 3
                      : personToIndex.length + 1;

          parts.addAll(
            extractTimeStampPartFromLine(
              lyric,
              startTimeStamp: timestamps.first,
            ),
          );
        }

        final lyricSplit = splitMultiLanguageLine(lyric);
        for (var i = 0; i < lyricSplit.length; i++) {
          var lyric = lyricSplit[i];
          if (lyric.length < 5 && lyric.startsWith('v3:')) lyric = '';
          final readableText = parts != null && parts.isNotEmpty
              ? parts.map((e) => e.lyrics).join()
              : lyric;
          for (final linetimestamp in timestamps) {
            registeredTimestamps.add(linetimestamp);
            lyrics.add(LrcLine(
              timestamp: linetimestamp,
              originalIndex: lyrics.length,
              lyrics: lyric,
              readableText: readableText.isNotEmpty ? readableText : lyric,
              type: lineType,
              parts: parts,
              person: person,
            ));
          }
        }
      }
    }

    if (type == LrcTypes.enhanced || type == LrcTypes.extended_enhanced) {
      // extract bg tags
      for (final m in RegExp(r'\[bg:(.*)\]').allMatches(content)) {
        final text = m.group(1);
        if (text == null) continue;
        final parts = extractTimeStampPartFromLine(text).toList();
        if (parts.isEmpty) continue;
        lyrics.add(LrcLine(
          timestamp: parts[0].startTimestamp,
          originalIndex: lyrics.length,
          lyrics: text,
          readableText: parts.map((e) => e.lyrics).join(),
          type: type ?? LrcTypes.enhanced,
          parts: parts,
          person: 0,
        ));
        shouldSortLyrics = true;
      }
    }

    if (shouldSortLyrics) {
      lyrics.sort((a, b) {
        final res =
            a.timestamp.inMicroseconds.compareTo(b.timestamp.inMicroseconds);
        if (res == 0) {
          return a.originalIndex.compareTo(b.originalIndex);
        }
        return res;
      });
    }

    var personCount =
        personToIndex.values.where((element) => element > 0).length;
    if (personCount <= 0) personCount = 1;

    return Lrc(
      type: type ?? LrcTypes.simple,
      artist: artist,
      album: album,
      title: title,
      author: author,
      length: length,
      creator: creator,
      offset: (offset != null) ? int.tryParse(offset) : null,
      program: program,
      version: version,
      lyrics: lyrics,
      language: language,
      personCount: personCount,
    );
  }

  /// Checks if the string [input] is a valid LRC using Regex.
  static bool isValid(String input) =>
      RegExp(r'\[(\d{1,}).+\]').hasMatch(input);

  static String cleanPlainLyrics(String input) {
    final regex = RegExp(
        r'([\r\n]*\[((ti)|(a[rlu])|(by)|([rv]e)|(length)|(offset)|(la)):.+\][\r\n]*)');
    return input.replaceAll(regex, '');
  }
}
