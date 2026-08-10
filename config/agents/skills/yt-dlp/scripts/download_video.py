#!/usr/bin/env python3
"""
Video downloader using yt-dlp.
Supports downloading videos from various platforms.
"""

import sys
import os
import subprocess
import json
import argparse
from pathlib import Path
from urllib.parse import urlparse

VALID_DOMAINS = [
    'youtube.com', 'youtu.be', 'twitter.com', 'x.com', 'vimeo.com',
    'tiktok.com', 'instagram.com', 'facebook.com', 'fb.watch',
    'twitch.tv', 'dailymotion.com', 'nicovideo.jp', 'bilibili.com',
    'reddit.com', 'streamable.com', 'clips.twitch.tv', 'video.twimg.com'
]

def is_video_url(url):
    """Check if URL looks like a video URL."""
    try:
        parsed = urlparse(url)
        domain = parsed.netloc.lower()

        # Remove www. prefix
        if domain.startswith('www.'):
            domain = domain[4:]

        # Check if it's a valid video domain
        for valid_domain in VALID_DOMAINS:
            if valid_domain in domain:
                return True

        return False
    except:
        return False

def extract_video_info(url):
    """Extract video information using yt-dlp."""
    try:
        cmd = [
            'yt-dlp',
            '--no-download',
            '--dump-json',
            '--flat-playlist',
            url
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            return None

        # Try to parse the first line as JSON
        lines = result.stdout.strip().split('\n')
        if lines:
            data = json.loads(lines[0])
            return data

        return None
    except Exception as e:
        print(f"Error extracting video info: {e}", file=sys.stderr)
        return None

def download_video(url, output_dir=None, format=None, quality=None):
    """Download video using yt-dlp."""
    if output_dir is None:
        output_dir = os.getcwd()

    # Build yt-dlp command
    cmd = ['yt-dlp', url]

    # Set output template
    cmd.extend(['-o', f'{output_dir}/%(title)s.%(ext)s'])

    # Handle format and quality
    if format:
        cmd.extend(['-f', format])
    elif quality:
        # Map quality to format selector
        quality_map = {
            'best': 'best',
            '1080p': 'bestvideo[height<=1080]+bestaudio/best',
            '720p': 'bestvideo[height<=720]+bestaudio/best',
            '480p': 'bestvideo[height<=480]+bestaudio/best',
            'audio': 'bestaudio'
        }
        if quality in quality_map:
            cmd.extend(['-f', quality_map[quality]])

    # Add some useful options
    cmd.extend([
        '--no-playlist',  # Only download single video
        '--write-info-json',  # Save metadata
        '--write-thumbnail'  # Save thumbnail
    ])

    print(f"Downloading video from: {url}", file=sys.stderr)
    print(f"Output directory: {output_dir}", file=sys.stderr)

    try:
        result = subprocess.run(cmd, check=True)
        return result.returncode == 0
    except subprocess.CalledProcessError as e:
        print(f"Download failed: {e}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Error during download: {e}", file=sys.stderr)
        return False

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

    args = parser.parse_args()

    # Validate URL
    if not is_video_url(args.url):
        print(f"Warning: URL does not appear to be from a known video platform: {args.url}", file=sys.stderr)
        print("Will attempt download anyway.", file=sys.stderr)

    if args.info_only:
        # Only extract info
        info = extract_video_info(args.url)
        if info:
            print(json.dumps(info, indent=2))
            sys.exit(0)
        else:
            sys.exit(1)
    else:
        # Download video
        success = download_video(args.url, args.output, args.format, args.quality)
        sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
