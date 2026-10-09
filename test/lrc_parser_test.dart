// by claude
import 'dart:io';

import 'package:test/test.dart';

import 'package:lrc/lrc.dart';

import 'fixtures.dart';

void main() {
  group('singers', () {
    test('plain lines keep the number written after v', () {
      const content = '[00:01.00]v2: second singer goes first\n[00:02.00]v1: first singer\n[00:03.00]v2: second again';
      final lrc = Lrc.parse(content);
      expect(lrc.lyrics.map((e) => e.person), [2, 1, 2]);
      expect(lrc.lyrics.map((e) => e.readableText), ['second singer goes first', 'first singer', 'second again']);
      expect(lrc.personCount, 2);
    });

    test('word synced lines keep the number written after v', () {
      const content = '[00:05.00]v3:<00:05.00>a <00:06.00>b<00:07.00>\n[00:08.00]v1:<00:08.00>c<00:09.00>';
      final lrc = Lrc.parse(content);
      expect(lrc.lyrics.map((e) => e.person), [3, 1]);
      expect(lrc.lyrics.first.parts!.map((e) => e.lyrics), ['a ', 'b']);
      expect(lrc.lyrics.first.readableText, 'a b');
    });
  });

  group('sorting', () {
    test('unique out of order timestamps come back sorted', () {
      final lrc = Lrc.parse('[00:20.00]b\n[00:10.00]a');
      expect(lrc.lyrics.map((e) => e.readableText), ['a', 'b']);
    });

    test('a translation block appended with shifted timestamps interleaves with the original', () {
      const content = '[00:10.00]one\n[00:20.00]two\n[00:10.50]uno\n[00:20.50]dos';
      final lrc = Lrc.parse(content);
      expect(lrc.lyrics.map((e) => e.readableText), ['one', 'uno', 'two', 'dos']);
    });

    test('lines sharing a timestamp keep their file order', () {
      const content = '[00:10.00]one\n[00:20.00]two\n[00:10.00]uno\n[00:20.00]dos';
      final lrc = Lrc.parse(content);
      expect(lrc.lyrics.map((e) => e.readableText), ['one', 'uno', 'two', 'dos']);
    });

    test('background vocals are placed at their own timestamp', () {
      const content = '[00:01.00]<00:01.00>a <00:02.00>b<00:03.00>\n[bg:<00:02.50>ooh<00:03.50>]\n[00:10.00]<00:10.00>c<00:11.00>';
      final lrc = Lrc.parse(content);
      expect(lrc.lyrics.map((e) => e.readableText), ['a b', 'ooh', 'c']);
      expect(lrc.lyrics[1].isBGLyrics, true);
    });

    test('parse output is sorted for every fixture', () {
      for (final (:name, :lrc) in parseAllFixtures()) {
        final lines = lrc.lyrics;
        expect(lines, isNotEmpty, reason: name);
        for (var i = 1; i < lines.length; i++) {
          expect(lines[i].timestamp >= lines[i - 1].timestamp, true, reason: '$name line $i');
        }
      }
    });
  });

  group('fixtures', () {
    test('timed_lrc_2: v1 word lines with millisecond timestamps and pauses', () {
      final lrc = _parseLrcFixture('timed_lrc_2.lrc');
      expect(lrc.type, LrcTypes.enhanced);
      expect(lrc.title, 'Brooklyn Baby');
      expect(lrc.artist, 'Lana Del Rey');
      expect(lrc.offset, 0);
      expect(lrc.personCount, 1);
      expect(lrc.lyrics.length, 57);

      final first = lrc.lyrics.first;
      expect(first.timestamp, const Duration(milliseconds: 18653));
      expect(first.person, 1);
      expect(first.readableText, "They say I'm too young to love you ");
      expect(first.parts!.length, 8);
      expect(first.parts!.first.endTimestamp, const Duration(milliseconds: 18900));
      expect(first.parts!.last.endTimestamp, const Duration(milliseconds: 22543));

      final pauseLine = lrc.lyrics[7];
      expect(pauseLine.readableText, 'Beat poetry on amphetamines ');
      final pause = pauseLine.parts![2];
      expect(pause.lyrics, '');
      expect(pause.startTimestamp, const Duration(milliseconds: 50081));
      expect(pause.endTimestamp, const Duration(milliseconds: 50422));

      final last = lrc.lyrics.last;
      expect(last.timestamp, const Duration(minutes: 5, seconds: 3, milliseconds: 417));
      expect(last.readableText, "I'm a Brooklyn baby ");
    });

    test('timed_lrc_3: back to back word timestamps give zero length empty parts', () {
      final lrc = _parseLrcFixture('timed_lrc_3.lrc');
      expect(lrc.title, 'KONTINUUM');
      expect(lrc.lyrics.length, 71);

      final first = lrc.lyrics.first;
      expect(first.readableText, 'KONTINUUM - SennaRin');
      expect(first.parts!.map((e) => e.lyrics), ['KONTINUUM ', '', '- ', '', 'SennaRin', '']);

      for (final line in lrc.lyrics) {
        for (final part in line.parts!) {
          if (part.lyrics.isEmpty) expect(part.endTimestamp, part.startTimestamp, reason: line.readableText);
        }
      }

      final last = lrc.lyrics.last;
      expect(last.timestamp, const Duration(minutes: 3, seconds: 1, milliseconds: 157));
      expect(last.readableText, 'Spotlight');
    });

    test('timed_lrc_4: crlf duet keeps both singers and their overlapping lines', () {
      final lrc = _parseLrcFixture('timed_lrc_4.lrc');
      expect(lrc.title, 'We Cry Together');
      expect(lrc.personCount, 2);
      expect(lrc.lyrics.length, 151);
      expect(lrc.lyrics.first.person, 2);
      expect(lrc.lyrics.first.readableText, 'Oh-ooh-oh-ooh, whoa ');

      final second = lrc.lyrics[4];
      final first = lrc.lyrics[5];
      expect(second.person, 2);
      expect(first.person, 1);
      expect(first.timestamp, const Duration(milliseconds: 31767));
      expect(first.timestamp < second.parts!.last.endTimestamp, true);

      final pausesLine = lrc.lyrics[8];
      expect(pausesLine.readableText, 'Fuck you, fuck you ');
      expect(pausesLine.parts!.map((e) => e.lyrics), ['Fuck ', 'you, ', '', 'fuck ', '', 'you ']);

      final last = lrc.lyrics.last;
      expect(last.person, 2);
      expect(last.readableText, 'Stop tap dancing around the conversation ');
    });

    test('timed_lrc_5: credit lines and same timestamp translations', () {
      final lrc = _parseLrcFixture('timed_lrc_5.lrc');
      expect(lrc.type, LrcTypes.simple);
      expect(lrc.creator, 'Mercury-xly');
      expect(lrc.lyrics.length, 114);
      expect(lrc.lyrics[0].readableText, '作词 : Khoa Pham');
      expect(lrc.lyrics[1].readableText, '作曲 : Khoa Pham');
      expect(lrc.lyrics[2].timestamp, const Duration(milliseconds: 20890));
      expect(lrc.lyrics[3].timestamp, const Duration(milliseconds: 20890));
      expect(lrc.lyrics[2].readableText, "I'm");
      expect(lrc.lyrics[3].readableText, '我');
      expect(lrc.lyrics.every((e) => e.person == null && e.parts == null), true);
      expect(lrc.lyrics.last.readableText, '你的心');
    });

    test('timed_lrc_8: romaji and japanese word lines share each timestamp', () {
      final lrc = _parseLrcFixture('timed_lrc_8.lrc');
      expect(lrc.type, LrcTypes.enhanced);
      expect(lrc.title, 'Ave Mujica');
      expect(lrc.album, 'Alea jacta est');
      expect(lrc.offset, 0);
      expect(lrc.lyrics.length, 109);
      expect(lrc.lyrics.first.readableText, 'Ave Mujica - Ave Mujica');

      final romaji = lrc.lyrics[3];
      final japanese = lrc.lyrics[4];
      expect(romaji.timestamp, const Duration(seconds: 28));
      expect(japanese.timestamp, const Duration(seconds: 28));
      expect(japanese.readableText, '「ようこそ Ave Mujica の世界へ」');
      expect(japanese.parts!.first.lyrics, '「');
      expect(japanese.parts!.last.endTimestamp, const Duration(milliseconds: 29929));

      final last = lrc.lyrics.last;
      expect(last.timestamp, const Duration(minutes: 4, seconds: 3, milliseconds: 223));
      expect(last.readableText, 'Ō 宿命は産声を上げる');
    });

    test('extra/ttml: the lrc and ttml exports of the same song give the same lines', () {
      final lrc = _parseLrcFixture('extra/ttml/Lana Del Rey - Brooklyn Baby.lrc');
      final ttmlContent = File('test/files/extra/ttml/Lana Del Rey - Lana Del Rey - Brooklyn Baby (Official Audio).xml').readLrcStringSync();
      final ttml = TtmlParser.parse(ttmlContent);
      expect(lrc.title, 'Brooklyn Baby');
      expect(lrc.creator, 'Generated using SongSync');
      expect(lrc.lyrics.length, 57);
      expect(ttml.type, LrcTypes.enhanced);
      expect(ttml.lyrics.length, lrc.lyrics.length);
      for (var i = 0; i < lrc.lyrics.length; i++) {
        final fromLrc = lrc.lyrics[i];
        final fromTtml = ttml.lyrics[i];
        final reason = fromLrc.readableText;
        expect(fromTtml.timestamp, fromLrc.timestamp, reason: reason);
        expect(fromTtml.readableText, fromLrc.readableText, reason: reason);
        expect(fromTtml.person, fromLrc.person, reason: reason);
        expect(fromTtml.parts!.map(_partSnapshot), fromLrc.parts!.map(_partSnapshot), reason: reason);
      }

      final syllablesLine = lrc.lyrics[3];
      expect(syllablesLine.readableText, 'The freedom land of the seventies ');
      expect(syllablesLine.parts!.map((e) => e.lyrics), ['The ', 'freedom ', 'land ', 'of ', 'the ', 'sev', 'en', 'ties ']);
      expect(syllablesLine.parts!.last.endTimestamp, const Duration(milliseconds: 36506));
    });

    test('extra/word synced lrc/Believer: doubled word timestamps and background shouts', () {
      final lrc = _parseLrcFixture('extra/word synced lrc/Imagine Dragons - Believer.lrc');
      expect(lrc.type, LrcTypes.enhanced);
      expect(lrc.title, 'Believer');
      expect(lrc.artist, 'Imagine Dragons');
      expect(lrc.creator, 'Generated using SongSync');
      expect(lrc.personCount, 1);
      expect(lrc.lyrics.length, 72);
      expect(lrc.lyrics.where((e) => e.isBGLyrics).length, 12);

      final first = lrc.lyrics.first;
      expect(first.timestamp, const Duration(milliseconds: 7926));
      expect(first.person, 1);
      expect(first.readableText, 'First things first ');
      expect(first.parts!.map(_partSnapshot), [(7926, 8342, 'First '), (8342, 8342, ''), (8342, 8826, 'things '), (8826, 8826, ''), (8826, 9318, 'first '), (9318, 9318, '')]);

      final lead = lrc.lyrics[16];
      final shout = lrc.lyrics[17];
      expect(lead.readableText, 'You made me a, you made me a believer ');
      expect(shout.isBGLyrics, true);
      expect(shout.timestamp, lead.timestamp);
      expect(shout.parts!.map(_partSnapshot), [(54959, 55859, 'Pain! '), (55859, 58682, '')]);
      expect(lrc.lyrics[18].timestamp, const Duration(milliseconds: 59593));

      final last = lrc.lyrics.last;
      expect(last.timestamp, const Duration(minutes: 3, seconds: 17, milliseconds: 832));
      expect(last.readableText, 'Believer ');
    });

    test('extra/word synced lrc/Animals: hyphenated syllables and background lines', () {
      final lrc = _parseLrcFixture('extra/word synced lrc/Maroon 5 - Animals.lrc');
      expect(lrc.title, 'Animals');
      expect(lrc.artist, 'Maroon 5');
      expect(lrc.lyrics.length, 107);
      expect(lrc.lyrics.where((e) => e.isBGLyrics).length, 7);
      expect(lrc.lyrics.first.timestamp, const Duration(milliseconds: 608));
      expect(lrc.lyrics.first.readableText, "Baby, I'm preying on you tonight ");

      final hyphenated = lrc.lyrics[4];
      expect(hyphenated.readableText, 'Like animals-mals ');
      expect(hyphenated.parts!.map((e) => e.lyrics), ['Like ', '', 'animals-', '', 'mals ', '']);

      final background = lrc.lyrics[69];
      expect(background.isBGLyrics, true);
      expect(background.readableText, "You can't deny ");
      expect(background.timestamp, const Duration(milliseconds: 156991));
      expect(lrc.lyrics[68].readableText, "You can't deny-ny-ny-ny ");

      final last = lrc.lyrics.last;
      expect(last.timestamp, const Duration(minutes: 3, seconds: 44, milliseconds: 524));
      expect(last.readableText, 'Yeah, yeah, yeah ');
    });

    test('extra/word synced lrc/Circles: pauses between words', () {
      final lrc = _parseLrcFixture('extra/word synced lrc/Post Malone - Circles.lrc');
      expect(lrc.title, 'Circles');
      expect(lrc.artist, 'Post Malone');
      expect(lrc.lyrics.length, 55);
      expect(lrc.lyrics.first.readableText, 'Oh, oh, oh ');

      final background = lrc.lyrics.singleWhere((e) => e.isBGLyrics);
      expect(background.readableText, 'The echoes ');
      expect(background.timestamp, const Duration(milliseconds: 121169));

      final last = lrc.lyrics.last;
      expect(last.timestamp, const Duration(minutes: 3, seconds: 24, milliseconds: 414));
      expect(last.readableText, 'Run away, run away, run away ');
      expect(_partSnapshot(last.parts![3]), (205482, 205682, ''));
      expect(_partSnapshot(last.parts![7]), (206649, 206814, ''));
      expect(last.parts!.last.endTimestamp, const Duration(milliseconds: 208350));
    });

    test('extra/word synced lrc/Blinding Lights: split syllables and background lines', () {
      final lrc = _parseLrcFixture('extra/word synced lrc/The Weeknd - Blinding Lights.lrc');
      expect(lrc.title, 'Blinding Lights');
      expect(lrc.artist, 'The Weeknd');
      expect(lrc.lyrics.length, 37);
      expect(lrc.lyrics.where((e) => e.isBGLyrics).map((e) => e.readableText), ['Back to let you know ', 'Say it on the phone ']);

      final syllables = lrc.lyrics[1];
      expect(syllables.readableText, "I've been on my own for long enough ");
      expect(_partSnapshot(syllables.parts![14]), (31839, 31996, 'e'));
      expect(_partSnapshot(syllables.parts![16]), (31996, 32529, 'nough '));

      final last = lrc.lyrics.last;
      expect(last.timestamp, const Duration(minutes: 3, seconds: 10, milliseconds: 387));
      expect(last.readableText, "No, I can't sleep until I feel your touch ");
    });

    test('weird_format.json is not lrc, ttml or a subtitle', () {
      final content = File('test/files/weird_format.json').readAsStringSync();
      expect(LrcParser.isValid(content), false);
      expect(() => Lrc.parse(content), throwsFormatException);
      expect(TtmlParser.isValid(content), false);
      expect(SubtitleParser.detectFormat(content), null);
    });
  });
}

Lrc _parseLrcFixture(String name) => Lrc.parse(File('test/files/$name').readLrcStringSync());

(int, int, String) _partSnapshot(LrcLinePart part) => (part.startTimestamp.inMilliseconds, part.endTimestamp.inMilliseconds, part.lyrics);
