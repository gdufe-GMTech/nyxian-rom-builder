#!/bin/bash
# bootstrap-mac.sh - build Nyxian + NyxianROM on a fresh Mac (1-2 hours)
#
# Usage on the rented Mac:
#   curl -fsSL https://raw.githubusercontent.com/gdufe-GMTech/nyxian-rom-builder/main/bootstrap-mac.sh | bash
#
# Artifacts land in $HOME/nyxian-build/builder/NyxianROM/ :
#   Nyxian.ipa        stock UI (needs a ROM flash)
#   rom.zip           ROM slot package
#   Nyxian-baked.ipa  boots straight into the ROM
#
# Override with env vars:
#   NYXIAN_REF=<commit>  BUILD_ROOT=<dir>

set -euo pipefail

NYXIAN_REPO="${NYXIAN_REPO:-https://github.com/emexlab/Nyxian.git}"
NYXIAN_REF="${NYXIAN_REF:-0d573db99dca}"
BUILDER_REPO="${BUILDER_REPO:-https://github.com/gdufe-GMTech/nyxian-rom-builder.git}"
BUILD_ROOT="${BUILD_ROOT:-$HOME/nyxian-build}"

step() { printf "\n==> %s\n" "$1"; }

step "checking Xcode"
if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "error: xcodebuild not found. Install Xcode from the App Store first." >&2
    exit 1
fi
xcodebuild -version
echo "--- iOS SDKs ---"
xcodebuild -showsdks | grep -i iphoneos || {
    echo "error: no iPhoneOS SDK found" >&2
    exit 1
}

step "checking disk space (need ~40 GB free)"
df -h "$HOME" | tail -1

step "installing build dependencies"
if ! command -v brew >/dev/null 2>&1; then
    echo "installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
brew install pkgconf cmake libarchive dpkg openssl ninja || true

step "installing the Metal toolchain (Xcode 26+ splits it out)"
sudo xcodebuild -runFirstLaunch || true
xcodebuild -downloadComponent MetalToolchain || true
xcrun -sdk iphoneos metal --version || true

mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

step "cloning Nyxian ($NYXIAN_REF)"
if [ ! -d Nyxian/.git ]; then
    git clone --filter=blob:none "$NYXIAN_REPO" Nyxian
fi
cd Nyxian
git fetch --all --tags --quiet || true
git checkout "$NYXIAN_REF"
git submodule update --init --recursive

step "building Nyxian.ipa (this is the long part: 1-2 hours)"
make CHECK_DEPS=0

step "building the ROM and baking the ipa"
cd "$BUILD_ROOT"
if [ ! -d builder/.git ]; then
    git clone "$BUILDER_REPO" builder
fi
cd builder/NyxianROM
chmod +x build.sh tools/*.sh
./build.sh "$BUILD_ROOT/Nyxian" --ipa

step "done"
ls -lh "$BUILD_ROOT"/builder/NyxianROM/rom.zip \
       "$BUILD_ROOT"/builder/NyxianROM/Nyxian-baked.ipa 2>/dev/null || true
cat <<EOF

Artifacts:
  $BUILD_ROOT/Nyxian/Nyxian.ipa
  $BUILD_ROOT/builder/NyxianROM/rom.zip
  $BUILD_ROOT/builder/NyxianROM/Nyxian-baked.ipa

Copy them off the machine with, for example:
  scp <user>@<host>:$BUILD_ROOT/builder/NyxianROM/Nyxian-baked.ipa .
EOF
