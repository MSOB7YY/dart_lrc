import 'dart:io';

import 'package:test/test.dart';

import 'package:lrc/lrc.dart';

void main() {
  test('multi timestamp lrc parsing', () {
    const multiTimestampedSyncedLrc = '''[00:11.86]Line 1 lyrics
[00:24]Line 2 lyrics
[00:29.02][00:44.02]Line 3 lyrics
[00:29][00:31.1] Line 4 lyrics
[102:29][104:31.1] Line 5 lyrics
[202:30] Line 6 lyrics
''';

    final parsed = Lrc.parse(multiTimestampedSyncedLrc);

    expect(parsed.lyrics.length, 9);
  });

  test('multi language lrc parsing', () {
    const multiLanguageSyncedLrc = '''[by:Trap_Girl]
[00:01.89]
[00:06.87]Yes we started a fire, now the bedroom is burning  我们点燃了一场火，现在卧室正燃着熊熊大火
[00:12.16]Can we put it out?  我们可以把它扑灭吗？
[00:13.99]'Cause we're both saying things that we're gonna regret when|我们总会说一些令人后悔的事
[00:19.16]Every word's too loud|每个字都是那么刺耳  
[00:21.12]We gotta slow, slow, slow down;
[00:21.12]我们只需要冷静下来
[00:24.30]Gotta lay low, low, low now/现在一个人出去静静
[00:28.01]Yeah, we should go, go, go now
[00:28.01]没错我们现在都该离开
[00:31.57]'Cause things are always better
[00:31.57]事情总会好起来的''';

    final parsed = Lrc.parse(multiLanguageSyncedLrc);
    expect(parsed.lyrics.length, 16);

    const multiLanguageSyncedLrc2 = '''[by:Trap_Girl]
[00:01.89]
[00:06.87]Yes we started a fire, now the bedroom is burning
[00:12.16]Can we put it out?
[00:13.99]'Cause we're both saying things that we're gonna regret when
[00:19.16]Every word's too loud  
[00:21.12]We gotta slow, slow, slow down;
[00:24.30]Gotta lay low, low, low now
[00:28.01]Yeah, we should go, go, go now
[00:31.57]'Cause things are always better
[00:06.87]我们点燃了一场火，现在卧室正燃着熊熊大火
[00:12.16]我们可以把它扑灭吗？
[00:13.99]我们总会说一些令人后悔的事
[00:19.16]每个字都是那么刺耳  
[00:24.30]现在一个人出去静静
[00:21.12]我们只需要冷静下来
[00:28.01]没错我们现在都该离开
[00:31.57]事情总会好起来的''';

    final parsed2 = Lrc.parse(multiLanguageSyncedLrc2);
    expect(parsed2.lyrics.length, 17);
  });

  test('clean plain lyrics', () {
    const plainLyrics = '''[ti:Space Song]
[ar:Beach House]
[by:Generated using SongSync]
It was late at night, you held on tight
From an empty seat, a flash of light
It will take a while to make you smile
Somewhere in these eyes, I'm on your side
''';

    final cleaned = LrcParser.cleanPlainLyrics(plainLyrics);

    expect(cleaned.startsWith('It was late'), true);
  });

  test('word synced lyrics', () {
    final file = File(r'test\files\timed_lrc.lrc');
    final parsed = Lrc.parse(file.readLrcStringSync());

    expect(parsed.lyrics.length, 89);
    expect(parsed.lyrics[0].parts?.length, 12);
    expect(parsed.lyrics[0].readableText,
        'Look at ya, look at ya, look at ya, look at ya ');
  });

  test('word synced lyrics 6', () {
    final file = File(r'test\files\timed_lrc_6.lrc');
    final parsed = Lrc.parse(file.readLrcStringSync());

    expect(parsed.lyrics.length, 38);
    expect(parsed.lyrics[0].parts?.length, 5);
    expect(
        parsed.lyrics[0].readableText, 'Cigarettes, cigarettes out the window');
  });

  test('word synced lyrics 7 - utf16_le_bom', () {
    final file = File(r'test\files\timed_lrc_7_utf16_le_bom.lrc');
    final parsed = Lrc.parse(file.readLrcStringSync());

    expect(parsed.lyrics.length, 91);
    expect(parsed.lyrics[1].readableText.trim(), 'Hateshinai sora wo yuku');
  });

  test('word synced lyrics 9', () {
    final file = File(r'test\files\timed_lrc_9.lrc');
    final parsed = Lrc.parse(file.readLrcStringSync());

    expect(parsed.lyrics.length, 83);
    expect(parsed.lyrics[1].readableText.trim(), 'Just to save you');
  });

  test('word synced lyrics 10 - empty lines & double spaces', () {
    final file = File(r'test\files\timed_lrc_10.lrc');
    final parsed = Lrc.parse(file.readLrcStringSync());

    expect(parsed.lyrics.length, 113);
    expect(parsed.lyrics[1].parts?.length, 3);
    expect(parsed.lyrics[1].parts?[0].startTimestamp.inMilliseconds, 9970);
    expect(parsed.lyrics[1].readableText, r'$, One Time!');
    expect(
        parsed.lyrics[7].readableText, 'Hai Sab Kuchh Mast (Sab Kuchh Mast)');
    expect(parsed.lyrics[111].parts?.last.endTimestamp.inMilliseconds, 177260);
  });

  test('ttml lyrics', () async {
    final file = File(r'test\files\ttml_lrc.xml');
    final parsed = TtmlParser.parse(file.readLrcStringSync());

    expect(parsed.lyrics.length, 57);
    expect(parsed.lyrics[0].parts?.length, 8);
    expect(
        parsed.lyrics[0].readableText, "They say I'm too young to love you ");
  });

  test('ttml lyrics 2', () async {
    final file = File(r'test\files\ttml_lrc2.xml');
    final parsed = TtmlParser.parse(file.readLrcStringSync());

    expect(parsed.lyrics.length, 34);
    expect(parsed.lyrics[0].readableText,
        'See I get all the lows, while you live all the highs, boy');
  });

  test('ttml lyrics3', () async {
    final file = File(r'test\files\ttml_lrc3.ttml');
    final parsed = TtmlParser.parse(file.readLrcStringSync());

    expect(parsed.lyrics.length, 111);
    expect(parsed.lyrics[1].parts?.length, 4);
    expect(parsed.lyrics[1].readableText, 'See dha see dha ');
  });
  test('ttml lyrics4', () async {
    final file = File(r'test\files\ttml_lrc4.ttml');
    final parsed = TtmlParser.parse(file.readLrcStringSync());

    expect(parsed.lyrics.length, 52);
    expect(parsed.lyrics[1].parts?.length, 8);
    expect(
        parsed.lyrics[1].readableText, 'Tryna find the one that can fix me ');
  });
  test('ttml lyrics5', () async {
    final file = File(r'test\files\ttml_lrc5.ttml');
    final parsed = TtmlParser.parse(file.readLrcStringSync());

    expect(parsed.lyrics.length, 112);
    expect(parsed.lyrics[2].parts?.length, 0);
    expect(parsed.lyrics[2].readableText, 'Sun is down, freezing cold');
  });

  test('srt subtitles', () {
    final file = File(r'test\files\sub_lrc.srt');
    final content = file.readLrcStringSync();

    expect(SubtitleParser.detectFormat(content), SubtitleFormat.srt);
    final parsed = SubtitleParser.parse(content);

    expect(parsed.lyrics.length, 3);
    expect(parsed.lyrics[0].readableText, 'Never gonna give you up');
    expect(parsed.lyrics[1].timestamp, const Duration(milliseconds: 4500));
    expect(parsed.lyrics[1].readableText,
        'Never gonna let you down Never gonna run around');
    expect(parsed.lyrics[1].parts?.single.endTimestamp,
        const Duration(seconds: 8));
  });

  test('vtt subtitles', () {
    final file = File(r'test\files\sub_lrc.vtt');
    final content = file.readLrcStringSync();

    expect(SubtitleParser.detectFormat(content), SubtitleFormat.vtt);
    final parsed = SubtitleParser.parse(content);

    expect(parsed.lyrics.length, 3);
    expect(parsed.lyrics[0].readableText, 'Never gonna give you up');
    expect(parsed.lyrics[0].person, 1);
    expect(parsed.lyrics[1].type, LrcTypes.enhanced);
    expect(parsed.lyrics[1].parts?.length, 5);
    expect(parsed.lyrics[1].readableText, 'Never gonna let you down');
    expect(parsed.lyrics[1].parts?.first.startTimestamp,
        const Duration(milliseconds: 4500));
    expect(
        parsed.lyrics[1].parts?.last.endTimestamp, const Duration(seconds: 8));
    expect(
        parsed.lyrics[2].readableText, 'Never gonna run around & desert you');
  });

  test('sbv subtitles', () {
    final file = File(r'test\files\sub_lrc.sbv');
    final content = file.readLrcStringSync();

    expect(SubtitleParser.detectFormat(content), SubtitleFormat.sbv);
    final parsed = SubtitleParser.parse(content);

    expect(parsed.lyrics.length, 2);
    expect(parsed.lyrics[0].readableText, 'Never gonna give you up');
    expect(parsed.lyrics[1].readableText,
        'Never gonna let you down Never gonna run around');
  });

  test('ass subtitles', () {
    final file = File(r'test\files\sub_lrc.ass');
    final content = file.readLrcStringSync();

    expect(SubtitleParser.detectFormat(content), SubtitleFormat.ssa);
    final parsed = SubtitleParser.parse(content);

    expect(parsed.title, 'Never Gonna Give You Up');
    expect(parsed.author, 'Rick Astley');
    expect(parsed.lyrics.length, 3);
    expect(parsed.lyrics[0].readableText, 'Never gonna give you up');
    expect(parsed.lyrics[1].type, LrcTypes.enhanced);
    expect(parsed.lyrics[1].parts?.length, 5);
    expect(parsed.lyrics[1].readableText, 'Never gonna let you down');
    expect(parsed.lyrics[1].parts?.first.endTimestamp,
        const Duration(milliseconds: 5000));
    expect(
        parsed.lyrics[1].parts?.last.endTimestamp, const Duration(seconds: 8));
    expect(parsed.lyrics[2].readableText,
        'Never gonna run around, and desert you');
    expect(parsed.lyrics[2].person, 2);
    expect(parsed.personCount, 2);
  });

  test('word synced last word ends at next later line', () {
    const content = '''[00:42.11]<00:42.11>Aaj <00:46.69>ho <00:47.29>gayi
[00:42.11]From today
[00:44.00]v2:<00:44.00>duet <00:45.00>line <00:46.00>
[00:48.19]<00:48.19>Aaj <00:52.00>ho <00:52.45>gaya''';

    final parsed = Lrc.parse(content);
    final first = parsed.lyrics[0].parts!.last;
    expect(first.lyrics, 'gayi');
    expect(first.startTimestamp, const Duration(milliseconds: 47290));
    expect(first.endTimestamp, const Duration(milliseconds: 48190));

    final last = parsed.lyrics.last;
    expect(last.readableText, 'Aaj ho gaya');
    expect(last.parts!.last.lyrics, 'gaya');
    expect(last.parts!.last.endTimestamp - last.parts!.last.startTimestamp,
        const Duration(milliseconds: 2130));
  });

  test('word synced multi timestamp line parts follow each timestamp', () {
    const content = '[00:10.00][01:20.00]<00:10.00>la <00:11.00>la<00:12.00>';

    final parsed = Lrc.parse(content);
    expect(parsed.lyrics[0].parts!.first.startTimestamp,
        const Duration(seconds: 10));
    expect(parsed.lyrics[1].parts!.first.startTimestamp,
        const Duration(seconds: 80));
    expect(
        parsed.lyrics[1].parts!.last.endTimestamp, const Duration(seconds: 82));
  });

  test('word synced parts follow ui offset', () {
    const content = '''[offset:500]
[00:10.00]<00:10.00>la <00:11.00>la<00:12.00>
[00:20.00]<00:20.00>next<00:21.00>''';

    final ui = Lrc.parse(content)
        .forUiDisplay(0, extraOffsetDuration: const Duration(seconds: 1))
        .uiLyricsLines;
    expect(ui[0].timestamp, const Duration(milliseconds: 10500));
    expect(
        ui[0].parts!.first.startTimestamp, const Duration(milliseconds: 10500));
    expect(ui[0].parts!.last.endTimestamp, const Duration(milliseconds: 12500));
    expect(ui[1].timestamp, const Duration(milliseconds: 12500));
    expect(ui[2].timestamp, const Duration(milliseconds: 20500));
  });
  test('format keeps word parts, singers, background lines and long timestamps',
      () {
    const content = '''[ar:Someone]
[offset:120]
[00:10.00]v1: <00:10.00>Hello <00:10.50>there<00:11.00><00:11.20>friend<00:12.00>
[bg:<00:10.40>ooh<00:11.00>]
[00:13.00]v2: plain duet line
[00:13.00]translated line
[61:02.50]past an hour''';

    final parsed = Lrc.parse(content);
    final formatted = parsed.format();
    final reparsed = Lrc.parse(formatted);

    expect(reparsed.artist, 'Someone');
    expect(reparsed.offset, 120);
    expect(reparsed.lyrics.length, parsed.lyrics.length);
    for (var i = 0; i < parsed.lyrics.length; i++) {
      final a = parsed.lyrics[i];
      final b = reparsed.lyrics[i];
      expect(b.timestamp, a.timestamp);
      expect(b.readableText, a.readableText);
      expect(b.person, a.person);
      expect(b.parts?.length, a.parts?.length);
      final partsA = a.parts ?? const <LrcLinePart>[];
      final partsB = b.parts ?? const <LrcLinePart>[];
      for (var j = 0; j < partsA.length; j++) {
        expect(partsB[j].lyrics, partsA[j].lyrics);
        expect(partsB[j].startTimestamp, partsA[j].startTimestamp);
        expect(partsB[j].endTimestamp, partsA[j].endTimestamp);
      }
    }
    expect(reparsed.lyrics.last.timestamp,
        const Duration(minutes: 61, seconds: 2, milliseconds: 500));
    expect(formatted, contains('[bg:<00:10.40>ooh<00:11.00>]'));
  });

  test('timestamp parsing', () {
    expect(LrcParser.parseTimestamp('01:02.34'),
        const Duration(minutes: 1, seconds: 2, milliseconds: 340));
    expect(LrcParser.parseTimestamp(' 75:00 '), const Duration(minutes: 75));
    expect(LrcParser.parseTimestamp('1:2:3'), null);
    expect(LrcParser.parseTimestamp('abc'), null);
  });
}
