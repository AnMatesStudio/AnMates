"""Crop the 4-up food reference image into 4 individual card illustrations.

The reference image is a 2x2 grid with bottom labels (LẨU / CAFE CHILL /
ĐỒ NƯỚNG / ĂN VẶT). We crop each quadrant, then trim ~22% off the bottom
to drop the label text — the Flutter UI renders the caption separately.

Usage:
    python scripts/crop_food_reference.py
"""
from pathlib import Path
from PIL import Image

SRC = Path("plan/screenshot/food_reference.png")
DST = Path("anmates_flutter/assets/food")

# Order: top-left, top-right, bottom-left, bottom-right
TILES = [
    ("lau.png",   0, 0),
    ("cafe.png",  1, 0),
    ("nuong.png", 0, 1),
    ("vat.png",   1, 1),
]

# How much of each tile's bottom to crop off (the label band)
LABEL_CROP_RATIO = 0.22

# Inner padding ratio to remove the white card border
INNER_PAD_RATIO = 0.03

# Each food sits roughly in the middle 65% of its tile horizontally.
# Crop that band so the resulting image is closer to square (better for
# our portrait-oriented polaroid card slots with BoxFit.cover).
CENTER_WIDTH_RATIO = 0.72


def main() -> None:
    if not SRC.exists():
        raise SystemExit(
            f"Reference image not found at {SRC}. Save it there first."
        )

    DST.mkdir(parents=True, exist_ok=True)
    img = Image.open(SRC).convert("RGBA")
    W, H = img.size
    tw, th = W // 2, H // 2

    for name, col, row in TILES:
        left = col * tw
        upper = row * th
        right = left + tw
        lower = upper + th

        tile = img.crop((left, upper, right, lower))
        # Drop bottom label band
        nw, nh = tile.size
        tile = tile.crop((0, 0, nw, int(nh * (1 - LABEL_CROP_RATIO))))
        # Trim inner border
        nw, nh = tile.size
        pad_x = int(nw * INNER_PAD_RATIO)
        pad_y = int(nh * INNER_PAD_RATIO)
        tile = tile.crop((pad_x, pad_y, nw - pad_x, nh - pad_y))
        # Center-crop horizontally to focus on the food
        nw, nh = tile.size
        keep_w = int(nw * CENTER_WIDTH_RATIO)
        side = (nw - keep_w) // 2
        tile = tile.crop((side, 0, side + keep_w, nh))

        out = DST / name
        tile.save(out, optimize=True)
        print(f"  [ok] {out} -- {tile.size}")

    print(f"\nDone. 4 illustrations saved to {DST}/")


if __name__ == "__main__":
    main()
