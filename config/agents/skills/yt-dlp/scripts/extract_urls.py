#!/usr/bin/env python3
"""
Extract video URLs from text or files.
"""

import sys
import re
import json
from urllib.parse import urlparse

# Video domains to look for
VIDEO_DOMAINS = [
    r'youtube\.com',
    r'youtu\.be',
    r'twitter\.com',
    r'x\.com',
    r'vimeo\.com',
    r'tiktok\.com',
    r'instagram\.com',
    r'facebook\.com',
    r'fb\.watch',
    r'twitch\.tv',
    r'dailymotion\.com',
    r'nicovideo\.jp',
    r'bilibili\.com',
    r'reddit\.com',
    r'streamable\.com',
    r'clips\.twitch\.tv',
    r'video\.twimg\.com'
]

def extract_urls_from_text(text):
    """Extract all URLs from text and filter video URLs."""
    # URL pattern
    url_pattern = r'https?://(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)'

    # Find all URLs
    all_urls = re.findall(url_pattern, text, re.IGNORECASE)

    # Filter video URLs
    video_urls = []
    for url in all_urls:
        parsed = urlparse(url)
        domain = parsed.netloc.lower()

        # Remove www. prefix
        if domain.startswith('www.'):
            domain = domain[4:]

        # Check if it's a video domain
        for video_domain in VIDEO_DOMAINS:
            if re.search(video_domain, domain):
                video_urls.append(url)
                break

    return video_urls

def extract_urls_from_file(file_path):
    """Extract URLs from a file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        return extract_urls_from_text(content)
    except Exception as e:
        print(f"Error reading file {file_path}: {e}", file=sys.stderr)
        return []

def main():
    if len(sys.argv) < 2:
        print("Usage: extract_urls.py <text_or_file>", file=sys.stderr)
        print("       If the argument is a file path, URLs will be extracted from the file.", file=sys.stderr)
        print("       Otherwise, URLs will be extracted from the provided text.", file=sys.stderr)
        sys.exit(1)

    input_arg = sys.argv[1]

    # Check if input is a file path
    if len(sys.argv) == 2 and not sys.stdin.isatty():
        # Read from stdin
        content = sys.stdin.read()
        urls = extract_urls_from_text(content)
    elif input_arg.startswith('http') or ' ' in input_arg:
        # It's likely text with a URL
        urls = extract_urls_from_text(input_arg)
    else:
        # Try as file first
        try:
            urls = extract_urls_from_file(input_arg)
        except:
            # Fall back to treating as text
            urls = extract_urls_from_text(input_arg)

    # Output as JSON
    print(json.dumps(urls, indent=2))

if __name__ == '__main__':
    main()
