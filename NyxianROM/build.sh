#!/bin/sh
# build.sh — 从 Nyxian 源码生成 ROM 工程并打包
#
#   ./build.sh /path/to/Nyxian
#
# 需要：macOS 或 Linux（nxromgen.sh 是 POSIX sh + python3），以及 Xcode 的 iOS SDK。
# 如果只想在设备上编（用 Nyxian 自带的 clang），先跑 `./build.sh /path/to/Nyxian --scaffold`
# 生成工程，再把 rom/src 拷进 Nyxian 的工程里编译，最后用 tools/mkrom.py 打包。

set -eu

NYXIAN_SRC="${1:?usage: ./build.sh /path/to/Nyxian [--scaffold]}"
MODE="${2:-build}"

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HERE/.work"

if [ ! -x "$NYXIAN_SRC/nxromgen.sh" ]; then
    echo "error: $NYXIAN_SRC/nxromgen.sh not found or not executable" >&2
    exit 1
fi

echo ">> nxromgen: $NYXIAN_SRC -> $WORK"
rm -rf "$WORK"
mkdir -p "$WORK"
"$NYXIAN_SRC/nxromgen.sh" "$NYXIAN_SRC" "$WORK"

echo ">> overlay NXROM shell sources"
cp -R "$HERE/overlay/." "$WORK/"

echo ">> install Makefile + apps + tools"
cp "$HERE/Makefile" "$WORK/Makefile"
mkdir -p "$WORK/appsrc" "$WORK/tools" "$WORK/kexts"
cp -R "$HERE/appsrc/." "$WORK/appsrc/"
cp -R "$HERE/kexts/." "$WORK/kexts/"
cp "$HERE/tools/." "$WORK/tools/" 2>/dev/null || true

if [ "$MODE" = "--scaffold" ]; then
    echo ">> scaffold only: sources ready at $WORK"
    exit 0
fi

cd "$WORK"
make clean >/dev/null 2>&1 || true
# 上游示例 kext 会 #import <UI/...>，所以要能找到原仓库的 Nyxian/ 目录
make NX_EXTRA_INC="-I$NYXIAN_SRC/Nyxian"

cp rom.zip "$HERE/rom.zip"

if [ "$MODE" = "--ipa" ]; then
    if [ ! -f "$NYXIAN_SRC/Nyxian.ipa" ]; then
        echo "error: $NYXIAN_SRC/Nyxian.ipa not found (run make in the Nyxian checkout first)" >&2
        exit 1
    fi
    STRIP=""
    if [ "${NXROM_STRIP_OFFICIAL:-0}" = "1" ]; then
        STRIP="--strip-official"
    fi
    python3 "$HERE/tools/bake_ipa.py" \
        --ipa "$NYXIAN_SRC/Nyxian.ipa" \
        --dylib "$WORK/main" \
        --rom "$WORK/rom.zip" \
        $STRIP \
        -o "$HERE/Nyxian-baked.ipa"
    echo ">> baked ipa: $HERE/Nyxian-baked.ipa"
fi

echo ">> done: $HERE/rom.zip"
echo ">> next: Recovery -> Flash ROM。刷机前先在 Nyxian 里导入签名证书，否则会卡在 failed to sign main"
