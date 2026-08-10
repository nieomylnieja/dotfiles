#!/usr/bin/env python3
"""
Test script for yt-dlp functionality.
"""

import subprocess
import sys

def test_yt_dlp_installed():
    """Check if yt-dlp is installed."""
    try:
        result = subprocess.run(['yt-dlp', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✓ yt-dlp is installed: version {result.stdout.strip()}")
            return True
        else:
            print("✗ yt-dlp command failed")
            return False
    except FileNotFoundError:
        print("✗ yt-dlp is not installed")
        print("  Install with: pip install yt-dlp")
        return False

def test_ffmpeg_installed():
    """Check if ffmpeg is installed."""
    try:
        result = subprocess.run(['ffmpeg', '-version'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✓ ffmpeg is installed")
            return True
        else:
            print("✗ ffmpeg command failed")
            return False
    except FileNotFoundError:
        print("✗ ffmpeg is not installed (required for format conversion)")
        print("  Install with: brew install ffmpeg (macOS) or apt install ffmpeg (Linux)")
        return False

def test_extract_urls():
    """Test URL extraction."""
    import extract_urls

    test_cases = [
        ("Check out https://youtube.com/watch?v=test", 1),
        ("Multiple: https://youtu.be/abc and https://vimeo.com/123", 2),
        ("No video links here", 0),
    ]

    print("\nTesting URL extraction:")
    all_passed = True

    for text, expected_count in test_cases:
        urls = extract_urls.extract_urls_from_text(text)
        if len(urls) == expected_count:
            print(f"✓ Found {expected_count} URL(s) in: '{text}'")
        else:
            print(f"✗ Expected {expected_count} URLs, got {len(urls)} in: '{text}'")
            all_passed = False

    return all_passed

def test_video_url_detection():
    """Test video URL detection."""
    import download_video

    test_cases = [
        ("https://youtube.com/watch?v=abc", True),
        ("https://youtu.be/xyz", True),
        ("https://twitter.com/user/status/123", True),
        ("https://example.com/video.mp4", False),
        ("https://google.com", False),
    ]

    print("\nTesting video URL detection:")
    all_passed = True

    for url, expected in test_cases:
        result = download_video.is_video_url(url)
        if result == expected:
            print(f"✓ Correctly identified {url} as {'video' if expected else 'non-video'}")
        else:
            print(f"✗ Wrong classification for {url}")
            all_passed = False

    return all_passed

def main():
    print("Testing yt-dlp Skill Setup\n")
    print("=" * 50)

    # Check dependencies
    yt_dlp_ok = test_yt_dlp_installed()
    ffmpeg_ok = test_ffmpeg_installed()

    # Test modules
    try:
        extract_urls_ok = test_extract_urls()
        detection_ok = test_video_url_detection()
    except Exception as e:
        print(f"\n✗ Module test failed: {e}")
        extract_urls_ok = detection_ok = False

    print("\n" + "=" * 50)

    # Summary
    if yt_dlp_ok and ffmpeg_ok:
        print("✓ Basic setup looks good!")
        print("  The skill is ready to use.")
    else:
        print("✗ Please install missing dependencies before using the skill.")
        sys.exit(1)

    if extract_urls_ok and detection_ok:
        print("✓ All module tests passed!")
    else:
        print("✗ Some module tests failed.")
        sys.exit(1)

if __name__ == '__main__':
    main()
