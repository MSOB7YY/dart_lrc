part 'multi_timestamp_parser.dart';

/// The parsed LRC class.
///
/// You can instantiate this class directly
/// or parse a string using `Lrc.parse()`.
class Lrc {
  /// The overall type of LRC for this object
  final LrcTypes type;

  /// The name of the artist of the song (optional)
  ///
  /// This corresponds to the ID tag `[ar:]`.
  final String? artist;

  /// The name of the album of the song (optional)
  ///
  /// This corresponds to the ID tag `[al:]`.
  final String? album;

  /// The title of the song (optional)
  ///
  /// This corresponds to the ID tag `[ti:]`.
  final String? title;

  /// The name of the author of the lyrics (optional)
  ///
  /// This corresponds to the ID tag `[au:]`.
  final String? author;

  /// The name of the creator of the LRC file (optional)
  ///
  /// This corresponds to the ID tag `[by:]`.
  final String? creator;

  /// The name of the program that created the LRC file (optional)
  ///
  /// This corresponds to the ID tag `[re:]`.
  final String? program;

  /// The version of the program that created the LRC file (optional)
  ///
  /// This corresponds to the ID tag `[ve:]`.
  final String? version;

  /// The length of the song (optional)
  ///
  /// This corresponds to the ID tag `[length:]`.
  final String? length;

  /// The language of the song, using an IETF BCP 47 language tag (optional)
  ///
  /// This corresponds to the ID tag `[la:]`.
  final String? language;

  /// Offset of time in milliseconds, can be positive [shifts time up]
  /// or negative [shifts time down] (optional)
  ///
  /// This corresponds to the ID tag `[offset:]`.
  final int? offset;

  /// The list of lyric lines
  final List<LrcLine> lyrics;

  final int personCount;

  /// Handy parameter to get a stream of the lyrics.
  /// See `List<LrcLine>.toStream()`.
  Stream<LrcStream> get stream => lyrics.toStream();

  /// Use this constructor if you want to manually create an LRC from scratch.
  /// Otherwise, parse an LRC string using [Lrc.parse].
  const Lrc({
    this.type = LrcTypes.simple,
    required this.lyrics,
    this.artist,
    this.album,
    this.title,
    this.creator,
    this.author,
    this.program,
    this.version,
    this.length,
    this.offset,
    this.language,
    this.personCount = 1,
  });

  /// Format the lrc to a readable string that can then be
  /// outputted to an LRC file.
  String format() {
    var buffer = StringBuffer();

    if (artist != null) buffer.writeln('[ar:$artist]');
    if (album != null) buffer.writeln('[al:$album]');
    if (title != null) buffer.writeln('[ti:$title]');
    if (length != null) buffer.writeln('[length:$length]');
    if (creator != null) buffer.writeln('[by:$creator]');
    if (author != null) buffer.writeln('[au:$author]');
    if (offset != null) buffer.writeln('[offset:${offset.toString()}]');
    if (program != null) buffer.writeln('[re:$program]');
    if (version != null) buffer.writeln('[ve:$version]');
    if (language != null) buffer.writeln('[la:$language]');

    final lrcLength = lyrics.length;
    for (var i = 0; i < lrcLength; i++) {
      buffer.writeln(lyrics[i].formattedLine);
    }

    return buffer.toString();
  }

  static List<String> _splitLines(String data) {
    var lines = <String>[];
    var end = data.length;
    var sliceStart = 0;
    var char = 0;
    for (var i = 0; i < end; i++) {
      var previousChar = char;
      char = data.codeUnitAt(i);
      if (char != 13) {
        if (char != 10) continue;
        if (previousChar == 13) {
          sliceStart = i + 1;
          continue;
        }
      }
      lines.add(data.substring(sliceStart, i));
      sliceStart = i + 1;
    }
    if (sliceStart < end) lines.add(data.substring(sliceStart, end));
    return lines;
  }

  static List<String> splitMultiLanguageLine(String lyric) {
    return lyric.split(RegExp(r'(\s{2,}|\|)(?=\S)'));
  }

  static Iterable<LrcLinePart> extractTimeStampPartFromLine(String line) sync* {
    for (var j in RegExp(r'<(([0-9]{1,}):([0-9]{1,})\.([0-9]{1,})?)>([^<]+)')
        .allMatches(line)) {
      final timestamp = Duration(
        minutes: int.tryParse(j.group(2)!) ?? 0,
        seconds: int.tryParse(j.group(3)!) ?? 0,
        milliseconds: (int.tryParse(j.group(4)!) ?? 0),
      );
      yield LrcLinePart(
        timestamp: timestamp,
        lyrics: j.group(5)?.trim() ?? '',
      );
    }
  }

  /// Parses an LRC from a string. Throws a `FormatExeption`
  /// if the inputted string is not valid.
  static Lrc parse(String parsed) {
    if (!isValid(parsed)) {
      throw FormatException('The inputted string is not a valid LRC file');
    }

    // split string into lines, code from Linesplitter().convert(data)
    var lines = _splitLines(parsed);

    // temporary storer variables
    String? artist,
        album,
        title,
        length,
        author,
        creator,
        offset,
        program,
        version,
        language;
    LrcTypes? type;
    var lyrics = <LrcLine>[];

    final personToIndex = <String, int>{};
    var registeredTimestamps = <Duration>{};
    var shouldSortLyrics = false;

    String? setIfMatchTag(String toMatch, String tag) =>
        (RegExp(r'^\[' + tag + r':.*\]$').hasMatch(toMatch))
            ? toMatch.substring(tag.length + 2, toMatch.length - 1).trim()
            : null;

    // loop thru each lines
    for (var i = 0; i < lines.length; i++) {
      var l = lines[i];
      artist ??= setIfMatchTag(l, 'ar');
      album ??= setIfMatchTag(l, 'al');
      title ??= setIfMatchTag(l, 'ti');
      author ??= setIfMatchTag(l, 'au');
      length ??= setIfMatchTag(l, 'length');
      creator ??= setIfMatchTag(l, 'by');
      offset ??= setIfMatchTag(l, 'offset');
      program ??= setIfMatchTag(l, 're');
      version ??= setIfMatchTag(l, 've');
      language ??= setIfMatchTag(l, 'la');

      if (_LRCMultiTimestampParser._durRegex.hasMatch(l)) {
        var lineType = LrcTypes.simple;
        List<LrcLinePart>? parts;

        final lrclineDetails = _LRCMultiTimestampParser.parseLine(l);
        final lyric = lrclineDetails.lineText;
        final timestamps = lrclineDetails.timestamps;

        if (shouldSortLyrics == false) {
          if (timestamps.length > 1) {
            // -- means it has multi timestamps
            shouldSortLyrics = true;
          }
          if (timestamps
              .any((element) => registeredTimestamps.contains(element))) {
            // -- means it has multi language in the end of the file
            shouldSortLyrics = true;
          }
        }

        int? person;

        // checkers for different types of LRCs
        if (lyric.contains(RegExp(r'^\w:'))) {
          //if extended
          type = (type == LrcTypes.enhanced)
              ? LrcTypes.extended_enhanced
              : LrcTypes.extended;

          final personText = lyric[0];
          person = personToIndex[personText] ??= personToIndex.length + 1;

          parts = [];
          parts.add(LrcLinePart(
            timestamp: timestamps.first,
            lyrics: lyric.substring(2),
          ));

          lineType = LrcTypes.extended;
        } else if (lyric
            .contains(RegExp(r'<[0-9]{1,}:[0-9]{1,}(\.[0-9]{1,})?>'))) {
          // if enhanced
          type = (type == LrcTypes.extended)
              ? LrcTypes.extended_enhanced
              : LrcTypes.enhanced;
          parts = [];
          lineType = LrcTypes.enhanced;

          final personText = lyric.substring(0, lyric.indexOf('<'));
          person = personToIndex[personText] ??= personToIndex.length + 1;

          parts.addAll(extractTimeStampPartFromLine(lyric));
        }

        final lyricSplit = splitMultiLanguageLine(lyric);
        for (var i = 0; i < lyricSplit.length; i++) {
          final part = lyricSplit[i];
          final readableText = parts != null && parts.isNotEmpty
              ? parts.map((e) => e.lyrics).join(' ')
              : part;
          for (final linetimestamp in timestamps) {
            registeredTimestamps.add(linetimestamp);
            lyrics.add(LrcLine(
              timestamp: linetimestamp,
              lyrics: part,
              readableText: readableText.isNotEmpty ? readableText : part,
              type: lineType,
              parts: parts,
              person: person,
            ));
          }
        }
      }
    }

    if (type == LrcTypes.enhanced || type == LrcTypes.extended_enhanced) {
      // extract bg tags
      for (final m in RegExp(r'\[bg:(.*)\]').allMatches(parsed)) {
        final text = m.group(1);
        if (text == null) continue;
        final parts = extractTimeStampPartFromLine(text).toList();
        if (parts.isEmpty) continue;
        final newLine = LrcLine(
          timestamp: parts[0].timestamp,
          lyrics: text,
          readableText: parts.map((e) => e.lyrics).join(' '),
          type: type ?? LrcTypes.enhanced,
          parts: parts,
          person: 0,
        );
        lyrics.add(newLine);
        shouldSortLyrics = true;
      }
    }

    if (shouldSortLyrics) {
      lyrics.sort((a, b) =>
          a.timestamp.inMicroseconds.compareTo(b.timestamp.inMicroseconds));
    }

    var personCount =
        personToIndex.values.where((element) => element > 0).length;
    if (personCount <= 0) personCount = 1;

    return Lrc(
      type: type ?? LrcTypes.simple,
      artist: artist,
      album: album,
      title: title,
      author: author,
      length: length,
      creator: creator,
      offset: (offset != null) ? int.tryParse(offset) : null,
      program: program,
      version: version,
      lyrics: lyrics,
      language: language,
      personCount: personCount,
    );
  }

  /// Checks if the string [input] is a valid LRC using Regex.
  static bool isValid(String input) =>
      RegExp(r'\[(\d{1,}).+\]').hasMatch(input);

  static String cleanPlainLyrics(String input) {
    final regex = RegExp(
        r'([\r\n]*\[((ti)|(a[rlu])|(by)|([rv]e)|(length)|(offset)|(la)):.+\][\r\n]*)');
    return input.replaceAll(regex, '');
  }

  @override
  String toString() {
    var lyrics = this.lyrics.join('\n');

    return '''
    Type: '$type'
    Artist: '$artist'
    Album: '$album'
    Title: '$title'
    Author: '$author'
    Creator: '$creator'
    Program: '$program'
    Length: '$length'
    Language: '$language'
    Offset: '$offset'
    Lyrics: $lyrics
    ''';
  }
}

///The types of LRC
enum LrcTypes {
  ///A simple LRC, with no extra formatting, etc
  simple,

  ///LRC with modifiers at the start in the form `A: foo`
  extended,

  ///LRC with additional timestamps per line in the form `<00:00.00> foo`
  enhanced,

  ///LRC that some lines are extended and some are enhanced
  extended_enhanced
}

///A line of lyrics, with its defined duration and raw lyrics
class LrcLine {
  ///timestamp for the lyrics wherein it'll be displayed
  final Duration timestamp;

  ///the raw lyrics for the line
  final String lyrics;

  final String readableText;

  final List<LrcLinePart>? parts;

  ///the type of lrc for this line
  final LrcTypes type;

  final int? person;

  bool get isBGLyrics => person == 0;

  const LrcLine({
    required this.timestamp,
    required this.lyrics,
    required this.readableText,
    required this.type,
    required this.parts,
    required this.person,
  });

  LrcLine withTimeStamp({required Duration newTimestamp}) {
    return LrcLine(
      timestamp: newTimestamp,
      lyrics: lyrics,
      readableText: readableText,
      type: type,
      person: person,
      parts: parts,
    );
  }

  ///get the string for a formatted line
  String get formattedLine {
    ///function to add leading zeros
    String f(int x) => x.toString().padLeft(2, '0');

    // LRC format doesn't accept hours.
    final minutes = timestamp.inMinutes % 60,
        seconds = timestamp.inSeconds % 60,
        hundreds = timestamp.inMilliseconds % 1000 ~/ 10;

    return '[${f(minutes)}:${f(seconds)}.${f(hundreds)}]$lyrics';
  }

  @override
  String toString() {
    return '''
      Timestamp: '$timestamp'
      Lyrics: '$lyrics'
      Parts: '$parts'
      Person: '$person'
    ''';
  }
}

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

/// A data class to store each yielding of the stream
class LrcStream {
  /// The previous line. Is null if the current line is the fist position.
  LrcLine? previous;

  /// Tthe current line
  LrcLine current;

  /// The next line. Is null if the current line is the last position.
  LrcLine? next;

  /// The duration from the current to the next. Is null if the current line is the last position.
  Duration? duration;

  /// The position of the current line
  int position;

  /// The total number of lines in the stream
  int length;

  /// The main constructor for a LrcStream
  LrcStream(
      {this.previous,
      required this.current,
      this.next,
      this.duration,
      required this.position,
      required this.length})
      //position should be greater than or equal to 0
      : assert(position >= 0),
        //the length should be greater than or equal to the position
        assert(length >= position),
        //previous is null only if position is 0
        assert((previous == null) ? position == 0 : true),
        //next is null only if position is the last
        assert((next == null) ? position == length : true);
}

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
  Lrc toLrc() => Lrc.parse(this);

  /// Handy extension getter if the given string is a valid LRC
  bool get isValidLrc => Lrc.isValid(this);
}
