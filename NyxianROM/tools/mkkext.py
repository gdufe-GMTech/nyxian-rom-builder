#!/usr/bin/env python3
"""
mkkext.py - turn a compiled kext binary into a .kext bundle

Usage:
    python3 tools/mkkext.py <kext-src-dir> <binary> <out.kext>

<kext-src-dir>/kext.plist supplies NXKextIdentifier / NXKextVersion / CFBundleExecutable.
The produced Info.plist mirrors what Nyxian's own builder generates for a kext:
    CFBundleIdentifier, CFBundleExecutable, CFBundleName, CFBundlePackageType=KEXT,
    CFBundleVersion, NXKextIdentifier, NXKextVersion
"""

import os
import plistlib
import sys


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)

    source_dir, binary, out_bundle = sys.argv[1:4]
    spec_path = os.path.join(source_dir, "kext.plist")

    if not os.path.isfile(spec_path):
        raise SystemExit(f"error: {spec_path} not found")
    if not os.path.isfile(binary):
        raise SystemExit(f"error: {binary} not found")

    with open(spec_path, "rb") as handle:
        spec = plistlib.load(handle)

    identifier = spec.get("NXKextIdentifier")
    if not identifier:
        raise SystemExit("error: NXKextIdentifier missing from kext.plist")

    executable = spec.get("CFBundleExecutable") or os.path.basename(binary)
    version = spec.get("NXKextVersion", "1.0.0")

    info = {
        "CFBundleIdentifier": identifier,
        "CFBundleExecutable": executable,
        "CFBundleName": spec.get("NXKextDisplayName", identifier),
        "CFBundlePackageType": "KEXT",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": version,
        "NXKextIdentifier": identifier,
        "NXKextVersion": version,
    }

    os.makedirs(out_bundle, exist_ok=True)
    with open(os.path.join(out_bundle, "Info.plist"), "wb") as handle:
        plistlib.dump(info, handle)

    print(f"   info.plist -> {out_bundle}/Info.plist ({identifier} {version})")


if __name__ == "__main__":
    main()
