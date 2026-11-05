#!/usr/bin/env python3
"""
bake_ipa.py - 把你的 ROM 烤进 Nyxian.ipa，做成"装了就是自己系统"的安装包

原理（不改一行 Nyxian 源码）：
    Nyxian 的引导器在"没有刷任何槽"时会 dlopen
    Payload/Nyxian.app/Frameworks/SuperSlot.dylib 作为内置槽。
    所以把我们的 main 换到那个位置，装完开机直接进我们的 ROM。

用法:
    python3 tools/bake_ipa.py --ipa Nyxian.ipa --dylib main -o Nyxian-baked.ipa
    python3 tools/bake_ipa.py --ipa Nyxian.ipa --dylib main --rom rom.zip --strip-official
    python3 tools/bake_ipa.py --ipa Nyxian.ipa --report

    --keep-official      保留官方 SuperSlot 备份（默认开）
    --strip-official     不保留备份（省 ~19.8 MB，但就没法"改回来"了）
    --strip <path>       额外剔除某个条目/前缀（相对 Payload/<app>/，可重复），自己负责
    --report             只打印包里最大的条目，用来决定要不要 strip
"""

import argparse
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from verify_rom import parse_macho, REQUIRED_SYMBOLS, CPU_TYPE_ARM64  # noqa: E402

SUPERSLOT = "Frameworks/SuperSlot.dylib"
OFFICIAL_BACKUP = "Frameworks/SuperSlot.official.dylib"


def find_app_prefix(names):
    for name in names:
        parts = name.split("/")
        if len(parts) >= 3 and parts[0] == "Payload" and parts[1].endswith(".app") and parts[2] == "Info.plist":
            return "/".join(parts[:2]) + "/"
    return None


def check_dylib(path):
    info = parse_macho(path)
    if info is None:
        raise SystemExit(f"error: {path} is not a 64-bit Mach-O")
    if info["cputype"] != CPU_TYPE_ARM64:
        raise SystemExit(f"error: {path} is not arm64")
    missing = [symbol for symbol in REQUIRED_SYMBOLS if symbol not in info["symbols"]]
    if missing:
        raise SystemExit(f"error: {path} is missing exports: {', '.join(missing)}")
    return info


def report(ipa_path, limit=15):
    with zipfile.ZipFile(ipa_path) as archive:
        infos = sorted(archive.infolist(), key=lambda i: -i.file_size)
        total = sum(i.file_size for i in infos)
        print(f"{ipa_path}: {len(infos)} entries, {total:,} bytes uncompressed")
        for info in infos[:limit]:
            print(f"  {info.file_size:>12,}  {info.filename}")


def bake(ipa_path, dylib_path, rom_path, output, keep_official, strips, stage_guests=False):
    check_dylib(dylib_path)

    with zipfile.ZipFile(ipa_path) as source:
        names = source.namelist()
        app_prefix = find_app_prefix(names)
        if app_prefix is None:
            raise SystemExit("error: not an .ipa (no Payload/*.app/Info.plist)")

        target = app_prefix + SUPERSLOT
        if target not in names:
            raise SystemExit(f"error: {target} not found in {ipa_path}")

        with open(dylib_path, "rb") as handle:
            replacement = handle.read()

        strip_prefixes = [app_prefix + item.lstrip("/") for item in strips]
        if keep_official:
            strip_prefixes = [p for p in strip_prefixes if not p.startswith(app_prefix + OFFICIAL_BACKUP)]

        saved = 0
        written = 0
        replaced = False

        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as out:
            for info in source.infolist():
                name = info.filename
                if not name or name.endswith("/"):
                    continue

                if any(name == prefix or name.startswith(prefix.rstrip("/") + "/") for prefix in strip_prefixes):
                    saved += info.file_size
                    continue

                if name == target:
                    out.writestr(name, replacement)
                    replaced = True
                    written += 1
                    continue

                out.writestr(name, source.read(name))
                written += 1

            if keep_official and app_prefix + OFFICIAL_BACKUP not in names:
                out.writestr(app_prefix + OFFICIAL_BACKUP, source.read(target))

            if rom_path:
                with open(rom_path, "rb") as handle:
                    out.writestr(app_prefix + "BakedROM.zip", handle.read())

                # Nyxian 的 ksurface 初始化要求 dylib 同级存在 Application/，
                # 否则 ksurface_kinit 会 kpanic（EXC_BREAKPOINT / brk 1）。
                # 烤包模式下 dylib 位于 Payload/<app>/Frameworks/，所以在那里
                # 放一个占位目录即可。
                #
                # 刻意不摊 kexts/：kext 是未签名的，烤包模式没有刷机时的重签
                # 流程，装了也用不了；而且 kext 目录里可能带 .dSYM，Sideloadly
                # 会把 DWARF 文件当成 Mach-O 去重签，直接报
                # "macho sign/edit failed (-40)"。
                staged = 0
                with zipfile.ZipFile(rom_path) as rom:
                    for info in rom.infolist():
                        name = info.filename
                        if name.endswith("/"):
                            continue
                        if ".dSYM/" in name or "/__MACOSX/" in name:
                            continue
                        if not name.startswith("ROM/Application/"):
                            continue
                        if not stage_guests:
                            continue
                        relative = name[len("ROM/"):]
                        out.writestr(app_prefix + "Frameworks/" + relative, rom.read(name))
                        staged += 1

                # 占位文件，保证目录一定被创建（zip 里的空目录未必被解出）
                out.writestr(app_prefix + "Frameworks/Application/.keep", b"")
                print(f"  Application/ staged: {staged} guest file(s)"
                      f"{'' if stage_guests else ' (dir only; pass --stage-guests to embed apps)'}")

    if not replaced:
        raise SystemExit("error: SuperSlot.dylib was not replaced")

    with zipfile.ZipFile(output) as check:
        if check.read(target) != replacement:
            raise SystemExit("error: verification failed, baked dylib bytes differ")

    print(f"baked  {output}  ({os.path.getsize(output):,} bytes, {written} entries)")
    print(f"  replaced {target} with {dylib_path} ({len(replacement):,} bytes)")
    print(f"  official backup: {'kept' if keep_official else 'stripped'}")
    if not keep_official:
        print(f"  stripped {OFFICIAL_BACKUP}")
    if strips:
        print(f"  stripped {len(strips)} extra path(s), ~{saved:,} bytes uncompressed")
    if rom_path:
        print(f"  rom.zip embedded as {app_prefix}BakedROM.zip")
    print()
    print("Next: install with AltStore / Sideloadly (dev cert, keep get-task-allow) or TrollStore.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ipa", required=True)
    parser.add_argument("--dylib", default="main")
    parser.add_argument("--rom", default=None)
    parser.add_argument("-o", "--output", default="Nyxian-baked.ipa")
    parser.add_argument("--keep-official", dest="keep_official", action="store_true", default=True)
    parser.add_argument("--strip-official", dest="keep_official", action="store_false")
    parser.add_argument("--strip", action="append", default=[], metavar="PATH")
    parser.add_argument("--stage-guests", dest="stage_guests", action="store_true",
                        help="embed ROM Application/*.app next to the dylib (needs signing)")
    parser.add_argument("--report", action="store_true")
    args = parser.parse_args()

    if not os.path.isfile(args.ipa):
        raise SystemExit(f"error: {args.ipa} not found")

    if args.report:
        report(args.ipa)
        return

    if not os.path.isfile(args.dylib):
        raise SystemExit(f"error: {args.dylib} not found")

    bake(args.ipa, args.dylib, args.rom, args.output, args.keep_official, args.strip,
         args.stage_guests)


if __name__ == "__main__":
    main()
