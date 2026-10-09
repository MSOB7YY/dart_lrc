// by claude
import 'dart:io';

import 'package:test/test.dart';

import 'package:lrc/lrc.dart';

void main() {
  group('qrc_lrc.qrc', () {
    final content = File('test/files/qrc_lrc.qrc').readAsStringSync();

    test('tags and lines snapshot', () {
      final lrc = QrcParser.parse(content)!;
      expect(lrc.type, LrcTypes.enhanced);
      expect(lrc.title, '晴天');
      expect(lrc.artist, '周杰伦');
      expect(lrc.album, '叶惠美');
      expect(lrc.creator, '');
      expect(lrc.offset, 0);
      expect(lrc.personCount, 1);
      final snapshot = lrc.lyrics.map((e) => (e.timestamp.inMilliseconds, e.parts!.last.endTimestamp.inMilliseconds, e.parts!.length, e.readableText)).toList();
      expect(snapshot, [
        (0, 4370, 8, '晴天 - 周杰伦'),
        (4370, 6100, 5, '词：周杰伦'),
        (29450, 31256, 6, '故事的小黄花'),
        (33060, 35692, 8, '从出生那年就飘着'),
        (36350, 39520, 6, '童年的荡秋千'),
      ]);
      for (final line in lrc.lyrics) {
        expect(line.type, LrcTypes.enhanced, reason: line.readableText);
        expect(line.person, null, reason: line.readableText);
        expect(line.isRTL, false, reason: line.readableText);
      }
    });

    test('first line words', () {
      final first = QrcParser.parse(content)!.lyrics.first;
      expect(first.lyrics, '<00:00.000>晴<00:00.546>天<00:01.092> <00:01.638>-<00:02.184> <00:02.730>周<00:03.276>杰<00:03.822>伦<00:04.370>');
      final parts = first.parts!.map((e) => (e.startTimestamp.inMilliseconds, e.endTimestamp.inMilliseconds, e.lyrics)).toList();
      expect(parts, [
        (0, 546, '晴'),
        (546, 1092, '天'),
        (1092, 1638, ' '),
        (1638, 2184, '-'),
        (2184, 2730, ' '),
        (2730, 3276, '周'),
        (3276, 3822, '杰'),
        (3822, 4370, '伦'),
      ]);
    });

    test('formatted lrc parses back to the same lines', () {
      final lrc = QrcParser.parse(content)!;
      final reparsed = Lrc.parse(lrc.format());
      expect(reparsed.title, lrc.title);
      expect(reparsed.lyrics.map((e) => e.readableText), lrc.lyrics.map((e) => e.readableText));
      expect(reparsed.lyrics.map((e) => e.parts!.length), lrc.lyrics.map((e) => e.parts!.length));
    });
  });

  test('LyricContent text alone, with lines lacking word timings', () {
    const content = '[1000,2000]Hello (1000,500)world(1500,500)\n[3000,1000]\n[4000,1000] plain line ';
    final lrc = QrcParser.parse(content)!;
    expect(lrc.type, LrcTypes.enhanced);
    final lines = lrc.lyrics.map((e) => (e.timestamp.inMilliseconds, e.type, e.parts?.length, e.readableText)).toList();
    expect(lines, [
      (1000, LrcTypes.enhanced, 2, 'Hello world'),
      (3000, LrcTypes.simple, null, ''),
      (4000, LrcTypes.simple, null, 'plain line'),
    ]);
  });

  test('xml entities are unescaped', () {
    const content = '<Lyric_1 LyricType="1" LyricContent="[1000,1000]Don&apos;t (1000,500)&quot;cry&quot;(1500,500)"/>';
    final line = QrcParser.parse(content)!.lyrics.single;
    expect(line.readableText, 'Don\'t "cry"');
    expect(line.parts!.map((e) => e.lyrics), ['Don\'t ', '"cry"']);
  });

  test('parentheses in words are kept and text after the last word timing is dropped', () {
    const content = '[0,2000](Oh)(0,500) yeah(500,500)!!';
    final line = QrcParser.parse(content)!.lyrics.single;
    expect(line.parts!.map((e) => e.lyrics), ['(Oh)', ' yeah']);
    expect(line.parts!.last.endTimestamp, const Duration(milliseconds: 1000));
  });

  test('out of order lines are sorted', () {
    const content = '[5000,1000]b(5000,1000)\n[1000,1000]a(1000,1000)';
    final lrc = QrcParser.parse(content)!;
    expect(lrc.lyrics.map((e) => e.readableText), ['a', 'b']);
  });

  test('isValid and parse reject other formats', () {
    const lrcContent = '[00:01.00]line\n[00:02.00]<00:02.00>word<00:03.00>';
    expect(QrcParser.isValid('[1000,2000]a(1000,2000)'), true);
    expect(QrcParser.isValid(lrcContent), false);
    expect(QrcParser.isValid('plain text (1,2)'), false);
    expect(QrcParser.parse(lrcContent), null);
    expect(QrcParser.parse('[ti:x]\n[1000,]a(1000,1)'), null);
  });
}
