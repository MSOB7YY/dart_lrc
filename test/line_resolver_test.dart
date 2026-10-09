// by claude
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:lrc/lrc.dart';

import 'fixtures.dart';

void main() {
  test('nothing plays before the first line', () {
    final resolver = _resolverOf([1000, 2000]);
    expect(resolver.indexAt(-500), -1);
    expect(resolver.indexAt(0), -1);
    expect(resolver.slotAt(994), -1);
  });

  test('a line plays from a few ms before its start until the next one starts', () {
    final resolver = _resolverOf([1000, 2000, 3000]);
    expect(resolver.indexAt(994), -1);
    expect(resolver.indexAt(995), 10);
    expect(resolver.indexAt(1994), 10);
    expect(resolver.indexAt(1995), 20);
    expect(resolver.indexAt(100000), 30);
    expect(resolver.slotAt(100000), 2);
  });

  test('forward playback, backward seeks and long jumps all match a linear scan', () {
    final starts = List.generate(300, (i) => i * 500 + (i.isEven ? 0 : 120));
    final resolver = _resolverOf(starts);
    for (var positionMS = -1000; positionMS < 152000; positionMS += 16) {
      expect(resolver.slotAt(positionMS), _scanSlot(starts, positionMS), reason: 'playing at $positionMS');
    }
    final random = Random(7);
    for (var i = 0; i < 3000; i++) {
      final positionMS = random.nextInt(153000) - 1000;
      expect(resolver.slotAt(positionMS), _scanSlot(starts, positionMS), reason: 'seek to $positionMS');
    }
  });

  test('upperBound counts the starts at or before a position', () {
    final resolver = _resolverOf([1000, 1000, 2000]);
    expect(resolver.upperBound(999), 0);
    expect(resolver.upperBound(1000), 2);
    expect(resolver.upperBound(1999), 2);
    expect(resolver.upperBound(2000), 3);
  });

  test('lines sharing a timestamp resolve to the first of them, background vocals never resolve', () {
    const content = '[00:01.00]<00:01.00>a <00:02.00>b<00:03.00>\n[bg:<00:02.50>ooh<00:03.50>]\n[00:01.00]translated\n[00:10.00]c';
    final ui = Lrc.parse(content).forUiDisplay(0);
    expect(ui.uiLyricsLines.map((e) => e.readableText), ['a b', 'translated', 'ooh', '', 'c']);
    final resolver = ui.lineResolver;
    expect(resolver.indexAt(1500), 0);
    expect(resolver.indexAt(2700), 0);
    expect(resolver.indexAt(3600), 3);
    expect(resolver.indexAt(10000), 4);
  });

  test('on every fixture it picks the line a backward scan for the last started line finds', () {
    for (final (:name, :lrc) in parseAllFixtures()) {
      final ui = lrc.forUiDisplay(0.8, extraOffsetDuration: const Duration(milliseconds: 300), romanizer: (text) => text.toUpperCase());
      final lines = ui.uiLyricsLines;
      final map = ui.highlightTimestampsMap;
      int scan(int positionMS) {
        final position = Duration(milliseconds: positionMS + LrcLineResolver.kToleranceMS);
        for (var i = lines.length - 1; i >= 0; i--) {
          final line = lines[i];
          if (line.timestamp <= position && !line.isBGLyrics) return map[line.timestamp]!.first;
        }
        return -1;
      }

      final resolver = ui.lineResolver;
      final endMS = lines.last.timestamp.inMilliseconds + 2000;
      for (var positionMS = -1000; positionMS < endMS; positionMS += 37) {
        expect(resolver.indexAt(positionMS), scan(positionMS), reason: '$name playing at $positionMS');
      }
      final random = Random(lines.length);
      for (var i = 0; i < 500; i++) {
        final positionMS = random.nextInt(endMS + 1000) - 1000;
        expect(resolver.indexAt(positionMS), scan(positionMS), reason: '$name seek to $positionMS');
      }
    }
  });
}

LrcLineResolver _resolverOf(List<int> startsMS) {
  final lineIndices = List.generate(startsMS.length, (slot) => slot * 10 + 10);
  return LrcLineResolver(Int32List.fromList(startsMS), Int32List.fromList(lineIndices));
}

int _scanSlot(List<int> startsMS, int positionMS) {
  var slot = -1;
  for (var i = 0; i < startsMS.length; i++) {
    if (startsMS[i] <= positionMS + LrcLineResolver.kToleranceMS) slot = i;
  }
  return slot;
}
