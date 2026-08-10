#!/usr/bin/env python3
"""
Extract audio from video using yt-dlp and ffmpeg.
"""

import sys
import os
import subprocess
import argparse
from pathlib import Path

def extract_audio(url, output_dir=None, format='mp3', quality='192'):
    """Extract audio from video."""
    if output_dir is None:
        output_dir = os.getcwd()

    # Build yt-dlp command
    cmd = ['yt-dlp', url]

    # Set output template for audio
    cmd.extend(['-o', f'{output_dir}/%(title)s.{format}'])

    # Set format to extract audio only
    cmd.extend(['-f', 'bestaudio[ext=m4a]/bestaudio'])

    # Add post-processing to convert to desired format
    cmd.extend([
        '--extract-audio',
        '--audio-format', format,
        '--audio-quality', quality
    ])

    # Add useful metadata options
    cmd.extend([
        '--write-info-json',
        '--write-thumbnail'
    ])

    print(f"Extracting audio from: {url}", file=sys.stderr)
    print(f"Output format: {format}", file=sys.stderr)
    print(f"Output directory: {output_dir}", file=sys.stderr)

    try:
        result = subprocess.run(cmd, check=True)
        return result.returncode == 0
    except subprocess.CalledProcessError as e:
        print(f"Audio extraction failed: {e}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Error during audio extraction: {e}", file=sys.stderr)
        return False

def main():
    parser = argparse.ArgumentParser(description='Extract audio from video using yt-dlp')
    parser.add_argument('url', help='Video URL')
    parser.add_argument('-o', '--output', help='Output directory', default=os.getcwd())
    parser.add_argument('-f', '--format', help='Audio format', default='mp3',
                       choices=['mp3', 'm4a', 'opus', 'flac', 'wav'])
    parser.add_argument('-q', '--quality', help='Audio quality', default='192')
    args = parser.parse_args()

    success = extract_audio(args.url, args.output, args.format, args.quality)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
