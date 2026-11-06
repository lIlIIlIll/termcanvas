#!/usr/bin/env python3
"""Exercise real GIF encoding of flat terminal colors and changing frames."""
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
import zlib

from visual_preview import encode_gif


def frame(marker_x):
    width, height = 32, 16
    background = bytes((19, 20, 34))
    rows = []
    for y in range(height):
        pixels = bytearray(background * width)
        if 6 <= y < 10:
            for x in range(marker_x, marker_x + 4):
                pixels[3*x:3*x+3] = bytes((240, 180, 60))
        rows.append(b"\0" + bytes(pixels))
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b""))


@unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg is required for GIF encoding")
class PreviewGifTests(unittest.TestCase):
    def test_flat_background_and_distinct_frames_survive_encoding(self):
        with tempfile.TemporaryDirectory(prefix="preview-gif-") as tmp:
            root = Path(tmp)
            (root / "frame-0000.png").write_bytes(frame(4))
            (root / "frame-0001.png").write_bytes(frame(12))
            gif = root / "capture.gif"
            encode_gif(root, gif, 2, os.environ.copy(), 15)
            result = subprocess.run(["ffmpeg", "-v", "error", "-i", str(gif), "-frames:v", "2",
                                     "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                                    check=True, capture_output=True, timeout=15)
            size = 32 * 16 * 3
            self.assertEqual(len(result.stdout), 2 * size)
            first, second = result.stdout[:size], result.stdout[size:]
            self.assertTrue(first != second, "the changing marker must appear in distinct frames")
            self.assertEqual(first[:32*3], bytes((19, 20, 34)) * 32)
            self.assertEqual(second[:32*3], bytes((19, 20, 34)) * 32)


if __name__ == "__main__":
    unittest.main()
