/// Building and checking the per-country channel logo packs.
///
/// A standalone copy of what the OKxIPTV app repository builds them with
/// (lib/core/channel_directory.dart, channel_match.dart and models.dart's
/// foldForSearch, plus tool/build_logo_packs.dart). It must stay in step:
/// the app repository has a test that builds a fixture with both and expects
/// byte-identical files. Pure Dart; the only package is crypto (SHA-256).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;

/// Where the iptv-org API files come from (public domain, the Unlicense).
const kApi = 'https://iptv-org.github.io/api/';

/// What the app accepts (lib/core/channel_directory.dart).
const kLogoManifestMaxBytes = 64 * 1024;
const kLogoPackMaxBytes = 512 * 1024;
const kLogoPackMaxJsonBytes = 4 * 1024 * 1024;

/// Stricter limits this repository holds itself to (real packs are 0.2–125 KB).
const kPackLimitBytes = 200 * 1024;
const kMinTrChannels = 300;
const kMinPacks = 100;

// ---- Packs ------------------------------------------------------------------

/// One channel of a pack.
class DirectoryChannel {
  final String id;
  final List<String> names;
  final String logo;
  const DirectoryChannel(this.id, this.names, this.logo);

  Map<String, Object> toJson() => {'id': id, 'names': names, 'logo': logo};
}

class LogoPack {
  /// Lower-case iptv-org country code ("tr", "uk").
  final String country;
  final String version;
  final List<DirectoryChannel> channels;
  const LogoPack(this.country, this.version, this.channels);

  Map<String, Object> toJson() => {
    'country': country,
    'version': version,
    'channels': [for (final c in channels) c.toJson()],
  };

  /// The gzipped JSON the app downloads.
  List<int> encode() => gzip.encode(utf8.encode(jsonEncode(toJson())));
}

/// One pack as manifest.json lists it.
class PackInfo {
  final int bytes;
  final String sha256;
  final String version;
  const PackInfo(this.bytes, this.sha256, this.version);

  Map<String, Object> toJson() => {'bytes': bytes, 'sha256': sha256, 'version': version};
}

/// Lower-case hex SHA-256 of [bytes].
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// Builds one pack per country from the iptv-org API files (channels.json,
/// logos.json, feeds.json; parsed JSON lists). NSFW channels are left out;
/// closed channels too, but their names are kept on the channel that
/// replaced them (a playlist may still use the old name). Each channel gets
/// its best logo: in use, for the whole channel or its main feed, on a host
/// other than imgur (blocked in some countries), about 400 px wide.
Map<String, LogoPack> buildLogoPacks({
  required List<dynamic> channels,
  required List<dynamic> logos,
  required List<dynamic> feeds,
  required String version,
}) {
  final byId = <String, Map>{};
  for (final c in channels) {
    if (c is Map && c['id'] is String) byId[c['id'] as String] = c;
  }
  String? strip(Object? id) => id is String && id.isNotEmpty ? id.split('@').first : null;

  /// Where a closed channel lives on now, following the chain (which may
  /// loop in bad data).
  String? successor(String id) {
    var cur = id;
    final seen = {cur};
    while (true) {
      final c = byId[cur];
      if (c == null) return null;
      if (c['closed'] == null) return cur;
      final next = strip(c['replaced_by']);
      if (next == null || !seen.add(next)) return null;
      cur = next;
    }
  }

  final mainFeed = <String, String>{};
  for (final f in feeds) {
    if (f is Map && f['is_main'] == true && f['channel'] is String && f['id'] is String) {
      mainFeed[f['channel'] as String] = f['id'] as String;
    }
  }

  final best = <String, (int, String)>{};
  for (final l in logos) {
    if (l is! Map) continue;
    final ch = l['channel'], url = l['url'];
    if (ch is! String || url is! String || !url.startsWith('https://')) continue;
    if (l['in_use'] == false) continue;
    final feed = l['feed'];
    if (feed != null && feed != mainFeed[ch]) continue;
    final width = (l['width'] as num?)?.toInt() ?? 0;
    final host = Uri.tryParse(url)?.host ?? '';
    final score =
        (feed == null ? 4000 : 0) +
        (host.endsWith('imgur.com') ? 0 : 2000) -
        (width - 400).abs().clamp(0, 1999);
    final had = best[ch];
    if (had == null || score > had.$1) best[ch] = (score, url);
  }

  final names = <String, List<String>>{};
  void addNames(String id, Map c) {
    final list = names.putIfAbsent(id, () => []);
    for (final n in [c['name'], ...?(c['alt_names'] as List?)]) {
      if (n is String && n.trim().isNotEmpty && !list.contains(n.trim())) list.add(n.trim());
    }
  }

  for (final c in byId.values) {
    if (c['is_nsfw'] == true) continue;
    final id = c['id'] as String;
    final target = successor(id);
    if (target == null) continue;
    addNames(target, c);
  }

  final packs = <String, List<DirectoryChannel>>{};
  final ids = names.keys.toList()..sort();
  for (final id in ids) {
    final logo = best[id]?.$2;
    final country = (byId[id]!['country'] as String?)?.toLowerCase();
    if (logo == null || country == null || country.isEmpty) continue;
    if (byId[id]!['is_nsfw'] == true) continue;
    // Names that leave nothing to compare would never match.
    final usable = names[id]!.where((n) => nameParts(n) != null).toList();
    if (usable.isEmpty) continue;
    packs.putIfAbsent(country, () => []).add(DirectoryChannel(id, usable, logo));
  }
  return {for (final e in packs.entries) e.key: LogoPack(e.key, version, e.value)};
}

/// The version for a new or changed pack: [version], or "[version]-2",
/// "-3"… when the previous manifest already used it (a second build on the
/// same day). The app downloads a pack only when its version is new to it.
String newPackVersion(String version, Object? previousEntry) {
  final old = previousEntry is Map ? previousEntry['version'] : null;
  if (old is! String || (old != version && !old.startsWith('$version-'))) return version;
  final n = old == version ? 1 : int.tryParse(old.substring(version.length + 1)) ?? 1;
  return '$version-${n + 1}';
}

/// The previous run's file for [pack] and its manifest version, when its
/// channels are exactly [pack]'s: an unchanged pack keeps its bytes and
/// version, so apps (which compare versions) don't download it again.
Future<(List<int>, String)?> previousPack(String? dir, Map previousManifest, LogoPack pack) async {
  if (dir == null) return null;
  final entry = previousManifest[pack.country];
  final file = File('$dir/${pack.country}.json.gz');
  if (entry is! Map || entry['version'] is! String || !await file.exists()) return null;
  final bytes = await file.readAsBytes();
  try {
    final j = jsonDecode(utf8.decode(gzip.decode(bytes)));
    if (j is! Map || j['country'] != pack.country || j['version'] != entry['version']) return null;
    if (jsonEncode(j['channels']) != jsonEncode(pack.toJson()['channels'])) return null;
  } catch (_) {
    return null;
  }
  return (bytes, entry['version'] as String);
}

// ---- Validation -------------------------------------------------------------

final _hex64 = RegExp(r'^[0-9a-f]{64}$');
final _packName = RegExp(r'^([a-z]{2})\.json\.gz$');

/// Problems with the packs in [dir] (empty when it may be published):
/// manifest.json parses and is within the app's limit, every pack file is
/// listed with its size and SHA-256 and every listed pack exists, each pack
/// is valid gzipped JSON for its country and version with https logos, no
/// pack is over [maxPackBytes], and Turkey has at least [minTr] channels.
Future<List<String>> validatePacks(
  Directory dir, {
  int maxPackBytes = kPackLimitBytes,
  int minTr = kMinTrChannels,
  int minPacks = kMinPacks,
}) async {
  final errors = <String>[];
  final manifestFile = File('${dir.path}/manifest.json');
  if (!await manifestFile.exists()) return ['manifest.json is missing'];
  final manifestBytes = await manifestFile.readAsBytes();
  if (manifestBytes.length > kLogoManifestMaxBytes) {
    errors.add('manifest.json is ${manifestBytes.length} bytes (limit $kLogoManifestMaxBytes)');
  }
  final Object? manifest;
  try {
    manifest = jsonDecode(utf8.decode(manifestBytes));
  } on FormatException catch (e) {
    return [...errors, 'manifest.json does not parse: ${e.message}'];
  }
  if (manifest is! Map) return [...errors, 'manifest.json is not an object'];

  final files = <String>{};
  await for (final f in dir.list()) {
    final name = f.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (name.endsWith('.json.gz')) {
      final m = _packName.firstMatch(name);
      if (f is! File || m == null) {
        errors.add('$name: unexpected pack file name');
      } else {
        files.add(m[1]!);
      }
    }
  }
  for (final cc in files) {
    if (!manifest.containsKey(cc)) errors.add('$cc.json.gz is not in manifest.json');
  }
  if (manifest.length < minPacks) errors.add('only ${manifest.length} packs (expected at least $minPacks)');

  var trChannels = -1;
  for (final MapEntry(:key, :value) in manifest.entries) {
    final cc = '$key';
    if (!RegExp(r'^[a-z]{2}$').hasMatch(cc)) errors.add('manifest key "$cc" is not a country code');
    if (value is! Map ||
        value['bytes'] is! int ||
        value['sha256'] is! String ||
        !_hex64.hasMatch(value['sha256'] as String) ||
        value['version'] is! String ||
        (value['version'] as String).isEmpty) {
      errors.add('$cc: malformed manifest entry');
      continue;
    }
    if (!files.contains(cc)) {
      errors.add('$cc: listed in manifest.json but $cc.json.gz is missing');
      continue;
    }
    final bytes = await File('${dir.path}/$cc.json.gz').readAsBytes();
    if (bytes.length != value['bytes']) {
      errors.add('$cc: ${bytes.length} bytes, manifest says ${value['bytes']}');
    }
    if (sha256Hex(bytes) != value['sha256']) errors.add('$cc: SHA-256 differs from manifest.json');
    if (bytes.length > maxPackBytes) errors.add('$cc: ${bytes.length} bytes gzipped (limit $maxPackBytes)');
    if (bytes.length > kLogoPackMaxBytes) errors.add('$cc: over the app limit of $kLogoPackMaxBytes bytes');
    final List<int> json;
    try {
      json = _gunzipCapped(bytes, kLogoPackMaxJsonBytes);
    } catch (e) {
      errors.add('$cc: does not gunzip within $kLogoPackMaxJsonBytes bytes ($e)');
      continue;
    }
    final Object? pack;
    try {
      pack = jsonDecode(utf8.decode(json));
    } on FormatException catch (e) {
      errors.add('$cc: does not parse: ${e.message}');
      continue;
    }
    if (pack is! Map || pack['channels'] is! List) {
      errors.add('$cc: not a pack object with a channels list');
      continue;
    }
    if (pack['country'] != cc) errors.add('$cc: pack says country "${pack['country']}"');
    if (pack['version'] != value['version']) {
      errors.add('$cc: pack version "${pack['version']}" differs from manifest "${value['version']}"');
    }
    final channels = pack['channels'] as List;
    if (channels.isEmpty) errors.add('$cc: no channels');
    var bad = 0;
    for (final c in channels) {
      final ok =
          c is Map &&
          c['id'] is String &&
          (c['id'] as String).isNotEmpty &&
          c['logo'] is String &&
          (c['logo'] as String).startsWith('https://') &&
          c['names'] is List &&
          (c['names'] as List).isNotEmpty &&
          (c['names'] as List).every((n) => n is String && n.trim().isNotEmpty);
      if (!ok) bad++;
    }
    if (bad > 0) errors.add('$cc: $bad malformed channel entries');
    if (cc == 'tr') trChannels = channels.length;
  }
  if (trChannels < 0) {
    errors.add('tr pack is missing');
  } else if (trChannels < minTr) {
    errors.add('tr pack has $trChannels channels (expected at least $minTr)');
  }
  return errors;
}

List<int> _gunzipCapped(List<int> gz, int limit) {
  final out = <int>[];
  gzip.decoder.startChunkedConversion(_CappedSink(out, limit))
    ..add(gz)
    ..close();
  return out;
}

class _CappedSink implements Sink<List<int>> {
  final List<int> out;
  final int limit;
  _CappedSink(this.out, this.limit);

  @override
  void add(List<int> chunk) {
    if (out.length + chunk.length > limit) throw const FormatException('too large');
    out.addAll(chunk);
  }

  @override
  void close() {}
}

// ---- Channel names (app: lib/core/channel_match.dart, models.dart) ----------

/// Picture-quality and copy markers that don't change which channel it is.
const _quality = {
  'hd', 'fhd', 'uhd', 'sd', 'sd+', 'hd+', 'fhd+', 'uhd+', '4k', '8k', 'hq', 'lq', //
  'hevc', 'h265', 'h264', 'x265', '1080p', '1080i', '720p', '576p', '480p', '50fps', '60fps',
  'raw', 'backup', 'yedek', 'alt', 'b', 'vip', 'orj', 'orijinal', 'original',
};

/// A leading country tag: "UK: ", "DE | ", "TR - ".
final _prefix = RegExp(r'^\s*([A-Za-z]{2,3})\s*[:|]\s*|^\s*([A-Z]{2,3})\s+-\s+');

/// Country tags providers put after the name: "beIN SPORTS 1 HD FR".
/// Only known codes count, so "SHOW TV" keeps its "TV".
const _countries = {
  'tr', 'uk', 'gb', 'us', 'usa', 'de', 'fr', 'it', 'es', 'nl', 'be', 'ch', 'at', 'pl', 'ru', 'ar', //
  'ku', 'al', 'hk', 'ca', 'au', 'se', 'no', 'dk', 'fi', 'pt', 'gr', 'ro', 'bg', 'hu', 'cz', 'sk',
  'hr', 'rs', 'srb', 'ba', 'mk', 'in', 'pk', 'ir', 'iq', 'az', 'ge', 'ua', 'br', 'mx', 'lat', 'arb',
  'nz', 'ie', 'jp', 'kr', 'cn', 'ph', 'th', 'vn', 'id', 'my', 'eg', 'sa', 'ae', 'qa', 'ma', 'dz',
  'tn', 'il', 'cy', 'lt', 'lv', 'ee', 'si', 'bih', 'kz', 'uz', 'am', 'ex', 'afr', 'asia',
};

final _brackets = RegExp(r'[\(\[\{]([^\)\]\}]*)[\)\]\}]');
final _split = RegExp(r'[^\p{L}\p{N}+]+', unicode: true);

/// Identity of a channel name: country plus the name without quality marks,
/// folded and without spaces ("TRT 1 HD" and "TRT1" agree; "UK: Showcase"
/// and "CA: Showcase" don't). Null when nothing is left to compare.
String? channelKey(String name) {
  var s = name.trim();
  String region = '';
  final p = _prefix.firstMatch(s);
  if (p != null) {
    region = (p[1] ?? p[2]!).toLowerCase();
    s = s.substring(p.end);
  }
  // Bracketed quality marks go ("(RAW)", "[FHD]"); other bracketed words stay.
  s = s.replaceAllMapped(_brackets, (m) {
    final inner = foldForSearch(m[1]!).split(_split).where((t) => t.isNotEmpty);
    return inner.every(_quality.contains) ? ' ' : ' ${m[1]} ';
  });
  // The country may also trail the quality marks: "beIN SPORTS 1 HD FR".
  final words = s.trim().split(RegExp(r'\s+'));
  while (words.isNotEmpty) {
    final last = words.last;
    final folded = foldForSearch(last);
    if (_quality.contains(folded)) {
      words.removeLast();
    } else if (region.isEmpty && last == last.toUpperCase() && _countries.contains(folded)) {
      region = folded;
      words.removeLast();
    } else {
      break;
    }
  }
  final tokens = foldForSearch(words.join(' '))
      .split(_split)
      .where((t) => t.isNotEmpty && !_quality.contains(t));
  final base = tokens.join();
  if (base.isEmpty) return null;
  return '$region|$base';
}

/// Playlist tags that look like countries but name a language or a bundle
/// ("AR:" is mostly Arabic, "EX-YU" a region): they never filter a match.
const _notCountries = {'ar', 'arb', 'ex', 'afr', 'asia', 'lat', 'ku'};

/// Spellings of one country: guides and iptv-org say "uk", playlists "GB".
const _regionAliases = {'gb': 'uk', 'usa': 'us', 'srb': 'rs', 'bih': 'ba'};

/// [tag] as a country code the matcher compares, or '' when it is no
/// country at all ("VIP:", "AR:").
String normalizeRegion(String? tag) {
  if (tag == null) return '';
  final t = tag.trim().toLowerCase();
  if (t.isEmpty || _notCountries.contains(t) || !_countries.contains(t)) return '';
  return _regionAliases[t] ?? t;
}

/// A channel name split for directory matching: the [base] that
/// [channelKey] compares and a country [region] ('' when unknown).
({String region, String base})? nameParts(String name) {
  final key = channelKey(name);
  if (key == null) return null;
  final bar = key.indexOf('|');
  final base = key.substring(bar + 1);
  // A one-letter or one-digit name would match half the guide.
  if (base.length < 2) return null;
  return (region: normalizeRegion(key.substring(0, bar)), base: base);
}

/// Lower-cases and strips Turkish/Latin diacritics so "İzmir" matches "izmir".
String foldForSearch(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    b.write(_fold[c] ?? c.toLowerCase());
  }
  return b.toString();
}

const _fold = <String, String>{
  'İ': 'i',
  'I': 'i',
  'ı': 'i',
  'Ş': 's',
  'ş': 's',
  'Ğ': 'g',
  'ğ': 'g',
  'Ü': 'u',
  'ü': 'u',
  'Ö': 'o',
  'ö': 'o',
  'Ç': 'c',
  'ç': 'c',
  'Â': 'a',
  'â': 'a',
  'Î': 'i',
  'î': 'i',
  'Û': 'u',
  'û': 'u',
  'É': 'e',
  'é': 'e',
  'È': 'e',
  'è': 'e',
  'Ë': 'e',
  'ë': 'e',
  'Á': 'a',
  'á': 'a',
  'À': 'a',
  'à': 'a',
  'Ä': 'a',
  'ä': 'a',
  'Ñ': 'n',
  'ñ': 'n',
  'Ó': 'o',
  'ó': 'o',
  'Ú': 'u',
  'ú': 'u',
};
