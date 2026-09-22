#!/usr/bin/env python3
"""Extract one video's audio with yt-dlp and ffmpeg."""

import argparse
import os
import subprocess
import sys

from download_video import OUTPUT_MARKER, output_path, redact_url, video_hostname


def extract_audio(
    url,
    output_dir=None,
    audio_format="mp3",
    quality="192",
    write_info_json=False,
    write_thumbnail=False,
):
    """Extract one audio file and return its verified path, or None."""
    if output_dir is None:
        output_dir = os.getcwd()

    command = [
        "yt-dlp",
        "--ignore-config",
        url,
        "-o",
        f"{output_dir}/%(title)s.%(ext)s",
        "-f",
        "bestaudio[ext=m4a]/bestaudio",
        "--extract-audio",
        "--audio-format",
        audio_format,
        "--audio-quality",
        quality,
        "--no-playlist",
        "--print",
        f"after_move:{OUTPUT_MARKER}%(filepath)s",
    ]
    if write_info_json:
        command.append("--write-info-json")
    if write_thumbnail:
        command.append("--write-thumbnail")

    print(
        f"Extracting audio from host: {video_hostname(url)}", file=sys.stderr
    )
    print(f"Output format: {audio_format}", file=sys.stderr)
    print(f"Output directory: {output_dir}", file=sys.stderr)

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            check=True,
            text=True,
        )
        path = output_path(result.stdout)
        if path is None:
            print(
                "Audio extraction failed: yt-dlp did not report one existing output file",
                file=sys.stderr,
            )
            return None
        return path
    except subprocess.CalledProcessError as error:
        detail = redact_url(error.stderr.strip() or str(error), url)
        print(f"Audio extraction failed: {detail}", file=sys.stderr)
        return None
    except OSError as error:
        print(f"Audio extraction failed: {error}", file=sys.stderr)
        return None


def main():
    parser = argparse.ArgumentParser(
        description="Extract audio from one video using yt-dlp"
    )
    parser.add_argument("url", help="Video URL")
    parser.add_argument(
        "-o", "--output", help="Output directory", default=os.getcwd()
    )
    parser.add_argument(
        "-f",
        "--format",
        dest="audio_format",
        default="mp3",
        choices=["mp3", "m4a", "opus", "flac", "wav"],
        help="Audio format",
    )
    parser.add_argument(
        "-q", "--quality", default="192", help="Audio quality"
    )
    parser.add_argument(
        "--write-info-json",
        action="store_true",
        help="Write a separate yt-dlp metadata JSON file",
    )
    parser.add_argument(
        "--write-thumbnail",
        action="store_true",
        help="Write a separate thumbnail file",
    )
    args = parser.parse_args()

    output_path_value = extract_audio(
        args.url,
        args.output,
        args.audio_format,
        args.quality,
        args.write_info_json,
        args.write_thumbnail,
    )
    if output_path_value:
        print(output_path_value)
        sys.exit(0)
    sys.exit(1)


if __name__ == "__main__":
    main()
