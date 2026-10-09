// by claude
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:lrc/lrc.dart';

void main() {
  group('weird_format.json', () {
    final content = File('test/files/weird_format.json').readAsStringSync();

    test('lines snapshot', () {
      final lrc = PaxsenixJsonParser.parse(content)!;
      expect(lrc.type, LrcTypes.enhanced);
      expect(lrc.personCount, 1);
      final snapshot = lrc.lyrics.map((e) => (e.timestamp.inMilliseconds, e.parts!.last.endTimestamp.inMilliseconds, e.parts!.length, e.readableText)).toList();
      expect(snapshot, [
        (49130, 55078, 4, 'Another head hangs lowly'),
        (55080, 60898, 4, 'Child is slowly taken'),
        (60900, 66108, 6, 'And the violence caused such silence'),
        (66110, 71238, 4, 'Who are we mistaken?'),
        (71240, 76858, 10, "But you see, it's not me, it's not my family"),
        (76860, 82858, 9, 'In your head, in your head they are fighting'),
        (82860, 88898, 12, 'With their tanks, and their bombs, and their bombs, and their guns'),
        (88900, 95028, 9, 'In your head, in your head they are crying'),
        (95030, 100078, 6, 'In your head, in your head'),
        (100080, 106078, 3, 'Zombie, zombie, zombie-ie-ie'),
        (106080, 111468, 7, "What's in your head? In your head?"),
        (111470, 118538, 4, 'Zombie, zombie, zombie-ie-ie-ie, oh'),
        (142250, 147198, 3, "Another mother's breaking"),
        (147200, 151208, 4, 'Heart is taking over'),
        (153590, 158628, 5, 'When the violence causes silence'),
        (158630, 164168, 4, 'We must be mistaken'),
        (164170, 169398, 7, "It's the same old theme, since 1916"),
        (169400, 175078, 9, "In your head, in your head they're still fighting"),
        (175080, 180878, 12, 'With their tanks, and their bombs, and their bombs, and their guns'),
        (180880, 187208, 9, 'In your head, in your head they are dying'),
        (187210, 192378, 6, 'In your head, in your head'),
        (192380, 199108, 3, 'Zombie, zombie, zombie-ie-ie'),
        (199110, 204258, 7, "What's in your head? In your head?"),
        (204260, 210638, 4, 'Zombie, zombie, zombie-ie-ie-ie, oh'),
        (210640, 214588, 8, 'Oh, oh, oh, oh, oh, oh, eh-eh-oh, ra-ra!'),
      ]);
      for (final line in lrc.lyrics) {
        expect(line.type, LrcTypes.enhanced, reason: line.readableText);
        expect(line.person, null, reason: line.readableText);
        expect(line.isRTL, false, reason: line.readableText);
      }
    });

    test('first line words', () {
      final first = PaxsenixJsonParser.parse(content)!.lyrics.first;
      expect(first.lyrics, '<00:49.130>Another <00:51.113>head <00:52.246>hangs <00:53.662>lowly<00:55.078>');
      final parts = first.parts!.map((e) => (e.startTimestamp.inMilliseconds, e.endTimestamp.inMilliseconds, e.lyrics)).toList();
      expect(parts, [
        (49130, 51112, 'Another '),
        (51113, 52245, 'head '),
        (52246, 53661, 'hangs '),
        (53662, 55078, 'lowly'),
      ]);
    });

    test('every word keeps its own timing and a space before the next one', () {
      final rawLines = jsonDecode(content) as List;
      final lines = PaxsenixJsonParser.parse(content)!.lyrics;
      expect(lines.length, rawLines.length);
      for (var i = 0; i < lines.length; i++) {
        final rawWords = rawLines[i]['text'] as List;
        final parts = lines[i].parts!;
        expect(parts.length, rawWords.length);
        expect(lines[i].timestamp, Duration(milliseconds: rawLines[i]['timestamp']));
        for (var j = 0; j < parts.length; j++) {
          final rawWord = rawWords[j];
          final text = rawWord['text'] as String;
          final isLast = j == parts.length - 1;
          expect(parts[j].lyrics, isLast ? text : '$text ');
          expect(parts[j].startTimestamp, Duration(milliseconds: rawWord['timestamp']));
          expect(parts[j].endTimestamp, Duration(milliseconds: rawWord['endtime']));
        }
      }
    });

    test('format output round trips through LrcParser', () {
      _expectFormatRoundTrip(PaxsenixJsonParser.parse(content)!);
    });

    test('is detected as valid', () {
      expect(PaxsenixJsonParser.isValid(content), true);
    });
  });

  group('syllables, singers and background vocals', () {
    test('syllables join without a space, background vocals become their own sorted lines', () {
      final lrc = PaxsenixJsonParser.parse(_kSyllableResponse)!;
      expect(lrc.type, LrcTypes.enhanced);
      expect(lrc.personCount, 2);
      final lines = lrc.lyrics.map((e) => (e.timestamp.inMilliseconds, e.person, e.isBGLyrics, e.readableText)).toList();
      expect(lines, [
        (1000, 1, false, 'Who are we mistaken?'),
        (2600, 0, true, 'You, the moonlight'),
        (3200, 2, false, 'something, boy'),
        (5000, 0, true, 'ooh'),
      ]);

      final lead = lrc.lyrics[0];
      final leadParts = lead.parts!.map((e) => (e.startTimestamp.inMilliseconds, e.endTimestamp.inMilliseconds, e.lyrics)).toList();
      expect(leadParts, [
        (1000, 1400, 'Who '),
        (1400, 1800, 'are '),
        (1800, 2100, 'we '),
        (2100, 2400, 'mi'),
        (2500, 3000, 'staken?'),
      ]);
      expect(lead.lyrics, '<00:01.000>Who <00:01.400>are <00:01.800>we <00:02.100>mi<00:02.500>staken?<00:03.000>');

      final background = lrc.lyrics[1];
      expect(background.type, LrcTypes.enhanced);
      expect(background.parts!.map((e) => e.lyrics), ['You, ', 'the ', 'moon', 'light']);
      expect(background.parts!.last.endTimestamp, const Duration(milliseconds: 3600));
    });

    test('format output round trips through LrcParser', () {
      final lrc = PaxsenixJsonParser.parse(_kSyllableResponse)!;
      final formatted = lrc.format();
      expect(formatted, contains('[00:01.00]v1: <00:01.00>Who <00:01.40>are <00:01.80>we <00:02.10>mi<00:02.50>staken?<00:03.00>'));
      expect(formatted, contains('[bg:<00:02.60>You, <00:02.90>the <00:03.10>moon<00:03.30>light<00:03.60>]'));
      expect(formatted, contains('[bg:<00:05.00>ooh<00:05.60>]'));
      _expectFormatRoundTrip(lrc);
    });

    test('line synced response gives plain lines spanning each line', () {
      const content = '{"type":"Line","content":[{"timestamp":17027,"endtime":25032,"text":[{"text":"In the backseat of my heart","timestamp":17027,"endtime":25032,"part":false}],'
          '"background":false,"backgroundText":[],"oppositeTurn":false},{"timestamp":25100,"endtime":30000,"text":[{"text":"Someone sayin\' I\'m a mess","timestamp":25100,"endtime":30000,"part":false}]}]}';
      final lrc = PaxsenixJsonParser.parse(content)!;
      expect(lrc.type, LrcTypes.simple);
      final first = lrc.lyrics.first;
      expect(first.type, LrcTypes.simple);
      expect(first.lyrics, 'In the backseat of my heart');
      expect(first.readableText, 'In the backseat of my heart');
      expect(first.parts!.single.startTimestamp, const Duration(milliseconds: 17027));
      expect(first.parts!.single.endTimestamp, const Duration(milliseconds: 25032));
      expect(lrc.lyrics.last.readableText, "Someone sayin' I'm a mess");
    });

    test('leading BOM and spaces are skipped', () {
      const content = '﻿ \n [ {"text":[{"text":"hi","part":false,"timestamp":10,"endtime":20}],"background":false,"timestamp":10,"endtime":20}]';
      expect(PaxsenixJsonParser.isValid(content), true);
      expect(PaxsenixJsonParser.parse(content)!.lyrics.single.readableText, 'hi');
    });

    test('a bad word or line is skipped, the rest is kept', () {
      const content = '[{"text":"not a list"},5,{"text":[{"text":"a","timestamp":"1","endtime":2},{"text":"b","part":false,"timestamp":10,"endtime":20}],"timestamp":10}]';
      final line = PaxsenixJsonParser.parse(content)!.lyrics.single;
      expect(line.readableText, 'b');
      expect(line.parts!.single.startTimestamp, const Duration(milliseconds: 10));
    });
  });

  group('rejects', () {
    test('malformed json returns null', () {
      expect(PaxsenixJsonParser.parse('[{"text":[{"text":"a","part":false,"timestamp":1,'), null);
      expect(PaxsenixJsonParser.parse('{"content": [}'), null);
      expect(PaxsenixJsonParser.parse('[{]'), null);
    });

    test('json of another shape returns null', () {
      expect(PaxsenixJsonParser.parse('[]'), null);
      expect(PaxsenixJsonParser.parse('{}'), null);
      expect(PaxsenixJsonParser.parse('[1, 2]'), null);
      expect(PaxsenixJsonParser.parse('{"lyrics": "plain text"}'), null);
      expect(PaxsenixJsonParser.parse('{"content": "plain text"}'), null);
      expect(PaxsenixJsonParser.parse('{"content": [{"text": []}]}'), null);
      expect(PaxsenixJsonParser.parse('[{"text": "plain text", "timestamp": 1}]'), null);
      expect(PaxsenixJsonParser.parse('[{"words": [{"text": "a", "timestamp": 1, "endtime": 2}]}]'), null);
      expect(PaxsenixJsonParser.parse('[{"text": [{"text": 5, "timestamp": 1, "endtime": 2}]}]'), null);
    });

    test('lrc, ttml, subtitles and plain text return null', () {
      expect(PaxsenixJsonParser.parse(''), null);
      expect(PaxsenixJsonParser.parse('   '), null);
      expect(PaxsenixJsonParser.parse('plain lyrics\nsecond line'), null);
      for (final name in ['timed_lrc.lrc', 'timed_lrc_2.lrc', 'ttml_lrc.xml', 'ttml_lrc3.ttml', 'sub_lrc.srt', 'sub_lrc.vtt', 'sub_lrc.ass']) {
        final content = File('test/files/$name').readLrcStringSync();
        expect(PaxsenixJsonParser.isValid(content), false, reason: name);
        expect(PaxsenixJsonParser.parse(content), null, reason: name);
      }
    });
  });
}

/// lrc keeps only centiseconds and no word end inside a line, so each word ends where the next starts.
void _expectFormatRoundTrip(Lrc lrc) {
  Duration toCentiseconds(Duration d) => Duration(milliseconds: d.inMilliseconds ~/ 10 * 10);

  final reparsed = LrcParser.parse(lrc.format());
  expect(reparsed.type, lrc.type);
  expect(reparsed.personCount, lrc.personCount);
  expect(reparsed.lyrics.length, lrc.lyrics.length);
  for (var i = 0; i < lrc.lyrics.length; i++) {
    final a = lrc.lyrics[i];
    final b = reparsed.lyrics[i];
    final reason = a.readableText;
    expect(b.timestamp, toCentiseconds(a.timestamp), reason: reason);
    expect(b.readableText, a.readableText, reason: reason);
    expect(b.person, a.person, reason: reason);
    final partsA = a.parts!;
    final partsB = b.parts!;
    expect(partsB.map((e) => e.lyrics), partsA.map((e) => e.lyrics), reason: reason);
    final lastIndex = partsA.length - 1;
    for (var j = 0; j <= lastIndex; j++) {
      final endA = j == lastIndex ? partsA[j].endTimestamp : partsA[j + 1].startTimestamp;
      expect(partsB[j].startTimestamp, toCentiseconds(partsA[j].startTimestamp), reason: reason);
      expect(partsB[j].endTimestamp, toCentiseconds(endA), reason: reason);
    }
  }
}

const _kSyllableResponse = '''
{"type": "Syllable", "metadata": {"language": "en"}, "content": [
  {"timestamp": 1000, "endtime": 3600, "agent": "v1", "oppositeTurn": false, "background": true, "text": [
    {"text": "Who", "part": false, "timestamp": 1000, "endtime": 1400},
    {"text": "are", "part": false, "timestamp": 1400, "endtime": 1800},
    {"text": "we", "part": false, "timestamp": 1800, "endtime": 2100},
    {"text": "mi", "part": true, "timestamp": 2100, "endtime": 2400},
    {"text": "staken?", "part": false, "timestamp": 2500, "endtime": 3000}
  ], "backgroundText": [
    {"text": "You,", "part": false, "timestamp": 2600, "endtime": 2900},
    {"text": "the", "part": false, "timestamp": 2900, "endtime": 3100},
    {"text": "moon", "part": true, "timestamp": 3100, "endtime": 3300},
    {"text": "light", "part": false, "timestamp": 3300, "endtime": 3600}
  ]},
  {"timestamp": 3200, "endtime": 4500, "agent": "v2", "oppositeTurn": true, "background": false, "backgroundText": [], "text": [
    {"text": "some", "part": true, "timestamp": 3200, "endtime": 3500},
    {"text": "thing,", "part": false, "timestamp": 3500, "endtime": 3900},
    {"text": "boy", "part": false, "timestamp": 4000, "endtime": 4500}
  ]},
  {"timestamp": 5000, "endtime": 5600, "background": true, "text": [
    {"text": "ooh", "part": false, "timestamp": 5000, "endtime": 5600}
  ]}
]}
''';
