// by claude
import 'dart:io';

import 'package:test/test.dart';

import 'package:lrc/lrc.dart';

void main() {
  test('apple music: agents, background vocals, head translations and transliterations', () {
    const content = '<tt xmlns="http://www.w3.org/ns/ttml" xmlns:itunes="http://music.apple.com/lyric-ttml-internal" xmlns:ttm="http://www.w3.org/ns/ttml#metadata" itunes:timing="Word" xml:lang="ja">'
        '<head><metadata>'
        '<ttm:agent type="person" xml:id="v1"/><ttm:agent type="person" xml:id="v2"/><ttm:agent type="group" xml:id="v1000"/>'
        '<iTunesMetadata xmlns="http://music.apple.com/lyric-ttml-internal">'
        '<translations><translation type="replacement" xml:lang="en">'
        '<text for="L1">Hello world <span ttm:role="x-bg">(oh)</span></text>'
        '</translation></translations>'
        '<transliterations><transliteration xml:lang="ja-Latn">'
        '<text for="L1"><span begin="1.000" end="1.500">kon</span><span begin="1.500" end="2.000">nichiwa</span> <span begin="2.000" end="3.000">sekai</span></text>'
        '</transliteration></transliterations>'
        '<songwriters><songwriter>A</songwriter><songwriter>B &amp; C</songwriter></songwriters>'
        '</iTunesMetadata>'
        '</metadata></head>'
        '<body dur="1:02.500"><div itunes:songPart="Verse">'
        '<p begin="1.000" end="3.500" itunes:key="L1" ttm:agent="v1">'
        '<span begin="1.000" end="1.500">こん</span><span begin="1.500" end="2.000">にちは</span> <span begin="2.000" end="3.000">世界</span>'
        '<span ttm:role="x-bg"><span begin="3.000" end="3.500">(おー)</span></span>'
        '</p>'
        '<p begin="4.000" end="5.000" itunes:key="L2" ttm:agent="v2"><span begin="4.000" end="5.000">duet</span></p>'
        '<p begin="6.000" end="7.000" itunes:key="L3" ttm:agent="v1000"><span begin="6.000" end="6.500">all</span> <span begin="6.500" end="7.000">together</span></p>'
        '</div></body></tt>';
    final lrc = TtmlParser.parse(content);
    expect(lrc.type, LrcTypes.enhanced);
    expect(lrc.personCount, 3);
    expect(lrc.author, 'A, B & C');
    expect(lrc.language, 'ja');
    expect(lrc.length, '01:02.50');
    expect(_snapshot(lrc), [
      (1000, 1, LrcTypes.enhanced, 'こん|にちは |世界', 'こんにちは 世界'),
      (1000, 1, LrcTypes.simple, null, 'Hello world'),
      (1000, 1, LrcTypes.enhanced, 'kon|nichiwa |sekai', 'konnichiwa sekai'),
      (3000, 0, LrcTypes.enhanced, '(おー)', '(おー)'),
      (3000, 0, LrcTypes.simple, null, '(oh)'),
      (4000, 2, LrcTypes.enhanced, 'duet', 'duet'),
      (6000, 1000, LrcTypes.enhanced, 'all |together', 'all together'),
    ]);
    final firstParts = lrc.lyrics.first.parts!.map((e) => (e.startTimestamp.inMilliseconds, e.endTimestamp.inMilliseconds));
    expect(firstParts, [(1000, 1500), (1500, 2000), (2000, 3000)]);
  });

  test('amll: inline translations and romanizations, metadata', () {
    const content = '<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata" xmlns:amll="http://www.example.com/ns/amll">'
        '<head><metadata>'
        '<amll:meta key="musicName" value="Song"/><amll:meta key="artists" value="X"/><amll:meta key="artists" value="Y"/>'
        '<amll:meta key="album" value="Al"/><amll:meta key="ttmlAuthorGithubLogin" value="someone"/>'
        '</metadata></head>'
        '<body><div>'
        '<p begin="00:01.000" end="00:03.000" ttm:agent="v1">'
        '<span begin="00:01.000" end="00:02.000">사랑</span> <span begin="00:02.000" end="00:03.000">해</span>'
        '<span ttm:role="x-translation" xml:lang="en">love you</span>'
        '<span ttm:role="x-roman">sarang hae</span>'
        '<span ttm:role="x-bg">'
        '<span begin="00:02.500" end="00:03.500">(yeah</span> <span begin="00:03.500" end="00:04.000">yeah)</span>'
        '<span ttm:role="x-translation" xml:lang="en">(yeah yeah)</span>'
        '</span>'
        '</p>'
        '</div></body></tt>';
    final lrc = TtmlParser.parse(content);
    expect(lrc.title, 'Song');
    expect(lrc.artist, 'X, Y');
    expect(lrc.album, 'Al');
    expect(lrc.creator, 'someone');
    expect(lrc.personCount, 1);
    expect(_snapshot(lrc), [
      (1000, 1, LrcTypes.enhanced, '사랑 |해', '사랑 해'),
      (1000, 1, LrcTypes.simple, null, 'love you'),
      (1000, 1, LrcTypes.simple, null, 'sarang hae'),
      (2500, 0, LrcTypes.enhanced, '(yeah |yeah)', '(yeah yeah)'),
      (2500, 0, LrcTypes.simple, null, '(yeah yeah)'),
    ]);
  });

  test('syllables join, spaces and indentation between words', () {
    const content = '<tt><body><div>\n'
        '  <p begin="1s" end="4s">\n'
        '    <span begin="1s" end="2s">sick</span>\n'
        '    <span begin="2s" end="3s">ly </span>\n'
        '    <span begin="3s" end="4s">done</span>\n'
        '  </p>\n'
        '  <p begin="5s" end="8s"><span begin="5s" end="6s">a</span>, <span begin="6s" end="7s"> b</span><span begin="7s" end="8s">c</span></p>\n'
        '</div></body></tt>';
    final lrc = TtmlParser.parse(content);
    expect(_snapshot(lrc), [
      (1000, null, LrcTypes.enhanced, 'sick|ly |done', 'sickly done'),
      (5000, null, LrcTypes.enhanced, 'a, |b|c', 'a, bc'),
    ]);
  });

  test('line synced: namespace prefixes, styling spans, br, entities, cdata, ruby and empty lines', () {
    const content = '<tt:tt xmlns:tt="http://www.w3.org/ns/ttml" xmlns:tts="http://www.w3.org/ns/ttml#styling">'
        '<tt:body><tt:div>'
        '<tt:p begin="10s" end="12s">Rock &amp; <tt:span tts:color="red">roll</tt:span><tt:br/>all &#x6E;ight</tt:p>'
        '<tt:p begin="12.5s" dur="1s"><![CDATA[a <b> & c]]></tt:p>'
        '<tt:p begin="00:00:14.000"><tt:span tts:ruby="container"><tt:span tts:ruby="base">漢字</tt:span><tt:span tts:ruby="text">かんじ</tt:span></tt:span></tt:p>'
        '<tt:p begin="15s" end="16s"/>'
        '<!-- <tt:p begin="17s">commented</tt:p> -->'
        '</tt:div></tt:body></tt:tt>';
    final lrc = TtmlParser.parse(content);
    expect(lrc.type, LrcTypes.simple);
    expect(_snapshot(lrc), [
      (10000, null, LrcTypes.simple, null, 'Rock & roll all night'),
      (12500, null, LrcTypes.simple, null, 'a <b> & c'),
      (14000, null, LrcTypes.simple, null, '漢字'),
      (15000, null, LrcTypes.simple, null, ''),
    ]);
  });

  test('entities, html named ones included', () {
    const content = '<tt><body><p begin="1s">caf&eacute; &#233; &#x1F600; &amp;lt; &quot;a&apos;</p></body></tt>';
    expect(TtmlParser.parse(content).lyrics.single.readableText, 'café é 😀 &lt; "a\'');
  });

  test('time expressions', () {
    const times = {
      '1.5s': 1500,
      '1500ms': 1500,
      '0.5m': 30000,
      '0.01h': 36000,
      '00:01:02.345': 62345,
      '01:02.3': 62300,
      '3': 3000,
      '00:00:02:15': 2500,
      '45f': 1500,
      '20000000t': 2000,
      '7.0004': 7000,
    };
    final paragraphs = times.keys.map((time) => '<p begin="$time">$time</p>').join();
    final content = '<tt xmlns:ttp="http://www.w3.org/ns/ttml#parameter" ttp:frameRate="30" ttp:tickRate="10000000"><body><div>$paragraphs</div></body></tt>';
    final lrc = TtmlParser.parse(content);
    final parsedTimes = {for (final line in lrc.lyrics) line.readableText: line.timestamp.inMilliseconds};
    expect(parsedTimes, times);
  });

  test('lrc text inside a line, escaped or not', () {
    const content = '<tt><body><div>'
        '<p begin="1.000s" end="3s">v2:&lt;00:01.000&gt;Hi &lt;00:02.000&gt;there&lt;00:03.000&gt;</p>'
        '<p begin="4s">v1:<00:04.000>Raw <00:05.000>lrc<00:06.000></p>'
        '</div></body></tt>';
    final lrc = TtmlParser.parse(content);
    expect(lrc.personCount, 2);
    expect(_snapshot(lrc), [
      (1000, 2, LrcTypes.enhanced, 'Hi |there', 'Hi there'),
      (4000, 1, LrcTypes.enhanced, 'Raw |lrc', 'Raw lrc'),
    ]);
  });

  test('div agents, out of order background vocals, and words without an end', () {
    const content = '<tt><body>'
        '<div ttm:agent="v2">'
        '<p begin="1s" end="3s"><span begin="1s">a</span> <span begin="2s">b</span><span ttm:role="x-bg"><span begin="4s" end="5s">bg</span></span></p>'
        '</div>'
        '<p begin="3.5s" end="6s"><span begin="3.5s" end="4s">c</span> <span begin="4s" dur="1s">d</span></p>'
        '</body></tt>';
    final lrc = TtmlParser.parse(content);
    expect(_snapshot(lrc), [
      (1000, 2, LrcTypes.enhanced, 'a |b', 'a b'),
      (3500, null, LrcTypes.enhanced, 'c |d', 'c d'),
      (4000, 0, LrcTypes.enhanced, 'bg', 'bg'),
    ]);
    final firstParts = lrc.lyrics.first.parts!.map((e) => (e.startTimestamp.inMilliseconds, e.endTimestamp.inMilliseconds));
    expect(firstParts, [(1000, 2000), (2000, 3000)]);
    expect(lrc.lyrics[1].parts!.last.endTimestamp.inMilliseconds, 5000);
  });

  test('single word lines stay plain unless the lyrics are word synced', () {
    const lineSynced = '<tt><body><p begin="1s" end="2s"><span begin="1s" end="2s">whole line</span></p></body></tt>';
    expect(TtmlParser.parse(lineSynced).lyrics.single.type, LrcTypes.simple);
    const declaredWordSynced = '<tt xmlns:itunes="http://music.apple.com/lyric-ttml-internal" itunes:timing="Word"><body><p begin="1s" end="2s"><span begin="1s" end="2s">word</span></p></body></tt>';
    expect(TtmlParser.parse(declaredWordSynced).lyrics.single.type, LrcTypes.enhanced);
  });

  test('broken documents still give their lines', () {
    const unclosedLine = '<tt><body><p begin="1s">a<p begin="2s">b</p></body></tt>';
    expect(TtmlParser.parse(unclosedLine).lyrics.map((e) => e.readableText), ['a', 'b']);
    const truncated = '<tt><body><p begin="1s"><span begin="1s" end="2s">a</span> <span begin="2s" end="3s">b';
    expect(TtmlParser.parse(truncated).lyrics.single.readableText, 'a b');
    const unterminatedTag = '<tt><body><p begin="1s">a</p><p begin="2';
    expect(TtmlParser.parse(unterminatedTag).lyrics.single.readableText, 'a');
  });

  test('isValid', () {
    for (final name in ['ttml_lrc.xml', 'ttml_lrc2.xml', 'ttml_lrc3.ttml', 'ttml_lrc4.ttml', 'ttml_lrc5.ttml']) {
      final content = File('test/files/$name').readLrcStringSync();
      expect(TtmlParser.isValid(content), true, reason: name);
    }
    expect(TtmlParser.isValid('<tt:p tt:begin="1s">a</tt:p>'), true);
    expect(TtmlParser.isValid('<html><body><p>hello</p><span data-begin="1">x</span></body></html>'), false);
    for (final name in ['timed_lrc.lrc', 'sub_lrc.srt', 'weird_format.json', 'qrc_lrc.qrc']) {
      final content = File('test/files/$name').readLrcStringSync();
      expect(TtmlParser.isValid(content), false, reason: name);
      expect(TtmlParser.parse(content).lyrics, isEmpty, reason: name);
    }
  });
}

/// parts lyrics are joined with `|`.
List<(int, int?, LrcTypes, String?, String)> _snapshot(Lrc lrc) {
  return lrc.lyrics.map((e) => (e.timestamp.inMilliseconds, e.person, e.type, e.parts?.map((p) => p.lyrics).join('|'), e.readableText)).toList();
}
