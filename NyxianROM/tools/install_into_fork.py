#!/usr/bin/env python3
"""
install_into_fork.py - 把 NyxianROM 装进你的 Nyxian fork

用法:
    python3 tools/install_into_fork.py /path/to/Nyxian-fork
    python3 tools/install_into_fork.py /path/to/fork --dry-run
    python3 tools/install_into_fork.py /path/to/fork --no-workflow
    python3 tools/install_into_fork.py /path/to/fork --subtree   # 打印 git subtree 命令

做的事:
    1. 把 NyxianROM/ 整个目录复制到 <fork>/NyxianROM（覆盖旧目录，清掉构建残留）
    2. 把 ci/build-ipa.yml 复制到 <fork>/.github/workflows/build-ipa.yml
    3. 给 shell 脚本补可执行位（Windows 拷过去会丢）
    4. 打印还差什么
"""

import argparse
import os
import shutil
import stat
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JUNK = [".work", "build", "kexts-bin", ".stage", ".rompkg", ".modules",
        "__pycache__", "tools/__pycache__", "Application", "rom.zip", "main"]


def copy_tree(source, target):
    if os.path.exists(target):
        shutil.rmtree(target)
    os.makedirs(target)
    for dirpath, dirs, files in os.walk(source):
        dirs[:] = [d for d in dirs if d not in ("__pycache__", ".git")]
        rel = os.path.relpath(dirpath, source)
        if rel.split(os.sep)[0] in JUNK:
            dirs[:] = []
            continue
        destination = target if rel == "." else os.path.join(target, rel)
        os.makedirs(destination, exist_ok=True)
        for name in files:
            if name in JUNK:
                continue
            shutil.copy2(os.path.join(dirpath, name), os.path.join(destination, name))


def chmod_x(path):
    try:
        mode = os.stat(path).st_mode
        os.chmod(path, mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    except OSError:
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("fork", help="Nyxian fork 的本地路径（用 --subtree 时改成 NyxianROM 仓库地址）")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-workflow", action="store_true")
    parser.add_argument("--subtree", action="store_true",
                        help="只打印 git subtree 命令，不复制文件")
    args = parser.parse_args()

    fork = os.path.abspath(args.fork)

    if args.subtree:
        print("在你的 Nyxian fork 里（假设 NyxianROM 已经是独立仓库）：")
        print(f"  git subtree add --prefix=NyxianROM {args.fork} main --squash")
        print("  mkdir -p .github/workflows")
        print("  cp NyxianROM/ci/build-ipa.yml .github/workflows/build-ipa.yml")
        print("  git add NyxianROM .github/workflows/build-ipa.yml && git commit -m 'add NyxianROM'")
        return

    if not os.path.isdir(fork):
        raise SystemExit(f"error: {fork} is not a directory")

    has_nxromgen = os.path.isfile(os.path.join(fork, "nxromgen.sh"))
    has_xcodeproj = os.path.isdir(os.path.join(fork, "Nyxian.xcodeproj"))

    print(f">> source : {HERE}")
    print(f">> fork   : {fork}")
    if not has_nxromgen:
        print("   warning: 这里没有 nxromgen.sh，确认一下是不是 Nyxian 仓库", file=sys.stderr)
    if not has_xcodeproj:
        print("   warning: 这里没有 Nyxian.xcodeproj", file=sys.stderr)

    target = os.path.join(fork, "NyxianROM")

    if args.dry_run:
        print(f"   [dry-run] copy {HERE} -> {target}")
        if not args.no_workflow:
            print(f"   [dry-run] copy {HERE}/ci/build-ipa.yml -> {fork}/.github/workflows/build-ipa.yml")
        print("   [dry-run] chmod +x build.sh tools/*.sh tools/*.py")
        return

    print(">> copying NyxianROM/")
    copy_tree(HERE, target)

    for junk in JUNK:
        path = os.path.join(target, junk)
        if os.path.isdir(path):
            shutil.rmtree(path, ignore_errors=True)
        elif os.path.isfile(path):
            os.remove(path)

    if not args.no_workflow:
        print(">> installing workflow")
        workflows = os.path.join(fork, ".github", "workflows")
        os.makedirs(workflows, exist_ok=True)
        shutil.copy2(os.path.join(HERE, "ci", "build-ipa.yml"),
                     os.path.join(workflows, "build-ipa.yml"))

    print(">> fixing exec bits")
    for relative in ("build.sh", "tools/fetch_kexts.sh", "tools/install_into_fork.sh"):
        path = os.path.join(target, relative)
        if os.path.isfile(path):
            chmod_x(path)
    for name in os.listdir(os.path.join(target, "tools")):
        if name.endswith(".py"):
            chmod_x(os.path.join(target, "tools", name))

    files = sum(len(f) for _, _, f in os.walk(target))
    print(f">> NyxianROM/ installed: {files} files")
    print()
    print("done. 下一步：")
    print(f"  cd {fork}")
    print("  git add NyxianROM .github/workflows/build-ipa.yml")
    print("  git commit -m 'add NyxianROM + CI'")
    print("  git push")
    print()
    print("然后在 GitHub：Actions -> build-ipa -> Run workflow（仓库保持 public）")


if __name__ == "__main__":
    main()
