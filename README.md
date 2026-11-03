[builder-repo-README.md](https://github.com/user-attachments/files/34303267/builder-repo-README.md)
# nyxian-rom-builder

用于从公开源码构建 Nyxian 及其自建 ROM 槽的持续集成仓库。

本仓库不保存 Nyxian 源码。工作流运行时克隆 [emexlab/Nyxian](https://github.com/emexlab/Nyxian) 到指定提交，调用本仓库内 `NyxianROM/` 的构建脚本，产出可直接安装的 IPA 与槽安装包。

---

## 1. 产物

一次成功运行产出三个文件，位于该次运行的 Artifacts 中（保留 14 天）：

| 文件 | 内容 | 用途 |
| --- | --- | --- |
| `Nyxian.ipa` | 官方界面，未签名 | 安装后需先刷入 `rom.zip` 才能进入自建系统 |
| `rom.zip` | ROM 槽安装包，含 `manifest.plist`、槽动态库、应用与 kext | 在宿主 Recovery 中刷机使用 |
| `Nyxian-baked.ipa` | 槽已写入内置槽位置的宿主程序，未签名 | 安装后直接进入自建系统，无需刷机 |

两个 IPA 均为未签名产物，安装前需使用开发证书重新签名。

---

## 2. 目录

```
.
├── .github/workflows/build-ipa.yml   构建工作流
└── NyxianROM/                        ROM 工程与工具（含单独的 README）
```

`NyxianROM/` 的工程结构、ROM 包格式、刷机流程与故障排查见 [NyxianROM/README.md](NyxianROM/README.md)。

---

## 3. 运行方式

1. 进入仓库的 Actions 页面，选择左侧 `build-ipa`；
2. 点击 `Run workflow`；
3. 可选参数 `nyxian_ref` 指定要构建的 Nyxian 提交或标签，默认 `0d573db99dca`；
4. 运行结束后在页面底部下载 Artifacts。

工作流仅通过手动触发（`workflow_dispatch`）。同一分支同时只允许一次有效运行，重复触发会取消较早的运行，被取消的运行不写入缓存。

---

## 4. 工作流结构

| Job | 职责 |
| --- | --- |
| `llvm` | 编译 `LLVM-On-iOS` 子模块，产出 `Frameworks/CoreCompiler/CoreCompilerSupportLibs`，写入缓存 |
| `app` | 读取缓存，构建 Nyxian 与 ROM，生成 `Nyxian-baked.ipa`，上传产物 |

缓存键为 `LLVM-On-iOS` 子模块的提交哈希。首次运行需完整编译 Swift/LLVM 工具链，耗时以小时计；子模块提交不变时，后续运行仅需构建宿主程序，约十余分钟。

运行环境为 `xcode-27` 镜像（macOS 27，Xcode 27.1，含 iOS 27.x SDK）。公开仓库的标准 macOS runner 不产生费用，单个 job 上限 6 小时，工作流内设置为 350 分钟。

---

## 5. 产物使用

安装与刷机步骤见 `NyxianROM/README.md` 第 8、9 节。以下为三项前置条件：

1. 宿主程序必须使用包含 `get-task-allow` 的开发描述文件签名，否则 `LiveProcess` 扩展无法启动；
2. 使用 `rom.zip` 前，需在宿主的设置中导入签名证书，刷机过程依赖该证书重新签名槽内文件；
3. 未签名 IPA 可通过 Sideloadly、AltStore 或 TrollStore 安装；TrollStore 通常不授予 `get-task-allow`，自建系统可显示，但 guest 进程无法启动。

---

## 6. 约束与已知问题

| 项目 | 说明 |
| --- | --- |
| 单 job 时限 | 6 小时。首次构建若接近该上限，可改用 `xcode-27-xlarge`（计费） |
| 磁盘容量 | 标准 macOS runner 空间有限，LLVM 全量编译可能触及上限 |
| `xcode-27` 为预览镜像 | 可能出现排队；不可用时需临时改用 `macos-26`，但该镜像仅含 iOS 26 SDK |
| 缓存写入条件 | 仅在 job 正常结束时保存；运行被取消或失败不会生成缓存 |
| Homebrew 包名 | 镜像更新可能导致 `dpkg`、`openssl` 等包名变动，安装失败时不影响已有依赖 |

---

## 7. 故障排查

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `The operation was canceled.` | 并发触发或手动取消；较早的运行被终止 | 单次只触发一次；确认 `cancel-in-progress` 为 `false` |
| `No space left on device` | 磁盘不足 | 改用 xlarge runner，或在本地构建 LLVM 后缓存 |
| `LLVM 缓存没命中` | `llvm` job 失败或未保存缓存 | 重跑；必要时将两个 job 合并 |
| `failed to sign ...` | 宿主未导入证书 | 在设置中导入签名证书后重新刷机 |
| Artifacts 为空 | `app` job 在收集步骤前失败 | 查看该 job 日志定位失败步骤 |
| `Could not resolve host` | 临时网络故障 | 重新运行 |

---

## 8. 维护

- 升级 Nyxian：修改 `nyxian_ref` 默认值，或运行时传入新提交；
- 更新 ROM 内容：替换 `NyxianROM/` 目录，工作流无需改动；
- 修改构建参数：编辑 `.github/workflows/build-ipa.yml`。

---

## 9. 许可

Nyxian 及其 `LindChain` 源码采用 emexLabs Public Source License 1.1（EPSL 1.1），使用与再分发前请阅读上游仓库的许可条款。本仓库仅包含构建配置与 `NyxianROM/` 工程文件。
