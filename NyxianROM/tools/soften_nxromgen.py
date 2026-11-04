#!/usr/bin/env python3
"""Copy nxromgen.sh with its hard anchor failures downgraded to warnings.

Upstream nxromgen.sh patches Nyxian sources by matching exact strings. When
main drifts, an anchor disappears and the generator aborts with

    raise SystemExit('... marker not found')

A ROM missing one optional patch still boots; a ROM that was never generated
does not. So every anchor failure becomes a warning, and for the guest-application
mount we additionally dump candidate lines, which tells us the new anchor to use.

Usage: soften_nxromgen.py <nxromgen.sh> <output.sh>
"""

import re
import sys

ROOT_MOUNT_OLD = """    marker = '        /* root mounts */\\n'
    if marker not in s:
        raise SystemExit('root mounts marker not found')
    s = s.replace(marker, mount_entry + marker, 1)"""

ROOT_MOUNT_NEW = """    marker = '        /* root mounts */\\n'
    if marker not in s:
        print('nxromgen: WARNING: root mounts marker not found; skipping guest app mount')
        for _i, _l in enumerate(s.split('\\n')):
            if 'kFSMount' in _l or 'root mount' in _l.lower():
                print('   candidate %d: %s' % (_i, _l[:160]))
        marker = ''
    if marker:
        s = s.replace(marker, mount_entry + marker, 1)"""


def main(source, destination):
    text = open(source, encoding="utf-8").read()

    if ROOT_MOUNT_OLD in text:
        text = text.replace(ROOT_MOUNT_OLD, ROOT_MOUNT_NEW, 1)
    else:
        print("warning: root-mount block not recognised, only generic softening applied")

    def replace(match):
        return "print('nxromgen: WARNING: skipped anchor: %s')" % match.group(1)

    text, count = re.subn(r"raise SystemExit\('([^']*)'\)", replace, text)

    open(destination, "w", encoding="utf-8").write(text)
    print("softened %d anchor failure(s) -> %s" % (count, destination))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: soften_nxromgen.py <nxromgen.sh> <output.sh>")
    main(sys.argv[1], sys.argv[2])
