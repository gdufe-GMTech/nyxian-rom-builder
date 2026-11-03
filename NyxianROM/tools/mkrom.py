#!/usr/bin/env python3
"""
mkrom.py - package a Nyxian ROM (bootloader-compatible with public `main`)

Usage:
    python3 tools/mkrom.py <staging-dir> [-o rom.zip]
    python3 tools/mkrom.py <staging-dir> --inspect rom.zip

<staging-dir> must contain:
    main                  ROM slot dylib exporting NXSlotMain/NXSlotDidAppear/NXSlotCreateWindow
    Application/          (optional) one directory per .app

Output layout (the flasher strips the first path component of every entry,
so the wrapper "ROM/" is required):

    rom.zip
    └── ROM/
        ├── manifest.plist     <- parsed by ROMManifest; required
        ├── main               <- NXRomExecutable
        └── Application/...

Manifest keys implemented by Nyxian's bootloader (BootViewController.swift):
    NXRomManifestVersion (int, currently 1)
    NXRomIdentifier, NXRomName, NXRomVersion      (strings, required)
    NXRomMinimumNyxianVersion (string, required) / NXRomMaximumNyxianVersion (string, optional)
    NXRomExecutable (string, required, path inside the slot)
    NXRomDefaultFilePermission (int, default 0644) / NXRomDefaultDirectoryPermission (int, default 0755)
    NXRomPaths (array of { NXPath, NXPermission?, NXRequiresCodeSigning?, NXT2Entitlements? })
    NXRomBootLogo { Light, Dark } (optional) / NXRomInstaller / NXRomUninstaller (optional)
"""

import argparse
import os
import plistlib
import sys
import zipfile

DEFAULT_MIN_NYXIAN = "0.0.0"   # always satisfied; set --min-nyxian to your build if you want a floor


def collect(staging: str):
    if not os.path.isdir(staging):
        raise SystemExit(f"error: {staging} is not a directory")

    if not os.path.isfile(os.path.join(staging, "main")):
        raise SystemExit("error: missing 'main' (the ROM slot dylib)")

    files = ["main"]
    paths = [{"NXPath": "main", "NXRequiresCodeSigning": True}]

    apps_dir = os.path.join(staging, "Application")
    if os.path.isdir(apps_dir):
        for name in sorted(os.listdir(apps_dir)):
            if not name.endswith(".app"):
                continue

            bundle = os.path.join(apps_dir, name)
            plist_path = os.path.join(bundle, "Info.plist")
            if not os.path.isfile(plist_path):
                print(f"warning: {name} has no Info.plist, skipped", file=sys.stderr)
                continue

            with open(plist_path, "rb") as handle:
                info = plistlib.load(handle)

            executable = info.get("CFBundleExecutable")
            if not executable:
                print(f"warning: {name} has no CFBundleExecutable, skipped", file=sys.stderr)
                continue

            executable_path = os.path.join(bundle, executable)
            if not os.path.isfile(executable_path):
                print(f"warning: {name}: executable '{executable}' missing, skipped", file=sys.stderr)
                continue

            rel = f"Application/{name}/{executable}"
            paths.append({"NXPath": rel, "NXRequiresCodeSigning": True})

            for dirpath, _dirs, filenames in os.walk(bundle):
                for filename in filenames:
                    full = os.path.join(dirpath, filename)
                    files.append(os.path.relpath(full, staging).replace(os.sep, "/"))

    kexts_dir = os.path.join(staging, "kexts")
    if os.path.isdir(kexts_dir):
        for name in sorted(os.listdir(kexts_dir)):
            if not name.endswith(".kext"):
                continue

            bundle = os.path.join(kexts_dir, name)
            plist_path = os.path.join(bundle, "Info.plist")
            if not os.path.isfile(plist_path):
                print(f"warning: {name} has no Info.plist, skipped", file=sys.stderr)
                continue

            with open(plist_path, "rb") as handle:
                info = plistlib.load(handle)

            executable = info.get("CFBundleExecutable")
            if not executable or not os.path.isfile(os.path.join(bundle, executable)):
                print(f"warning: {name}: executable missing, skipped", file=sys.stderr)
                continue

            # kext 也要在刷机时重签，并加一个 NXT2 签名（空 entitlements 也可以，
            # 只要键存在，flasher 就会调 trust_nxt2_sign()）
            paths.append({
                "NXPath": f"kexts/{name}/{executable}",
                "NXRequiresCodeSigning": True,
                "NXT2Entitlements": {},
            })

            for dirpath, _dirs, filenames in os.walk(bundle):
                for filename in filenames:
                    full = os.path.join(dirpath, filename)
                    files.append(os.path.relpath(full, staging).replace(os.sep, "/"))

    return paths, files


def make_manifest(identifier, name, version, minimum, maximum, executable):
    manifest = {
        "NXRomManifestVersion": 1,
        "NXRomIdentifier": identifier,
        "NXRomName": name,
        "NXRomVersion": version,
        "NXRomMinimumNyxianVersion": minimum,
        "NXRomExecutable": executable,
        "NXRomDefaultFilePermission": 0o644,
        "NXRomDefaultDirectoryPermission": 0o755,
    }
    if maximum:
        manifest["NXRomMaximumNyxianVersion"] = maximum
    return manifest


def build(staging: str, output: str, identifier: str, name: str,
          version: str, minimum: str, maximum: str, flat: bool):
    paths, files = collect(staging)

    manifest = make_manifest(identifier, name, version, minimum, maximum, "main")
    manifest["NXRomPaths"] = paths

    prefix = "" if flat else "ROM/"

    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr(f"{prefix}manifest.plist", plistlib.dumps(manifest))
        for rel in files:
            archive.write(os.path.join(staging, rel), f"{prefix}{rel}")

    size = os.path.getsize(output)
    print(f"rom.zip  {size:,} bytes  ({len(files)} payload files + manifest.plist)")
    print(f"  identifier : {identifier}")
    print(f"  name       : {name} {version}")
    print(f"  min Nyxian : {minimum}" + (f"  max: {maximum}" if maximum else ""))
    print(f"  executable : main")
    print(f"  sign on flash: {', '.join(p['NXPath'] for p in paths)}")


def inspect(path: str):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        print(f"{path}: {len(names)} entries")
        for entry in sorted(names):
            print(f"  {archive.getinfo(entry).file_size:>10,}  {entry}")

        manifest_name = next((n for n in names if n.endswith("manifest.plist")), None)
        if manifest_name is None:
            print("error: no manifest.plist in archive", file=sys.stderr)
            return 1

        manifest = plistlib.loads(archive.read(manifest_name))
        required = ["NXRomManifestVersion", "NXRomIdentifier", "NXRomName",
                    "NXRomVersion", "NXRomMinimumNyxianVersion", "NXRomExecutable"]
        missing = [key for key in required if key not in manifest]
        if missing:
            print(f"error: manifest missing {', '.join(missing)}", file=sys.stderr)
            return 1

        root = os.path.dirname(manifest_name)
        executable = manifest["NXRomExecutable"]
        if f"{root}/{executable}" not in names:
            print(f"error: NXRomExecutable '{executable}' not in archive", file=sys.stderr)
            return 1

        for entry in manifest.get("NXRomPaths", []):
            target = f"{root}/{entry['NXPath']}"
            if target not in names:
                print(f"error: NXRomPaths entry '{entry['NXPath']}' not in archive", file=sys.stderr)
                return 1

        print("manifest: ok")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("staging")
    parser.add_argument("-o", "--output", default="rom.zip")
    parser.add_argument("--identifier", default="org.example.nyxrom")
    parser.add_argument("--name", default="NyxROM")
    parser.add_argument("--version", default="0.1.0")
    parser.add_argument("--min-nyxian", default=DEFAULT_MIN_NYXIAN)
    parser.add_argument("--max-nyxian", default="")
    parser.add_argument("--flat", action="store_true",
                        help="do not wrap entries in ROM/ (only for bootloaders that extract as-is)")
    parser.add_argument("--inspect", action="store_true")
    args = parser.parse_args()

    if args.inspect:
        sys.exit(inspect(args.staging))

    build(args.staging, args.output, args.identifier, args.name,
          args.version, args.min_nyxian, args.max_nyxian, args.flat)


if __name__ == "__main__":
    main()
