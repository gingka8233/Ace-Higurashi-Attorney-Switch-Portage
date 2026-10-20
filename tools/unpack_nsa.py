#!/usr/bin/env python3
"""Extract standard NScripter NSA archives, including SPB bitmap assets.

Independent reader implementing the documented NSA/SPB formats; compatible with
this game's archive. Please keep copyright notices of any extracted media.
"""
import argparse
from pathlib import Path
import struct


class BitReader:
    def __init__(self, data):
        self.data = memoryview(data)
        self.position = 0

    def take(self, n):
        value = 0
        for _ in range(n):
            i = self.position >> 3
            if i >= len(self.data):
                raise ValueError('Truncated SPB stream')
            value = (value << 1) | ((self.data[i] >> (7 - (self.position & 7))) & 1)
            self.position += 1
        return value


def decode_spb(src):
    if len(src) < 6:
        raise ValueError('Truncated SPB image')
    w, h = struct.unpack_from('>HH', src, 0)
    if not 0 < w <= 8192 or not 0 < h <= 8192:
        raise ValueError('Invalid SPB dimensions')
    stride = (w * 3 + 3) & ~3
    size = 54 + h * stride
    bmp = bytearray(size)
    struct.pack_into('<2sIHHI', bmp, 0, b'BM', size, 0, 0, 54)
    struct.pack_into('<IIIHHIIIIII', bmp, 14, 40, w, h, 1, 24, 0, size - 54, 0, 0, 0, 0)
    bits = BitReader(src[4:])
    pixels = w * h
    for channel in range(3):
        plane = bytearray(pixels)
        value = bits.take(8)
        plane[0] = value
        p = 1
        while p < pixels:
            mode = bits.take(3)
            if mode == 0:
                n = min(4, pixels - p)
                plane[p:p+n] = bytes([value]) * n
                p += n
                continue
            width = bits.take(1) + 1 if mode == 7 else mode + 2
            for _ in range(min(4, pixels - p)):
                code = bits.take(width)
                if width == 8:
                    value = code
                elif code & 1:
                    value = (value + (code >> 1) + 1) & 255
                else:
                    value = (value - (code >> 1)) & 255
                plane[p] = value
                p += 1
        for scan in range(h):
            bottom_up_y = h - 1 - scan
            start = 54 + bottom_up_y * stride + channel
            row = plane[scan*w:(scan+1)*w]
            if scan & 1:
                row.reverse()
            bmp[start:start + 3*w:3] = row
    return bytes(bmp)


def entries(archive):
    if len(archive) < 6:
        raise ValueError('NSA archive truncated')
    n = int.from_bytes(archive[0:2], 'big')
    base = int.from_bytes(archive[2:6], 'big')
    pos = 6
    for _ in range(n):
        end = archive.index(b'\x00', pos)
        name = archive[pos:end].decode('cp932').replace('\\', '/')
        comp = archive[end+1]
        offset, packed, unpacked = struct.unpack_from('>III', archive, end+2)
        pos = end + 14
        if not 0 <= offset + base <= offset + base + packed <= len(archive):
            raise ValueError('Bad NSA offset for ' + name)
        yield name, comp, archive[base+offset:base+offset+packed], unpacked
    if pos != base:
        raise ValueError('NSA index size mismatch')


def extract(src, out):
    src = Path(src)
    root = Path(out).resolve()
    root.mkdir(parents=True, exist_ok=True)
    count = 0
    for name, compression, payload, expected in entries(src.read_bytes()):
        dst = (root / name).resolve()
        if not dst.is_relative_to(root):
            raise ValueError('Path outside target directory: ' + name)
        if compression == 0:
            data = payload
        elif compression == 1:
            data = decode_spb(payload)
        else:
            raise ValueError(f'Unknown NSA compression mode {compression} for {name}')
        if len(data) != expected:
            raise ValueError(f'Bad decoded size for {name}: {len(data)} != {expected}')
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(data)
        count += 1
    return count


if __name__ == '__main__':
    cli = argparse.ArgumentParser(description='Unpack a NScripter arc.nsa archive')
    cli.add_argument('archive', type=Path)
    cli.add_argument('destination', type=Path)
    args = cli.parse_args()
    count = extract(args.archive, args.destination)
    print(f'{count} resources extracted into {args.destination}')
