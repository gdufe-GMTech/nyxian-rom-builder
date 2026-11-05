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

if [ ! -f "$NYXIAN_SRC/nxromgen.sh" ]; then
    echo "error: $NYXIAN_SRC/nxromgen.sh not found" >&2
    exit 1
fi

echo ">> nxromgen: $NYXIAN_SRC -> $WORK"
rm -rf "$WORK"
mkdir -p "$WORK"

# 上游 nxromgen 用精确字符串定位补丁点，main 一漂移锚点就消失并直接中止。
# 这里跑一份"锚点缺失只告警"的副本，保证 ROM 始终能生成；缺哪个补丁会在日志里写明。
# 副本必须放在 $WORK 之外，因为 nxromgen 第 32 行会 rm -rf "$OUT"。
GEN="${TMPDIR:-/tmp}/nxromgen-$$.sh"
trap 'rm -f "$GEN"' EXIT
python3 "$HERE/tools/soften_nxromgen.py" "$NYXIAN_SRC/nxromgen.sh" "$GEN"
chmod +x "$GEN"
"$GEN" "$NYXIAN_SRC" "$WORK"
rm -f "$GEN"

echo ">> overlay NXROM shell sources"
cp -R "$HERE/overlay/." "$WORK/"

echo ">> install Makefile + apps + tools"
cp "$HERE/Makefile" "$WORK/Makefile"
mkdir -p "$WORK/appsrc" "$WORK/tools" "$WORK/kexts"
cp -R "$HERE/appsrc/." "$WORK/appsrc/"
cp -R "$HERE/kexts/." "$WORK/kexts/"
# 必须带 -R：BSD 的 cp 复制目录内容需要它，缺了会报 "is a directory"，
# 而 Makefile 里的 python3 tools/mkkext.py 找不到脚本就整颗 kext 编不出来。
cp -R "$HERE/tools/." "$WORK/tools/"
rm -rf "$WORK/tools/__pycache__"
test -f "$WORK/tools/mkkext.py" || { echo "error: tools/mkkext.py missing in $WORK" >&2; exit 1; }

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
