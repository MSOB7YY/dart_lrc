part of lrc;

class LrcLinePart {
  final Duration timestamp;
  final String lyrics;

  const LrcLinePart({
    required this.timestamp,
    required this.lyrics,
  });

  @override
  String toString() {
    return '''
      Timestamp: '$timestamp'
      Lyrics: '$lyrics'
    ''';
  }
}
