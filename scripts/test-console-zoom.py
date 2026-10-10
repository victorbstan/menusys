"""Check actual native console glyph size, independent of HUD/UI zoom.

Requires Pillow and NumPy. Captures contain 'ZOOMCHECK ZOOMCHECK'; the template
comes from the selected game's conchars artwork. Searches native margins and
scroll positions, but fixes the expected physical glyph dimensions.
"""
import argparse
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image


def console_template(data):
    pak = (data / 'pak0.pak').read_bytes()
    magic, offset, size = struct.unpack_from('<4sii', pak)
    assert magic == b'PACK'
    wad = None
    for position in range(offset, offset + size, 64):
        name, start, length = struct.unpack_from('<56sii', pak, position)
        if name.split(b'\0')[0] == b'gfx.wad':
            wad = pak[start:start + length]
    assert wad is not None, 'Missing gfx.wad'
    _, count, offset = struct.unpack_from('<4sii', wad)
    font = None
    for position in range(offset, offset + 32 * count, 32):
        start, size, _, _, _, _, name = struct.unpack_from('<iiiBBH16s', wad, position)
        if name.split(b'\0')[0].lower() == b'conchars':
            font = np.frombuffer(wad[start:start + size], dtype=np.uint8).reshape(128, 128)
    assert font is not None, 'Missing conchars'
    return np.concatenate([
        font[ord(char) // 16 * 8:ord(char) // 16 * 8 + 8,
             ord(char) % 16 * 8:ord(char) % 16 * 8 + 8]
        for char in 'ZOOMCHECK ZOOMCHECK'
    ], axis=1) != 0


def check(capture, template, scale):
    pixels = np.array(Image.open(capture).convert('RGB')).astype(int)
    height, width = pixels.shape[:2]
    # Native Quake font shades are grayscale; ignore the brown conback artwork.
    foreground = (pixels.max(axis=2) - pixels.min(axis=2) < 25) & (pixels.min(axis=2) > 20)
    rows = height - int(8 * scale)
    columns = min(65, width - int(template.shape[1] * scale))
    assert rows > 0 and columns > 0
    scores = np.zeros((rows, columns))
    # Sample centers of original artwork pixels to tolerate raster rounding.
    for y in range(8):
        for x in range(template.shape[1]):
            px, py = int((x + .5) * scale), int((y + .5) * scale)
            scores += foreground[py:py + rows, px:px + columns] == template[y, x]
    y, x = np.unravel_index(scores.argmax(), scores.shape)
    matched = float(scores[y, x] / template.size)
    # Fractional glyphs can differ at raster boundaries in FTE's font cache.
    minimum = .95 if scale % 1 else .97
    assert matched > minimum, f'{capture}: expected {scale}x console text, matched {matched:.3f}'
    return dict(capture=str(capture), scale=scale, matched=matched, x=int(x), y=int(y))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data', type=Path, required=True)
    parser.add_argument('--scale', type=float, required=True)
    parser.add_argument('--captures', type=Path, nargs='+', required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    results = [check(capture, console_template(args.data), args.scale) for capture in args.captures]
    if args.output:
        args.output.write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
    print(f'PASS: {len(results)} native console captures at {args.scale:g}x')


if __name__ == '__main__':
    main()
