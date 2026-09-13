---
name: yt-dlp
description: |
  Download one video, extract its audio, or inspect media metadata with yt-dlp
  when the user explicitly requests that operation for a supplied URL. Do not
  trigger merely because a conversation contains a video link.
---

# yt-dlp media operations

Use the tested wrappers in [`scripts/`](scripts/). A sufficiently specific
request authorizes the named operation; do not ask the user to select it again.
Ask one focused question only when the URL, output location, or material format
choice is missing.

## Commands

Download one video without playlist expansion:

```bash
scripts/download_video.py URL --output DIRECTORY
```

The default uses yt-dlp's best format and creates no metadata or thumbnail
sidecars. Supported presets are `best`, `1080p`, `720p`, `480p`, and `audio`.
The wrappers ignore user and system yt-dlp configuration so those defaults stay
deterministic.
Use `--format` only when the user supplied a yt-dlp format selector.
Add `--write-info-json` or `--write-thumbnail` only when requested.

Inspect metadata without downloading:

```bash
scripts/download_video.py URL --info-only
```

Extract one audio file:

```bash
scripts/extract_audio.py URL --output DIRECTORY
```

The default is MP3 at quality `192` with no metadata or thumbnail sidecars.
Supported formats are `mp3`, `m4a`, `opus`, `flac`, and `wav`.

Extract supported media URLs from user-supplied text only when the requested
operation needs it:

```bash
scripts/extract_urls.py -
```

Pass the text on standard input. Do not scan earlier conversation turns or
offer downloads proactively. The wrappers operate on one URL at a time and do
not support playlist or subtitle workflows.

## Safety and errors

- Inspect each wrapper's `--help` before using an option not listed here.
- Keep signed URL queries and credentials out of progress and error messages.
- Do not add cookie, browser-profile, authentication, overwrite, or playlist
  options without explicit authorization.
- Treat a missing `yt-dlp` or `ffmpeg`, a nonzero exit, and invalid output as a
  failure. Preserve the useful error text after redacting the source URL.
- On NixOS, report a missing dependency. Do not install it or enter a package
  shell unless the user authorizes that action.
- Report the verified primary path printed by the wrapper. If the user requested
  sidecars, report only the sidecar paths that you confirm on disk.
- Do not claim success from an exit code alone when the requested output file
  cannot be found.

Dependencies: Python 3, `yt-dlp`, and `ffmpeg` for audio conversion or merged
formats.
