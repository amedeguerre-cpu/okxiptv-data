// Checks a packs folder before it is published.
//
//   dart run tool/validate_packs.dart [DIR]   (default: packs)
//
// Fails (exit code 1, one line per problem) unless manifest.json parses and
// fits the app's 64 KB limit, every <cc>.json.gz is listed in it with the
// right size and SHA-256 and every listed pack exists, each pack gunzips to
// JSON for its country and version with https logos, no pack is over
// 200 KB gzipped, and the Turkish pack has at least 300 channels.
import 'dart:io';

import 'logo_packs.dart';

Future<void> main(List<String> args) async {
  final dir = Directory(args.isEmpty ? 'packs' : args.first);
  if (!await dir.exists()) {
    stderr.writeln('${dir.path}: no such folder');
    exitCode = 1;
    return;
  }
  final errors = await validatePacks(dir);
  if (errors.isNotEmpty) {
    for (final e in errors) {
      stderr.writeln('error: $e');
    }
    stderr.writeln('${errors.length} problem(s) in ${dir.path}');
    exitCode = 1;
    return;
  }
  final count = (await dir.list().where((f) => f.path.endsWith('.json.gz')).length);
  stdout.writeln('${dir.path}: $count packs OK');
}
