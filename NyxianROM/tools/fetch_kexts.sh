#!/bin/sh
# fetch_kexts.sh — 把上游的示例 kext 源码拉到 kexts/upstream/
#
#   ./tools/fetch_kexts.sh                # 全部
#   ./tools/fetch_kexts.sh KRW NyxianMount
#
# 上游仓库 KEXTs/*.zip 是 Nyxian 的"工程模板"：UUID 目录 + Main.c/m + Config/Project.plist。
# 这里把它摊平成 kexts/upstream/<Name>/Main.*，并从 EXPORT_KSURFACE_MODULE 里抠出 identifier，
# 生成 kext.plist 给 Makefile 用。

set -eu

REPO="https://raw.githubusercontent.com/emexlab/Nyxian/main/KEXTs"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="$ROOT/kexts/upstream"

DEFAULT="BaseEntitlementLoader BasePreferenceLoader ColorWinMix CrashReporter KRW NyxianMount RelHomeMount SharedTheme TestTweak UISingleFlight"

if [ "$#" -gt 0 ]; then
    NAMES="$*"
else
    NAMES="$DEFAULT"
fi

mkdir -p "$OUT"

for name in $NAMES; do
    work="$(mktemp -d)"
    zip="$work/$name.zip"

    echo ">> $name"
    if ! curl -fsSL "$REPO/$name.zip" -o "$zip"; then
        echo "   skip: download failed" >&2
        rm -rf "$work"
        continue
    fi

    unzip -q "$zip" -d "$work/x"
    inner="$(find "$work/x" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    if [ -z "$inner" ]; then
        echo "   skip: unexpected archive layout" >&2
        rm -rf "$work"
        continue
    fi

    dest="$OUT/$name"
    rm -rf "$dest"
    mkdir -p "$dest"
    # 只要源码，Config/Project.plist 是 IDE 工程设置
    find "$inner" -maxdepth 1 -type f \( -name '*.c' -o -name '*.m' -o -name '*.h' \) -exec cp {} "$dest/" \;

    identifier="$(sed -n 's/.*\.identifier *= *"\([^"]*\)".*/\1/p' "$dest"/Main.* 2>/dev/null | head -n 1)"
    if [ -z "$identifier" ]; then
        identifier="org.example.rom.$(echo "$name" | tr '[:upper:]' '[:lower:]')"
        echo "   warning: no identifier found, using $identifier" >&2
    fi

    cat > "$dest/kext.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NXKextIdentifier</key><string>$identifier</string>
    <key>NXKextVersion</key><string>1.0.0</string>
    <key>NXKextDisplayName</key><string>$name</string>
    <key>CFBundleExecutable</key><string>$name</string>
    <key>NXKextUpstream</key><true/>
</dict>
</plist>
EOF

    echo "   $identifier -> kexts/upstream/$name"
    rm -rf "$work"
done

echo ">> done. 编译：make kexts"
