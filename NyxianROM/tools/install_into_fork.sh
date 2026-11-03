#!/bin/sh
# install_into_fork.sh — macOS/Linux 的薄包装，实际逻辑在 install_into_fork.py
#
#   ./tools/install_into_fork.sh /path/to/Nyxian-fork
#   ./tools/install_into_fork.sh /path/to/fork --dry-run
#
# Windows 上直接跑：python tools\install_into_fork.py <fork>

set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$HERE/install_into_fork.py" "$@"
