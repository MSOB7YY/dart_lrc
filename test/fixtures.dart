// by claude
import 'dart:io';

import 'package:lrc/lrc.dart';

/// every lyrics & subtitle file under test/files, parsed by the parser of its format.
Iterable<({String name, Lrc lrc})> parseAllFixtures() sync* {
  final files = Directory('test/files').listSync(recursive: true).whereType<File>();
  for (final file in files) {
    final path = file.path;
    final parse = _parserFor(path);
    if (parse == null) continue;
    yield (name: path, lrc: parse(file.readLrcStringSync()));
  }
}

Lrc Function(String content)? _parserFor(String path) {
  if (path.endsWith('.lrc')) return LrcParser.parse;
  if (path.endsWith('.xml') || path.endsWith('.ttml')) return TtmlParser.parse;
  if (path.endsWith('.srt') || path.endsWith('.vtt') || path.endsWith('.sbv') || path.endsWith('.ass')) return SubtitleParser.parse;
  if (path.endsWith('.json')) return (content) => PaxsenixJsonParser.parse(content)!;
  return null;
}
