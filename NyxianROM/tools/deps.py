#!/usr/bin/env python3
"""
deps.py - print the dylibs a Mach-O links against (LC_LOAD_DYLIB / LC_LOAD_WEAK_DYLIB)

Usage:
    python3 tools/deps.py <macho> [more...]
"""

import struct
import sys

LC_LOAD_DYLIB = 0x0C
LC_LOAD_WEAK_DYLIB = 0x80000018
LC_REEXPORT_DYLIB = 0x8000001F


def dylibs(path):
    with open(path, "rb") as handle:
        data = handle.read()

    if len(data) < 32 or struct.unpack("<I", data[:4])[0] != 0xFEEDFACF:
        return None

    ncmds = struct.unpack("<I", data[16:20])[0]
    offset = 32
    result = []

    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack("<II", data[offset:offset + 8])
        if cmd in (LC_LOAD_DYLIB, LC_LOAD_WEAK_DYLIB, LC_REEXPORT_DYLIB):
            name_offset = struct.unpack("<I", data[offset + 8:offset + 12])[0]
            start = offset + name_offset
            end = data.index(b"\x00", start)
            result.append(data[start:end].decode("utf-8", "replace"))
        offset += cmdsize

    return result


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)

    for path in sys.argv[1:]:
        entries = dylibs(path)
        print(f"== {path}")
        if entries is None:
            print("   (not a 64-bit Mach-O)")
            continue
        for entry in entries:
            print(f"   {entry}")
        if not entries:
            print("   (no dylib dependencies)")


if __name__ == "__main__":
    main()
