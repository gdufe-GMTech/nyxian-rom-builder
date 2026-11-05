#!/usr/bin/env python3
"""Copy nxromgen.sh, adapting it to upstream drift and downgrading hard failures.

Upstream nxromgen.sh patches Nyxian sources by matching exact strings. When main
drifts, an anchor disappears and the generator aborts with

    raise SystemExit('... marker not found')

Three adjustments, applied in order:

1. The sandbox registry call gained two entitlement parameters upstream
   (4 args -> 6 args). Rewrite the injected call so it still compiles.
2. The root-mount table became individual ksurface_fs_init_mount3() calls, so
   the old "/* root mounts */" marker is gone. Insert the ROM Application mount
   next to the bootfs mount instead, which is where the old table started.
3. Any anchor that is still missing only warns: a ROM without one optional
   patch still boots, a ROM that was never generated does not.

Usage: soften_nxromgen.py <nxromgen.sh> <output.sh>
"""

import re
import sys

# ---------------------------------------------------------------- 1. 4 -> 6 args
SANDBOX_CALL_OLD = """    kr = ksurface_fs_sandbox_registry_add(kFSMountPermissionRead,
                                          kFSNodeTypeDirectory,
                                          romApplicationSource.fileSystemRepresentation,
                                          NULL);"""

SANDBOX_CALL_NEW = """    kr = ksurface_fs_sandbox_registry_add(kFSMountPermissionRead,
                                          kFSNodeTypeDirectory,
                                          romApplicationSource.fileSystemRepresentation,
                                          NULL,
                                          NULL,
                                          NULL);"""

# ------------------------------------------------- 2. mount table -> mount3 call
ROOT_MOUNT_OLD = """    marker = '        /* root mounts */\\n'
    if marker not in s:
        raise SystemExit('root mounts marker not found')
    s = s.replace(marker, mount_entry + marker, 1)"""

ROOT_MOUNT_NEW = """    marker = '        /* root mounts */\\n'
    if marker in s:
        s = s.replace(marker, mount_entry + marker, 1)
    else:
        # Upstream replaced the mount table with individual init_mount3() calls.
        anchor = '    ksurface_fs_init_mount3(kFSMountAttrRead, "$mnt/bootfs", "$vroot/boot");\\n'
        if anchor in s:
            entry = ('    ksurface_fs_init_mount3(kFSMountAttrRead,'
                     ' romApplicationSource.fileSystemRepresentation,'
                     ' rootApplicationMount.fileSystemRepresentation);\\n')
            s = s.replace(anchor, anchor + entry, 1)
        else:
            print('nxromgen: WARNING: no anchor for the ROM Application mount; guests stay hidden')
            for _i, _l in enumerate(s.split('\\n')):
                if 'ksurface_fs_init_mount3' in _l:
                    print('   candidate %d: %s' % (_i, _l[:160]))"""


def main(source, destination):
    text = open(source, encoding="utf-8").read()

    if SANDBOX_CALL_OLD in text:
        text = text.replace(SANDBOX_CALL_OLD, SANDBOX_CALL_NEW, 1)
        print("sandbox registry call: 4 args -> 6 args")
    else:
        print("warning: sandbox registry call not recognised (already 6 args?)")

    if ROOT_MOUNT_OLD in text:
        text = text.replace(ROOT_MOUNT_OLD, ROOT_MOUNT_NEW, 1)
        print("root mount: falling back to the init_mount3 anchor")
    else:
        print("warning: root-mount block not recognised")

    def replace(match):
        return "print('nxromgen: WARNING: skipped anchor: %s')" % match.group(1)

    text, count = re.subn(r"raise SystemExit\('([^']*)'\)", replace, text)

    open(destination, "w", encoding="utf-8").write(text)
    print("softened %d anchor failure(s) -> %s" % (count, destination))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: soften_nxromgen.py <nxromgen.sh> <output.sh>")
    main(sys.argv[1], sys.argv[2])
