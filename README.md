# OKxIPTV channel data

Small per-country channel lists the OKxIPTV player downloads when a user turns on
"Kanal logolarını otomatik bul" (find channel logos automatically).

- `packs/<country>.json.gz`: channel id, names and a logo address per channel.
- `packs/manifest.json`: size, SHA-256 and version of every pack.

Built from the [iptv-org](https://github.com/iptv-org/database) channel database
(public domain, the Unlicense). Only text is published here. Logo images are not
copied: they stay on their own hosts, and their trademarks belong to their owners.

## Demo playlist

`demo/` holds a small test playlist and guide for App Review and for trying the
player: public test streams and open movies, only linked, never copied. See
[demo/README.md](demo/README.md).

## Format

`manifest.json` lists every pack:

```json
{"tr": {"bytes": 9240, "sha256": "bd58…", "version": "2026-11-17"}}
```

A pack is gzipped JSON:

```json
{"country": "tr", "version": "2026-11-17",
 "channels": [{"id": "24TV.tr", "names": ["24 TV"], "logo": "https://…"}]}
```

The app downloads one country's pack only with the user's opt-in, at most once a
week, and only when the manifest shows a new version. It checks the size and
SHA-256 against the manifest before using a pack.

## How the packs are built

`.github/workflows/build-packs.yml` runs on the 3rd of every month (and from the
Actions tab, *Run workflow*):

1. `dart run tool/build_packs.dart --out $RUNNER_TEMP/packs --previous packs`
   reads `channels.json`, `logos.json` and `feeds.json` from
   <https://iptv-org.github.io/api/> and writes one pack per country. A pack whose
   channels did not change keeps its old file and version, so phones don't
   download it again; changed packs get today's date as version (with `-2`,
   `-3`… when the same day was already used, so a second run that day is still
   picked up).
2. `dart run tool/validate_packs.dart $RUNNER_TEMP/packs` stops the run unless:
   - `manifest.json` parses and is at most 64 KB;
   - every `<cc>.json.gz` is listed in the manifest with matching size and
     SHA-256, and every listed pack exists;
   - every pack gunzips (at most 4 MB) to JSON for its own country and version,
     with an id, names and an `https://` logo per channel;
   - no pack is over 200 KB gzipped;
   - there are at least 100 packs and the Turkish pack has at least 300 channels.
3. The result replaces `packs/` and is committed only if a file changed.

Channel selection: NSFW channels are left out; a closed channel's names move to
the channel that replaced it; each channel gets one logo (in use, for the channel
or its main feed, preferably not on imgur, about 400 px wide); names that reduce
to nothing comparable ("HD") are dropped.

## Running it locally

Needs the Dart SDK 3.14 or later.

```sh
dart pub get
dart run tool/build_packs.dart --out /tmp/packs --previous packs
dart run tool/validate_packs.dart /tmp/packs
```

`--from DIR` reads the three iptv-org files from a folder instead of the network;
`--version` sets the version of changed packs.

The builder is a standalone copy of the one in the OKxIPTV app's source, which
checks that both write byte-identical files for the same input. Change them
together.

Contact: destek@okxproject.com
