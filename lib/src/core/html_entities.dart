// by claude
part of lrc;

/// Decodes xml entities (`&lt;`, `&amp;`, `&#39;`, `&#x27;`, ...) directly, the far slower [HtmlUnescape] only runs for other entities.
class _HtmlEntities {
  static const _kMaxEntityLength = 32;
  static final _htmlUnescape = HtmlUnescape();

  /// [s] itself when it has no entities.
  static String decode(String s) {
    var amp = s.indexOf('&');
    if (amp < 0) return s;
    final buffer = StringBuffer();
    var segmentStart = 0;
    while (amp >= 0) {
      final semicolon = _semicolonAfter(s, amp + 1);
      final charCode = semicolon < 0 ? -1 : _charCodeOf(s, amp + 1, semicolon);
      if (charCode < 0) return _htmlUnescape.convert(s);
      buffer.write(s.substring(segmentStart, amp));
      buffer.writeCharCode(charCode);
      segmentStart = semicolon + 1;
      amp = s.indexOf('&', segmentStart);
    }
    buffer.write(s.substring(segmentStart));
    return buffer.toString();
  }

  static int _semicolonAfter(String s, int start) {
    final maxEnd = start + _kMaxEntityLength;
    final end = maxEnd < s.length ? maxEnd : s.length;
    for (var i = start; i < end; i++) {
      if (s.codeUnitAt(i) == 0x3B /* ; */) return i;
    }
    return -1;
  }

  /// -1 when it is left to [HtmlUnescape], like html named entities.
  static int _charCodeOf(String s, int start, int end) {
    final length = end - start;
    if (length < 2) return -1;
    if (s.codeUnitAt(start) != 0x23 /* # */) {
      return switch (length) {
        2 when s.startsWith('lt', start) => 0x3C,
        2 when s.startsWith('gt', start) => 0x3E,
        3 when s.startsWith('amp', start) => 0x26,
        4 when s.startsWith('quot', start) => 0x22,
        4 when s.startsWith('apos', start) => 0x27,
        _ => -1,
      };
    }
    final marker = s.codeUnitAt(start + 1);
    final isHex = marker == 0x78 /* x */ || marker == 0x58 /* X */;
    final digitsStart = isHex ? start + 2 : start + 1;
    if (digitsStart == end) return -1;
    final base = isHex ? 16 : 10;
    var value = 0;
    for (var i = digitsStart; i < end; i++) {
      final digit = _digitOf(s.codeUnitAt(i), isHex);
      if (digit < 0) return -1;
      value = value * base + digit;
      if (value > 0x10FFFF) return -1;
    }
    final isSurrogate = value >= 0xD800 && value <= 0xDFFF;
    if (value == 0 || isSurrogate) return -1;
    return value;
  }

  static int _digitOf(int c, bool isHex) {
    if (c >= 0x30 && c <= 0x39) return c - 0x30;
    if (!isHex) return -1;
    final lower = c | 0x20;
    if (lower >= 0x61 && lower <= 0x66) return lower - 0x61 + 10;
    return -1;
  }
}
