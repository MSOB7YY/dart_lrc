part of lrc;

class TtmlParser {
  static final _regexp = RegExp(
      r'<p[^>]*?begin="([\d:.]+)s?"[^>]*?end="([\d:.]+)s?"[^>]*?>(.*?)<\/p>');

  static bool isValid(String content) => _regexp.hasMatch(content);

  static Lrc parse(String content) {
    final lrcLines = <LrcLine>[];
    final personToIndex = <String, int>{};
    final htmlUnescape = HtmlUnescape();
    var type = LrcTypes.simple;

    for (final m in _regexp.allMatches(content)) {
      int? startMS;
      // int? endMS;
      try {
        startMS = (double.parse(m.group(1)!) * 1000).round();
        // endMS = (double.parse(m.group(2)!) * 1000).round();
      } catch (_) {}
      if (startMS != null) {
        final textOriginal = m.group(3);
        String textNormalized;
        if (textOriginal != null && textOriginal.isNotEmpty) {
          textNormalized = htmlUnescape.convert(textOriginal);
        } else {
          textNormalized = '';
        }

        final personText =
            textNormalized.substring(0, textNormalized.indexOf('<'));
        final person = personToIndex[personText] ??= personToIndex.length + 1;
        var parts =
            LrcParser.extractTimeStampPartFromLine(textNormalized).toList();
        final lineType = parts.isNotEmpty ? LrcTypes.enhanced : LrcTypes.simple;
        if (lineType == LrcTypes.enhanced) type = LrcTypes.enhanced;
        lrcLines.add(LrcLine(
          timestamp: Duration(milliseconds: startMS),
          originalIndex: lrcLines.length,
          lyrics: textNormalized,
          readableText: parts.isNotEmpty
              ? parts.map((e) => e.lyrics).join()
              : textNormalized,
          type: lineType,
          parts: parts,
          person: person,
        ));
      }
    }

    return Lrc(
      lyrics: lrcLines,
      type: type,
    );
  }
}
