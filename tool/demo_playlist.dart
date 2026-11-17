// Writes the demo playlist used for App Review and player testing, and the
// TV guide that goes with it.
//
//   dart run tool/demo_playlist.dart [--out demo] [--days 14] [--start YYYY-MM-DD] [--check]
//
// <out>/okx-demo.m3u       six test channels and four open films (see demo/README.md)
// <out>/okx-demo-epg.xml   programmes for the test channels, from 00:00 UTC on
//                          --start (default: today, UTC) for --days days
//
// --check also fetches every stream and fails (exit code 1, one line per
// problem) unless each one answers over HTTPS with a real HLS playlist whose
// first variant and first segment load, or with video bytes for a film file.
//
// The playlist is the only source of truth for channel ids and names: the
// M3U and the guide are written from the same list, so they never drift.
import 'dart:convert';
import 'dart:io';

/// Where the files are published (GitHub Pages of the okxiptv-data repo).
const pagesBase = 'https://amedeguerre-cpu.github.io/okxiptv-data/demo/';

class Show {
  final String title;
  final String desc;
  final int minutes;
  const Show(this.title, this.desc, this.minutes);
}

class DemoChannel {
  /// Guide id. Written to the guide always, and to the playlist only when
  /// [idInPlaylist] is true: one channel is left without an id on purpose,
  /// so the player has to find its guide by the channel name.
  final String id;
  final bool idInPlaylist;
  final String name;
  final String url;
  final List<Show> shows;
  const DemoChannel(this.id, this.name, this.url, this.shows, {this.idInPlaylist = true});
}

class DemoFilm {
  final String name;
  final String url;
  const DemoFilm(this.name, this.url);
}

const liveGroup = 'Live Test';
const filmGroup = 'Movies';

const _bars = Show('Colour Bars', 'Colour bars with a running clock, for checking picture and sync.', 60);
const _signal = Show('Signal Check', 'A steady test signal for checking the connection.', 30);
const _tone = Show('Tone and Clock', 'Test tone with an on-screen clock.', 30);
const _morning = Show('Morning Test Card', 'The day starts with the test card.', 90);
const _night = Show('Night Loop', 'The test pattern runs through the night.', 120);
const _subs = Show('Subtitle Check', 'Test pattern with subtitle tracks in several languages.', 45);
const _hevc = Show('HEVC Picture Check', 'High-efficiency video test pattern.', 60);
const _count = Show('Frame Counter', 'A frame counter and timecode for checking smooth playback.', 45);

// Channels 1 and 2 link the 720p media playlist rather than the master: the
// master also lists an audio-only variant, which a player on a slow
// connection could pick and show no picture.
const channels = [
  DemoChannel(
    'okx-demo-1',
    'Test Channel 1',
    'https://demo.unified-streaming.com/k8s/live/stable/live.isml/live-audio_eng=128000-video=1000000.m3u8',
    [_morning, _bars, _signal, _tone, _bars, _night],
  ),
  DemoChannel(
    'okx-demo-2',
    'Test Channel 2',
    'https://demo.unified-streaming.com/k8s/live/scte35.isml/scte35-audio_eng=128000-video=1000000.m3u8',
    [_bars, _tone, _signal, _bars, _night, _morning],
  ),
  DemoChannel(
    'okx-demo-3',
    'Test Channel 3',
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8',
    [_signal, _bars, _count, _tone, _night],
  ),
  DemoChannel(
    'okx-demo-4',
    'Test Channel 4',
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8',
    [_subs, _bars, _signal, _subs, _night],
  ),
  DemoChannel(
    'okx-demo-5',
    'Test Channel 5',
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8',
    [_count, _signal, _bars, _tone, _count, _night],
  ),
  DemoChannel(
    'okx-demo-6',
    'Test Channel 6',
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8',
    [_hevc, _signal, _bars, _hevc, _night],
    idInPlaylist: false,
  ),
];

const films = [
  DemoFilm('Big Buck Bunny (2008)', 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8'),
  DemoFilm('Elephants Dream (2006)', 'https://download.blender.org/ED/elephantsdream-720-h264-st-aac.mov'),
  DemoFilm('Sintel (2010)', 'https://download.blender.org/durian/movies/Sintel.2010.1080p.mkv'),
  DemoFilm('Tears of Steel (2012)', 'https://download.blender.org/demo/movies/ToS/tears_of_steel_720p.mov'),
];

String _attr(String s) => s.replaceAll('"', "'");

String buildM3u() {
  final b = StringBuffer('#EXTM3U url-tvg="${pagesBase}okx-demo-epg.xml"\n');
  for (final c in channels) {
    final id = c.idInPlaylist ? 'tvg-id="${c.id}" ' : '';
    b
      ..writeln('#EXTINF:-1 ${id}tvg-name="${_attr(c.name)}" group-title="$liveGroup",${c.name}')
      ..writeln(c.url);
  }
  for (final f in films) {
    b
      ..writeln('#EXTINF:-1 tvg-name="${_attr(f.name)}" group-title="$filmGroup",${f.name}')
      ..writeln(f.url);
  }
  return b.toString();
}

String _xml(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _time(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}00 +0000';
}

/// Programmes from 00:00 UTC on [start] for [days] days. Each channel runs
/// its own cycle of shows, started at a different point so the channels
/// don't change programme at the same moment.
String buildEpg(DateTime start, int days) {
  final from = DateTime.utc(start.year, start.month, start.day);
  final until = from.add(Duration(days: days));
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<tv generator-info-name="okxiptv-data demo_playlist.dart">');
  for (final c in channels) {
    b
      ..writeln('  <channel id="${_xml(c.id)}">')
      ..writeln('    <display-name lang="en">${_xml(c.name)}</display-name>')
      ..writeln('  </channel>');
  }
  for (var i = 0; i < channels.length; i++) {
    final c = channels[i];
    var t = from;
    var k = i % c.shows.length;
    while (t.isBefore(until)) {
      final s = c.shows[k];
      var end = t.add(Duration(minutes: s.minutes));
      if (end.isAfter(until)) end = until;
      b
        ..writeln('  <programme start="${_time(t)}" stop="${_time(end)}" channel="${_xml(c.id)}">')
        ..writeln('    <title lang="en">${_xml(s.title)}</title>')
        ..writeln('    <desc lang="en">${_xml(s.desc)}</desc>')
        ..writeln('  </programme>');
      t = end;
      k = (k + 1) % c.shows.length;
    }
  }
  b.writeln('</tv>');
  return b.toString();
}

// ---- Stream check -------------------------------------------------------------

Future<(int, List<int>)> _get(HttpClient http, Uri uri, {bool range = false}) async {
  final req = await http.getUrl(uri);
  if (range) req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-4095');
  final res = await req.close().timeout(const Duration(seconds: 20));
  final bytes = <int>[];
  await for (final chunk in res.timeout(const Duration(seconds: 20))) {
    bytes.addAll(chunk);
    if (bytes.length > 512 * 1024) break; // a playlist is never this big
  }
  return (res.statusCode, bytes);
}

bool _ok(int status) => status == 200 || status == 206;

/// First URI line of a playlist (variant or segment), resolved.
Uri? _firstUri(String playlist, Uri base) {
  for (final raw in const LineSplitter().convert(playlist)) {
    final l = raw.trim();
    if (l.isEmpty) continue;
    if (l.startsWith('#EXT-X-MAP:')) {
      final m = RegExp(r'URI="([^"]+)"').firstMatch(l);
      if (m != null) return base.resolve(m[1]!);
    }
    if (!l.startsWith('#')) return base.resolve(l);
  }
  return null;
}

/// Problems with one stream; empty when it works.
Future<List<String>> checkStream(HttpClient http, String name, String url) async {
  final uri = Uri.parse(url);
  if (uri.scheme != 'https') return ['$name: not HTTPS'];
  try {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.mov') || path.endsWith('.mkv') || path.endsWith('.mp4')) {
      final (status, bytes) = await _get(http, uri, range: true);
      if (!_ok(status)) return ['$name: HTTP $status'];
      if (bytes.length < 1024) return ['$name: only ${bytes.length} bytes'];
      return [];
    }
    final (status, bytes) = await _get(http, uri);
    if (status != 200) return ['$name: HTTP $status'];
    var text = utf8.decode(bytes, allowMalformed: true);
    if (!text.trimLeft().startsWith('#EXTM3U')) return ['$name: not an HLS playlist'];
    var base = uri;
    if (text.contains('#EXT-X-STREAM-INF')) {
      final variant = _firstUri(text.substring(text.indexOf('#EXT-X-STREAM-INF')), uri);
      if (variant == null) return ['$name: master playlist without variants'];
      final (vs, vb) = await _get(http, variant);
      if (vs != 200) return ['$name: variant $variant: HTTP $vs'];
      text = utf8.decode(vb, allowMalformed: true);
      base = variant;
    }
    if (!text.contains('#EXTINF')) return ['$name: media playlist without segments'];
    final segment = _firstUri(text, base);
    if (segment == null) return ['$name: no segment'];
    final (ss, sb) = await _get(http, segment, range: true);
    if (!_ok(ss)) return ['$name: segment $segment: HTTP $ss'];
    if (sb.isEmpty) return ['$name: empty segment'];
    return [];
  } catch (e) {
    return ['$name: $e'];
  }
}

Future<List<String>> checkAll() async {
  final http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = 'okxiptv-data demo check';
  try {
    final all = [for (final c in channels) (c.name, c.url), for (final f in films) (f.name, f.url)];
    final results = await Future.wait([for (final (n, u) in all) checkStream(http, n, u)]);
    return [for (final r in results) ...r];
  } finally {
    http.close(force: true);
  }
}

// ---- Command line -------------------------------------------------------------

Future<void> main(List<String> args) async {
  var out = 'demo';
  var days = 14;
  var start = DateTime.now().toUtc();
  var check = false;
  for (var i = 0; i < args.length; i++) {
    String value() {
      if (i + 1 >= args.length) {
        stderr.writeln('${args[i]} needs a value');
        exit(64);
      }
      return args[++i];
    }

    switch (args[i]) {
      case '--out':
        out = value();
      case '--days':
        days = int.tryParse(value()) ?? -1;
        if (days < 1 || days > 366) {
          stderr.writeln('--days: 1 to 366');
          exit(64);
        }
      case '--start':
        final v = value();
        final d = DateTime.tryParse(v);
        if (d == null) {
          stderr.writeln('--start: expected YYYY-MM-DD, got $v');
          exit(64);
        }
        start = d;
      case '--check':
        check = true;
      default:
        stderr.writeln('unknown argument: ${args[i]}');
        exit(64);
    }
  }

  final dir = Directory(out);
  await dir.create(recursive: true);
  await File('${dir.path}/okx-demo.m3u').writeAsString(buildM3u());
  await File('${dir.path}/okx-demo-epg.xml').writeAsString(buildEpg(start, days));
  final from = DateTime.utc(start.year, start.month, start.day).toIso8601String().substring(0, 10);
  stdout.writeln('${dir.path}: playlist and $days-day guide from $from written');

  if (check) {
    final problems = await checkAll();
    for (final p in problems) {
      stderr.writeln('error: $p');
    }
    if (problems.isNotEmpty) {
      stderr.writeln('${problems.length} stream(s) failed the check');
      exitCode = 1;
      return;
    }
    stdout.writeln('${channels.length + films.length} streams OK');
  }
}
