# OKxIPTV demo playlist

A small playlist for trying the OKxIPTV player without an IPTV subscription,
made for App Review and for our own testing. **It is for testing the player
only.** It contains no TV channels: only public test streams and open films
that their owners publish for anyone to play.

- Playlist: <https://amedeguerre-cpu.github.io/okxiptv-data/demo/okx-demo.m3u>
- TV guide (XMLTV): <https://amedeguerre-cpu.github.io/okxiptv-data/demo/okx-demo-epg.xml>
  (named in the playlist header, so the app picks it up by itself)

In the app: **M3U link** → paste the playlist address into **Playlist URL** →
**Add playlist**.

## What is in it

Nothing is copied here. The playlist only links to the streams where their
owners host them, over HTTPS: no video, audio or picture from them is copied,
stored, re-hosted or redistributed by us or by the app, and the app plays each
one straight from its owner's server. There are no logos (`tvg-logo` is left
out), and no channel is named after a real broadcaster.

Where each provider publishes its streams (pages checked with `curl` on
2026-11-17, all HTTP 200):

- **Unified Streaming** (Test Channels 1 and 2): their public demo site,
  "USP Demonstration pages", <https://demo.unified-streaming.com/>. Test
  Channel 2's stream (`k8s/live/scte35.isml`) belongs to the "Unified Streaming
  Live Reference Stream" page <https://demo.unified-streaming.com/k8s/live/>,
  which builds that stream address. Test Channel 1's stream
  (`k8s/live/stable/live.isml`) is served from the same demo site; the page at
  <https://demo.unified-streaming.com/k8s/live/stable/> is the same live
  reference page, but we found no page that prints that exact address. These
  are reference streams Unified Streaming publishes to demonstrate its
  streaming server; their pages do not explicitly say "for player testing".
- **Apple BipBop** (Test Channels 3 to 6): "Examples - HTTP Live Streaming",
  <https://developer.apple.com/streaming/examples/>, Apple's page of HLS example
  streams for developers, with a "Bip Bop" category. The page loads its stream
  list with scripts, so the exact addresses did not show in the fetched HTML.
- **Mux** (Big Buck Bunny HLS): "Test Streams", <https://test-streams.mux.dev/>.
  The page says these are test HLS streams, primarily used by hls.js, hosted by
  Mux, and links the exact address used here (`x36xhzz/x36xhzz.m3u8`,
  "Big Buck Bunny - adaptive qualities").

### Group "Live Test" (six channels)

| Channel | Stream | What it shows | Source and terms |
| --- | --- | --- | --- |
| Test Channel 1 | `demo.unified-streaming.com/k8s/live/stable/live.isml/live-audio_eng=128000-video=1000000.m3u8` | Live test card with the current time (really live) | Public live reference stream on the [Unified Streaming demo site](https://demo.unified-streaming.com/) ([live page](https://demo.unified-streaming.com/k8s/live/stable/)); linked only. Their logo is part of the picture. |
| Test Channel 2 | `demo.unified-streaming.com/k8s/live/scte35.isml/scte35-audio_eng=128000-video=1000000.m3u8` | The same live test card, with SCTE-35 ad markers | Unified Streaming [Live Reference Stream page](https://demo.unified-streaming.com/k8s/live/); linked only. |
| Test Channel 3 | `devstreaming-cdn.apple.com/…/bipbop_4x3/bipbop_4x3_variant.m3u8` | Apple's "BipBop" test pattern, MPEG-TS, 4:3 | [Apple HLS examples](https://developer.apple.com/streaming/examples/) ("Bip Bop"), published for developers to test HLS playback; linked only. |
| Test Channel 4 | `devstreaming-cdn.apple.com/…/bipbop_16x9/bipbop_16x9_variant.m3u8` | BipBop 16:9 with subtitles in several languages | Apple HLS examples. |
| Test Channel 5 | `devstreaming-cdn.apple.com/…/img_bipbop_adv_example_fmp4/master.m3u8` | Advanced BipBop (fMP4, up to 1080p, frame counter) | Apple HLS examples. |
| Test Channel 6 | `devstreaming-cdn.apple.com/…/bipbop_adv_example_hevc/master.m3u8` | Advanced BipBop in HEVC | Apple HLS examples. |

Channels 1 and 2 are live. They link the 720p media playlist (video and
audio together) instead of the master, because the master also lists an
audio-only variant that a player on a slow connection could pick, leaving
the screen black. Channels 3 to 6 are recorded test patterns
(10 to 30 minutes) shown as channels; when one ends, the player starts it
again like a channel that dropped.

Test Channel 6 has **no `tvg-id` on purpose**: its guide is found by the
channel name, which shows the app's name matching for playlists without
guide ids. Channels 1 to 5 carry `tvg-id`s `okx-demo-1` … `okx-demo-5`, which
match the guide.

### Group "Movies" (four open films)

| Film | Stream | Licence and credit |
| --- | --- | --- |
| Big Buck Bunny (2008) | `test-streams.mux.dev/x36xhzz/x36xhzz.m3u8` (HLS, up to 1080p) | © 2008 Blender Foundation, [peach.blender.org](https://peach.blender.org/), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). HLS copy hosted by Mux as a public test stream on [test-streams.mux.dev](https://test-streams.mux.dev/); linked only. |
| Elephants Dream (2006) | `download.blender.org/ED/elephantsdream-720-h264-st-aac.mov` (720p file) | © 2006 Blender Foundation / Netherlands Media Art Institute, [orange.blender.org](https://orange.blender.org/), [CC BY 2.5](https://creativecommons.org/licenses/by/2.5/). |
| Sintel (2010) | `download.blender.org/durian/movies/Sintel.2010.1080p.mkv` (1080p file, subtitles) | © 2010 Blender Foundation, [durian.blender.org](https://durian.blender.org/), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). |
| Tears of Steel (2012) | `download.blender.org/demo/movies/ToS/tears_of_steel_720p.mov` (720p file) | © 2012 Blender Foundation, [mango.blender.org](https://mango.blender.org/), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). |

The three Blender downloads are plain video files (MOV/MKV, served with byte
ranges), not HLS or DASH. The player opens them like a provider's film
entries. Sintel is about 1.2 GB at 1080p, so it needs a decent connection.

### The guide

`okx-demo-epg.xml` is made up by `tool/demo_playlist.dart`: neutral programme
names ("Colour Bars", "Signal Check"…) in a repeating schedule for each test
channel, starting at 00:00 UTC on the day it is generated. No real
broadcaster's guide data is used. The guide text is free to reuse (CC0).

## Making and checking it

From the data repo root (Dart SDK 3.14 or later, `dart pub get` once):

```sh
dart run tool/demo_playlist.dart --out demo --check
```

This writes `demo/okx-demo.m3u` and a 14-day `demo/okx-demo-epg.xml`, then
fetches every stream and fails (exit code 1) unless each one answers over
HTTPS with an HLS playlist whose first variant and first segment load, or
with video bytes for a film file. Options: `--days N` (default 14),
`--start YYYY-MM-DD` (default today, UTC).

The playlist and the guide come from the same list in the script, so ids and
names always match. To change a stream, edit the list there and run the
command again; don't edit the generated files by hand.

When this was made (2026-11-17) every stream above was checked with the script
and with ffmpeg (a frame decoded from each). Streams that failed then and were
left out: Akamai's live test (`cph-p2p-msl.akamaized.net`, its variant answers
404), Unified Streaming's on-demand films (503) and Bitmovin's test streams
(403).

## Keeping the guide fresh

The app keeps the guide from two days back to four days ahead, so a guide that
ends in the past shows empty rows. A 14-day guide is therefore only good for
about two weeks after it is generated. **Run the command again before every
App Store submission**, and keep it running on a schedule.

The monthly `build-packs` workflow is not often enough for a 14-day guide, so
the demo has its own weekly workflow, `.github/workflows/demo-guide.yml`
(Mondays 05:41 UTC, also runnable by hand). It writes a 21-day guide and runs
`--check`, so the run fails, and we hear about it, when a stream is gone.

Contact: destek@okxproject.com
