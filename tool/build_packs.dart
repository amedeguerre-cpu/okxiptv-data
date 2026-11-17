// Builds the per-country channel logo packs in packs/.
//
//   dart run tool/build_packs.dart [--out packs] [--from DIR]
//       [--version YYYY-MM-DD] [--previous DIR]
//
// Reads channels.json, logos.json and feeds.json from the iptv-org API
// (https://iptv-org.github.io/api/, public domain / Unlicense) or, with
// --from, from a folder holding those three files. Writes <cc>.json.gz per
// country plus manifest.json ({cc: {bytes, sha256, version}}) and removes
// packs of countries that are gone. --version defaults to today (UTC). With
// --previous (the packs published now), a pack whose channels did not change
// keeps its old file and version, so apps don't download it again.
//
// A standalone copy of the app repository's tool/build_logo_packs.dart: same
// options, byte-identical output (tested there).
import 'dart:convert';
import 'dart:io';

import 'logo_packs.dart';

Future<void> main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final out = Directory(arg('--out') ?? 'packs');
  final from = arg('--from');
  final previous = arg('--previous');

  Future<List<dynamic>> load(String file) async {
    final String text;
    if (from != null) {
      text = await File('$from/$file').readAsString();
    } else {
      final client = HttpClient()..userAgent = 'okxiptv-pack-builder';
      try {
        final req = await client.getUrl(Uri.parse('$kApi$file'));
        final res = await req.close();
        if (res.statusCode != 200) throw HttpException('$file: HTTP ${res.statusCode}');
        text = await res.transform(utf8.decoder).join();
      } finally {
        client.close();
      }
    }
    return jsonDecode(text) as List<dynamic>;
  }

  stdout.writeln('Reading iptv-org data…');
  final channels = await load('channels.json');
  final logos = await load('logos.json');
  final feeds = await load('feeds.json');
  final now = DateTime.now().toUtc();
  final version =
      arg('--version') ??
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final packs = buildLogoPacks(channels: channels, logos: logos, feeds: feeds, version: version);

  var previousManifest = <dynamic, dynamic>{};
  if (previous != null && await File('$previous/manifest.json').exists()) {
    final j = jsonDecode(await File('$previous/manifest.json').readAsString());
    if (j is Map) previousManifest = j;
  }

  await out.create(recursive: true);
  final manifest = <String, Object>{};
  final countries = packs.keys.toList()..sort();
  var kept = 0;
  for (final cc in countries) {
    var packVersion = newPackVersion(version, previousManifest[cc]);
    var bytes = LogoPack(cc, packVersion, packs[cc]!.channels).encode();
    if (await previousPack(previous, previousManifest, packs[cc]!) case (final old, final oldVersion)) {
      (bytes, packVersion) = (old, oldVersion);
      kept++;
    }
    final hex = sha256Hex(bytes);
    await File('${out.path}/$cc.json.gz').writeAsBytes(bytes);
    manifest[cc] = PackInfo(bytes.length, hex, packVersion).toJson();
  }
  // Countries that are gone (manifest.json no longer lists them).
  await for (final f in out.list()) {
    final name = f.uri.pathSegments.last;
    if (f is File && name.endsWith('.json.gz')) {
      if (!packs.containsKey(name.substring(0, name.length - '.json.gz'.length))) await f.delete();
    }
  }
  await File('${out.path}/manifest.json').writeAsString(const JsonEncoder.withIndent(' ').convert(manifest));
  final tr = manifest['tr'] as Map?;
  stdout.writeln(
    'Wrote ${countries.length} packs to ${out.path}, ${countries.length - kept} new or changed'
    '${tr == null ? '' : ' (tr: ${packs['tr']!.channels.length} channels, ${tr['bytes']} bytes)'}',
  );
}
