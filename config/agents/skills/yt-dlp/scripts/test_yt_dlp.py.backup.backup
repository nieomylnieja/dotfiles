#!/usr/bin/env python3

import io
import json
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import patch

import download_video
import extract_audio
import extract_urls


def completed_download(directory, filename):
    path = Path(directory, filename)
    path.write_text("media", encoding="utf-8")
    return subprocess.CompletedProcess(
        [],
        0,
        f"{download_video.OUTPUT_MARKER}{path}\n",
        "",
    )


def temporary_directory():
    timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    return tempfile.TemporaryDirectory(prefix=f"yt-dlp-test-{timestamp}-")


class VideoUrlTest(unittest.TestCase):
    def test_accepts_exact_hosts_and_subdomains(self):
        self.assertTrue(download_video.is_video_url("https://youtube.com/watch?v=1"))
        self.assertTrue(download_video.is_video_url("https://M.YOUTUBE.COM./watch?v=1"))

    def test_rejects_lookalikes_and_embedded_credentials(self):
        self.assertFalse(download_video.is_video_url("https://youtube.com.example.test/video"))
        self.assertFalse(download_video.is_video_url("https://youtube.com@example.test/video"))
        self.assertFalse(download_video.is_video_url("https://user:secret@youtube.com/video"))

    def test_redacts_the_full_source_url(self):
        url = "https://youtube.com/watch?v=1&token=secret"
        redacted = download_video.redact_url(f"failed for {url}", url)

        self.assertNotIn("token=secret", redacted)
        self.assertIn("youtube.com", redacted)

    def test_redacts_normalized_and_redirect_urls(self):
        source = "https://youtube.com/watch?v=1&token=secret#fragment"
        diagnostic = (
            "failed at https://youtube.com/watch?v=1&token=secret and "
            "https://cdn.example.test/file?token=cdn-secret"
        )

        redacted = download_video.redact_url(diagnostic, source)

        self.assertNotIn("token=secret", redacted)
        self.assertNotIn("cdn-secret", redacted)
        self.assertIn("youtube.com", redacted)
        self.assertIn("cdn.example.test", redacted)


class DownloaderCommandTest(unittest.TestCase):
    @patch("download_video.subprocess.run")
    def test_defaults_to_one_video_without_sidecars(self, run):
        with temporary_directory() as directory:
            run.return_value = completed_download(directory, "video.mp4")

            result = download_video.download_video(
                "https://youtube.com/watch?v=1", directory
            )

            self.assertEqual(result, str(Path(directory, "video.mp4")))

        command = run.call_args.args[0]
        self.assertIn("--ignore-config", command)
        self.assertIn("--no-playlist", command)
        self.assertNotIn("--write-info-json", command)
        self.assertNotIn("--write-thumbnail", command)
        self.assertTrue(run.call_args.kwargs["capture_output"])

    @patch("download_video.subprocess.run")
    def test_explicit_format_takes_priority_over_quality(self, run):
        with temporary_directory() as directory:
            run.return_value = completed_download(directory, "video.mp4")

            download_video.download_video(
                "https://youtube.com/watch?v=1",
                output_dir=directory,
                format="137+140",
                quality="720p",
            )

        command = run.call_args.args[0]
        format_index = command.index("-f")
        self.assertEqual(command[format_index + 1], "137+140")

    @patch("download_video.subprocess.run")
    def test_rejects_zero_exit_without_an_output_file(self, run):
        run.return_value = subprocess.CompletedProcess([], 0, "", "")
        stderr = io.StringIO()

        with redirect_stderr(stderr):
            result = download_video.download_video(
                "https://youtube.com/watch?v=1"
            )

        self.assertIsNone(result)
        self.assertIn("did not report one existing output file", stderr.getvalue())

    @patch("download_video.subprocess.run")
    def test_failure_output_redacts_a_signed_url(self, run):
        url = "https://youtube.com/watch?v=1&token=secret"
        run.side_effect = subprocess.CalledProcessError(
            1,
            ["yt-dlp"],
            stderr=f"failed to download {url}",
        )
        stderr = io.StringIO()

        with redirect_stderr(stderr):
            success = download_video.download_video(url)

        self.assertFalse(success)
        self.assertNotIn("token=secret", stderr.getvalue())

    @patch("download_video.subprocess.run")
    def test_info_timeout_does_not_print_a_signed_url(self, run):
        url = "https://youtube.com/watch?v=1&token=secret"
        run.side_effect = subprocess.TimeoutExpired(
            ["yt-dlp", "--dump-json", url], 30
        )
        stderr = io.StringIO()

        with redirect_stderr(stderr):
            info = download_video.extract_video_info(url)

        self.assertIsNone(info)
        self.assertNotIn("token=secret", stderr.getvalue())
        self.assertIn("timed out", stderr.getvalue())

    @patch("download_video.subprocess.run")
    def test_info_mode_disables_playlist_expansion(self, run):
        run.return_value = subprocess.CompletedProcess(
            [], 0, '{"id":"video-1"}\n', ""
        )

        info = download_video.extract_video_info(
            "https://youtube.com/watch?v=1"
        )

        self.assertEqual(info["id"], "video-1")
        self.assertIn("--ignore-config", run.call_args.args[0])
        self.assertIn("--no-playlist", run.call_args.args[0])


class AudioCommandTest(unittest.TestCase):
    @patch("extract_audio.subprocess.run")
    def test_defaults_to_one_audio_file_without_sidecars(self, run):
        with temporary_directory() as directory:
            run.return_value = completed_download(directory, "audio.mp3")

            result = extract_audio.extract_audio(
                "https://youtube.com/watch?v=1", directory
            )

            self.assertEqual(result, str(Path(directory, "audio.mp3")))

        command = run.call_args.args[0]
        self.assertIn("--ignore-config", command)
        self.assertIn("--no-playlist", command)
        self.assertNotIn("--write-info-json", command)
        self.assertNotIn("--write-thumbnail", command)
        self.assertTrue(run.call_args.kwargs["capture_output"])

    @patch("extract_audio.subprocess.run")
    def test_rejects_zero_exit_without_an_output_file(self, run):
        run.return_value = subprocess.CompletedProcess([], 0, "", "")
        stderr = io.StringIO()

        with redirect_stderr(stderr):
            result = extract_audio.extract_audio(
                "https://youtube.com/watch?v=1"
            )

        self.assertIsNone(result)
        self.assertIn("did not report one existing output file", stderr.getvalue())

    @patch("extract_audio.subprocess.run")
    def test_failure_output_redacts_a_signed_url(self, run):
        url = "https://youtube.com/watch?v=1&token=secret"
        run.side_effect = subprocess.CalledProcessError(
            1,
            ["yt-dlp", url],
            stderr=f"failed to download {url}",
        )
        stderr = io.StringIO()

        with redirect_stderr(stderr):
            success = extract_audio.extract_audio(url)

        self.assertFalse(success)
        self.assertNotIn("token=secret", stderr.getvalue())


class UrlExtractionTest(unittest.TestCase):
    def test_filters_lookalike_hosts(self):
        text = (
            "keep https://youtu.be/abc and "
            "drop https://youtube.com.example.test/watch?v=1"
        )

        self.assertEqual(
            extract_urls.extract_urls_from_text(text),
            ["https://youtu.be/abc"],
        )

    def test_dash_reads_piped_input(self):
        script = Path(extract_urls.__file__)
        result = subprocess.run(
            [sys.executable, str(script), "-"],
            input="watch https://vimeo.com/123",
            capture_output=True,
            check=False,
            text=True,
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout), ["https://vimeo.com/123"])


if __name__ == "__main__":
    unittest.main()
