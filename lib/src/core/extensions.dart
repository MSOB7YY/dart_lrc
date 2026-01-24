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
