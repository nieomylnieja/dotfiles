#!/usr/bin/env python3
"""
Video downloader using yt-dlp.
Supports downloading videos from various platforms.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

VALID_DOMAINS = [
    'youtube.com', 'youtu.be', 'twitter.com', 'x.com', 'vimeo.com',
    'tiktok.com', 'instagram.com', 'facebook.com', 'fb.watch',
    'twitch.tv', 'dailymotion.com', 'nicovideo.jp', 'bilibili.com',
    'reddit.com', 'streamable.com', 'clips.twitch.tv', 'video.twimg.com'
]

QUALITY_FORMATS = {
    'best': 'best',
    '1080p': 'bestvideo[height<=1080]+bestaudio/best',
    '720p': 'bestvideo[height<=720]+bestaudio/best',
    '480p': 'bestvideo[height<=480]+bestaudio/best',
    'audio': 'bestaudio',
}
OUTPUT_MARKER = "__YTDLP_OUTPUT__"
HTTP_URL_PATTERN = re.compile(r"https?://[^\s<>\"']+", re.IGNORECASE)


def is_video_url(url):
    """Check if URL looks like a video URL."""
    try:
        parsed = urlparse(url)
        domain = (parsed.hostname or '').lower().rstrip('.')

        if domain.startswith('www.'):
            domain = domain[4:]

        return (
            parsed.scheme in {'http', 'https'}
            and not parsed.username
            and not parsed.password
            and any(
                domain == valid_domain or domain.endswith(f'.{valid_domain}')
                for valid_domain in VALID_DOMAINS
            )
        )
    except ValueError:
        return False


def video_hostname(url):
    """Return a hostname that is safe to include in logs."""
    try:
        return urlparse(url).hostname or 'unknown host'
    except ValueError:
        return 'unknown host'


def redact_url(text, _source_url=None):
    """Remove every HTTP URL from diagnostic text."""
    return HTTP_URL_PATTERN.sub(
        lambda match: f"<video URL on {video_hostname(match.group(0))}>",
        text,
    )


def output_path(stdout):
    """Return one verified path from yt-dlp's marked output."""
    paths = [
        line.removeprefix(OUTPUT_MARKER)
        for line in stdout.splitlines()
        if line.startswith(OUTPUT_MARKER)
    ]
    if len(paths) != 1:
        return None

    path = Path(paths[0])
    return str(path) if path.is_file() else None


def extract_video_info(url):
    """Extract video information using yt-dlp."""
    try:
        cmd = [
            'yt-dlp',
            '--ignore-config',
            '--no-download',
            '--dump-json',
            '--flat-playlist',
            '--no-playlist',
            url
        ]

        result = subprocess.run(
            cmd,
            capture_output=True,
            check=True,
            text=True,
            timeout=30,
        )

        lines = result.stdout.strip().split('\n')
        if lines:
            return json.loads(lines[0])

        return None
    except subprocess.CalledProcessError as error:
        detail = redact_url(error.stderr.strip() or str(error), url)
        print(f"Video information failed: {detail}", file=sys.stderr)
        return None
    except subprocess.TimeoutExpired:
        print("Video information failed: yt-dlp timed out after 30 seconds", file=sys.stderr)
        return None
    except (FileNotFoundError, json.JSONDecodeError) as error:
        print(f"Video information failed: {error}", file=sys.stderr)
        return None


def download_video(
    url,
    output_dir=None,
    format=None,
    quality=None,
    write_info_json=False,
    write_thumbnail=False,
):
    """Download video using yt-dlp."""
    if output_dir is None:
        output_dir = os.getcwd()

    cmd = ['yt-dlp', '--ignore-config', url]
    cmd.extend(['-o', f'{output_dir}/%(title)s.%(ext)s'])
    cmd.extend(['--print', f'after_move:{OUTPUT_MARKER}%(filepath)s'])

    if format:
        cmd.extend(['-f', format])
    elif quality in QUALITY_FORMATS:
        cmd.extend(['-f', QUALITY_FORMATS[quality]])

    cmd.append('--no-playlist')
    if write_info_json:
        cmd.append('--write-info-json')
    if write_thumbnail:
        cmd.append('--write-thumbnail')

    print(f"Downloading video from host: {video_hostname(url)}", file=sys.stderr)
    print(f"Output directory: {output_dir}", file=sys.stderr)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            check=True,
            text=True,
        )
        path = output_path(result.stdout)
        if path is None:
            print(
                "Download failed: yt-dlp did not report one existing output file",
                file=sys.stderr,
            )
            return None
        return path
    except subprocess.CalledProcessError as error:
        detail = redact_url(error.stderr.strip() or str(error), url)
        print(f"Download failed: {detail}", file=sys.stderr)
        return None
    except OSError as error:
        print(f"Error during download: {error}", file=sys.stderr)
        return None

def main():
    parser = argparse.ArgumentParser(description='Download video using yt-dlp')
    parser.add_argument('url', help='Video URL to download')
    parser.add_argument('-o', '--output', help='Output directory', default=os.getcwd())
    parser.add_argument('-f', '--format', help='Video format selector')
    parser.add_argument('-q', '--quality',
                       choices=['best', '1080p', '720p', '480p', 'audio'],
                       help='Video quality')
    parser.add_argument('--info-only', action='store_true',
                       help='Only extract video info, do not download')
    parser.add_argument('--write-info-json', action='store_true',
                       help='Write a separate yt-dlp metadata JSON file')
    parser.add_argument('--write-thumbnail', action='store_true',
                       help='Write a separate thumbnail file')

    args = parser.parse_args()

    if not is_video_url(args.url):
        print(
            "Warning: URL host is not a known video platform: "
            f"{video_hostname(args.url)}",
            file=sys.stderr,
        )
        print("Will attempt download anyway.", file=sys.stderr)

    if args.info_only:
        info = extract_video_info(args.url)
        if info:
            print(json.dumps(info, indent=2))
            sys.exit(0)
        else:
            sys.exit(1)
    else:
        downloaded_path = download_video(
            args.url,
            args.output,
            args.format,
            args.quality,
            args.write_info_json,
            args.write_thumbnail,
        )
        if downloaded_path:
            print(downloaded_path)
            sys.exit(0)
        sys.exit(1)

if __name__ == '__main__':
    main()
