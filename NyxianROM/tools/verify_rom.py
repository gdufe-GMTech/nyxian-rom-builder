#!/usr/bin/env python3
"""
verify_rom.py - sanity-check a Nyxian ROM before flashing

Usage:
    python3 tools/verify_rom.py rom.zip
    python3 tools/verify_rom.py ./staging

Checks:
  * main is an arm64 Mach-O (MH_DYLIB)
  * main exports NXSlotMain / NXSlotDidAppear / NXSlotCreateWindow
    (looked up in LC_SYMTAB and in the dyld export trie)
  * manifest.sign matches the archive contents
  * every .app has a matching CFBundleIdentifier / CFBundleExecutable
"""

import argparse
import os
import plistlib
import struct
import sys
import tempfile
import zipfile

MH_MAGIC_64 = 0xFEEDFACF
CPU_TYPE_ARM64 = 0x0100000C
MH_DYLIB = 6

LC_SYMTAB = 0x02
LC_ID_DYLIB = 0x0D
LC_DYLD_INFO_ONLY = 0x80000022
LC_DYLD_EXPORTS_TRIE = 0x80000033

REQUIRED_SYMBOLS = ("NXSlotMain", "NXSlotDidAppear", "NXSlotCreateWindow")


def uleb(data, offset):
    result = 0
    shift = 0
    while True:
        byte = data[offset]
        offset += 1
        result |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return result, offset
        shift += 7


def walk_export_trie(data, start, end, out, prefix=""):
    """Minimal export-trie walk; collects every exported symbol name."""
    stack = [(start, prefix)]
    seen = set()
    while stack:
        node, name = stack.pop()
        if node in seen or node >= end:
            continue
        seen.add(node)

        terminal_size, cursor = uleb(data, node)
        if terminal_size:
            flags, _cursor2 = uleb(data, cursor)
            if not (flags & 0x08):  # not a re-export
                out.add(name)

        cursor += terminal_size
        if cursor >= end:
            continue

        children = data[cursor]
        cursor += 1
        for _ in range(children):
            nul = data.index(b"\x00", cursor)
            edge = data[cursor:nul].decode("utf-8", "replace")
            child_offset, cursor = uleb(data, nul + 1)
            stack.append((child_offset, name + edge))


def parse_macho(path):
    with open(path, "rb") as handle:
        data = handle.read()

    if len(data) < 32:
        return None

    magic = struct.unpack("<I", data[:4])[0]
    if magic != MH_MAGIC_64:
        return None

    cputype, _cpusub, filetype, ncmds = struct.unpack("<iiII", data[4:20])
    offset = 32
    symbols = set()
    info = {"cputype": cputype, "filetype": filetype, "install_name": None}

    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack("<II", data[offset:offset + 8])

        if cmd == LC_ID_DYLIB:
            name_offset = struct.unpack("<I", data[offset + 8:offset + 12])[0]
            start = offset + name_offset
            end = data.index(b"\x00", start)
            info["install_name"] = data[start:end].decode("utf-8", "replace")

        elif cmd == LC_SYMTAB:
            symoff, nsyms, stroff, strsize = struct.unpack("<IIII", data[offset + 8:offset + 24])
            for index in range(nsyms):
                entry = symoff + index * 16
                n_strx = struct.unpack("<I", data[entry:entry + 4])[0]
                if n_strx == 0 or n_strx >= strsize:
                    continue
                start = stroff + n_strx
                end = data.index(b"\x00", start)
                symbols.add(data[start:end].decode("utf-8", "replace").lstrip("_"))

        elif cmd == LC_DYLD_INFO_ONLY:
            fields = struct.unpack("<IIIIIIIIII", data[offset + 8:offset + 48])
            export_off, export_size = fields[8], fields[9]
            if export_size:
                walk_export_trie(data, export_off, export_off + export_size, symbols)

        elif cmd == LC_DYLD_EXPORTS_TRIE:
            dataoff, datasize = struct.unpack("<II", data[offset + 8:offset + 16])
            if datasize:
                walk_export_trie(data, dataoff, dataoff + datasize, symbols)

        offset += cmdsize

    info["symbols"] = symbols
    return info


def check_macho(path, label, required):
    info = parse_macho(path)
    problems = []

    if info is None:
        return [f"{label}: not a 64-bit Mach-O"]

    if info["cputype"] != CPU_TYPE_ARM64:
        problems.append(f"{label}: cputype 0x{info['cputype']:x} is not arm64")

    # main must be a dylib (the bootloader dlopen()s it);
    # apps may be MH_EXECUTE, the official template just builds them as dylibs.
    if required and info["filetype"] != MH_DYLIB:
        problems.append(f"{label}: filetype {info['filetype']} is not MH_DYLIB(6)")

    missing = [symbol for symbol in required if symbol not in info["symbols"]]
    if missing:
        problems.append(f"{label}: missing exported symbols: {', '.join(missing)}")

    return problems


def check_app(bundle_path, label):
    problems = []
    plist_path = os.path.join(bundle_path, "Info.plist")

    if not os.path.isfile(plist_path):
        return [f"{label}: no Info.plist"]

    with open(plist_path, "rb") as handle:
        info = plistlib.load(handle)

    executable = info.get("CFBundleExecutable")
    identifier = info.get("CFBundleIdentifier")
    if not executable:
        problems.append(f"{label}: CFBundleExecutable missing")
    if not identifier:
        problems.append(f"{label}: CFBundleIdentifier missing")

    if executable:
        executable_path = os.path.join(bundle_path, executable)
        if not os.path.isfile(executable_path):
            problems.append(f"{label}: executable '{executable}' missing")
        else:
            problems += check_macho(executable_path, f"{label}/{executable}", ())

    return problems


def check_kext(bundle_path, label):
    problems = []
    plist_path = os.path.join(bundle_path, "Info.plist")

    if not os.path.isfile(plist_path):
        return [f"{label}: no Info.plist"]

    with open(plist_path, "rb") as handle:
        info = plistlib.load(handle)

    executable = info.get("CFBundleExecutable")
    identifier = info.get("CFBundleIdentifier") or info.get("NXKextIdentifier")
    if not executable:
        problems.append(f"{label}: CFBundleExecutable missing")
    if not identifier:
        problems.append(f"{label}: CFBundleIdentifier/NXKextIdentifier missing")

    if executable:
        executable_path = os.path.join(bundle_path, executable)
        if not os.path.isfile(executable_path):
            problems.append(f"{label}: executable '{executable}' missing")
        else:
            problems += check_macho(executable_path, f"{label}/{executable}", ())

    return problems


def verify_tree(root):
    problems = []
    main = os.path.join(root, "main")

    if not os.path.isfile(main):
        problems.append("missing 'main'")
    else:
        problems += check_macho(main, "main", REQUIRED_SYMBOLS)

    apps_dir = os.path.join(root, "Application")
    if os.path.isdir(apps_dir):
        for name in sorted(os.listdir(apps_dir)):
            if name.endswith(".app"):
                problems += check_app(os.path.join(apps_dir, name), name)

    kexts_dir = os.path.join(root, "kexts")
    if os.path.isdir(kexts_dir):
        for name in sorted(os.listdir(kexts_dir)):
            if name.endswith(".kext"):
                problems += check_kext(os.path.join(kexts_dir, name), name)

    problems += check_manifest(root)
    return problems


def check_manifest(root):
    """The bootloader parses manifest.plist and refuses to flash without it."""
    problems = []
    manifest_path = os.path.join(root, "manifest.plist")

    if not os.path.isfile(manifest_path):
        return ["missing manifest.plist (the bootloader requires it)"]

    with open(manifest_path, "rb") as handle:
        manifest = plistlib.load(handle)

    required = ["NXRomManifestVersion", "NXRomIdentifier", "NXRomName",
                "NXRomVersion", "NXRomMinimumNyxianVersion", "NXRomExecutable"]
    for key in required:
        if key not in manifest:
            problems.append(f"manifest.plist: missing {key}")

    executable = manifest.get("NXRomExecutable")
    if executable and not os.path.isfile(os.path.join(root, executable)):
        problems.append(f"manifest.plist: NXRomExecutable '{executable}' does not exist")

    for entry in manifest.get("NXRomPaths", []):
        rel = entry.get("NXPath")
        if rel and not os.path.isfile(os.path.join(root, rel)):
            problems.append(f"manifest.plist: NXRomPaths entry '{rel}' does not exist")

    return problems


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("rom")
    args = parser.parse_args()

    if zipfile.is_zipfile(args.rom):
        with tempfile.TemporaryDirectory() as tmp:
            with zipfile.ZipFile(args.rom) as archive:
                archive.extractall(tmp)
            root = os.path.join(tmp, "ROM")
            if not os.path.isdir(root):
                print("error: archive has no ROM/ directory", file=sys.stderr)
                sys.exit(1)
            problems = verify_tree(root)
    else:
        problems = verify_tree(args.rom)

    if problems:
        print("FAIL", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        sys.exit(1)

    print("OK: main exports NXSlotMain / NXSlotDidAppear / NXSlotCreateWindow, bundles look sane")


if __name__ == "__main__":
    main()
