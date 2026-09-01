#!/usr/bin/env python3
"""
Extract video URLs from text or files.
"""

import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

VIDEO_DOMAINS = [
    'youtube.com',
    'youtu.be',
    'twitter.com',
    'x.com',
    'vimeo.com',
    'tiktok.com',
    'instagram.com',
    'facebook.com',
    'fb.watch',
    'twitch.tv',
    'dailymotion.com',
    'nicovideo.jp',
    'bilibili.com',
    'reddit.com',
    'streamable.com',
    'clips.twitch.tv',
    'video.twimg.com'
]

URL_PATTERN = re.compile(
    r'https?://(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}'
    r'\.[a-zA-Z0-9()]{1,6}\b'
    r'(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    re.IGNORECASE,
)


def is_video_hostname(hostname):
    """Return whether hostname is a recognized video host or subdomain."""
    hostname = hostname.lower().rstrip('.')
    if hostname.startswith('www.'):
        hostname = hostname[4:]
    return any(
        hostname == domain or hostname.endswith(f'.{domain}')
        for domain in VIDEO_DOMAINS
    )


def extract_urls_from_text(text):
    """Extract all URLs from text and filter video URLs."""
    all_urls = URL_PATTERN.findall(text)

    return [
        url for url in all_urls
        if is_video_hostname(urlparse(url).hostname or '')
    ]


def extract_urls_from_file(file_path):
    """Extract URLs from a file."""
    content = Path(file_path).read_text(encoding='utf-8')
    return extract_urls_from_text(content)


def main():
    if len(sys.argv) < 2:
        print("Usage: extract_urls.py <text_or_file>", file=sys.stderr)
        print("       If the argument is a file path, URLs will be extracted from the file.", file=sys.stderr)
        print("       Otherwise, URLs will be extracted from the provided text.", file=sys.stderr)
        sys.exit(1)

    if len(sys.argv) != 2:
        print("Error: pass exactly one text, file, or '-' argument", file=sys.stderr)
        sys.exit(1)

    input_arg = sys.argv[1]
    if input_arg == '-':
        content = sys.stdin.read()
        urls = extract_urls_from_text(content)
    elif Path(input_arg).is_file():
        urls = extract_urls_from_file(input_arg)
    else:
        urls = extract_urls_from_text(input_arg)

    print(json.dumps(urls, indent=2))


if __name__ == '__main__':
    main()
