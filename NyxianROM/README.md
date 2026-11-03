[README.md](https://github.com/user-attachments/files/34303236/README.md)
# NyxianROM

为 Nyxian 构建可替换的用户空间系统槽（ROM slot），并提供配套的打包、签名、刷机与校验工具。

本工程不修改 Nyxian 宿主程序的源码，全部功能通过官方槽接口（`NXSlotMain` 等）与公开刷机流程实现。

---

## 1. 概述

Nyxian 的引导器在启动时选择一个"槽"作为系统入口。槽是一组放在 `Library/Boot/Slot/<A|B>` 目录下的文件，由引导器通过 `dlopen` 加载其中的动态库，并调用其导出的入口函数。本工程提供一个最小可用的槽实现，包含桌面、设置、应用启动器与内核扩展加载，以及生成该槽安装包（`rom.zip`）和直接烧录进宿主 IPA 的工具链。

### 1.1 能力范围

| 目标 | 支持 | 说明 |
| --- | --- | --- |
| 运行自建图形应用 | 是 | 通过 `PEProcessManager` 与本工程的应用注册表启动 |
| 自建桌面、启动器、设置 | 是 | 本工程实现 |
| 扩展运行时（kext） | 是 | 通过 `PEKext` 加载，需要签名与 NXT2 信任块 |
| 更多命令行工具 | 是 | 以 arm64 Mach-O 形式放入 rootfs |
| 运行 Apple 系统应用（设置、SpringBoard、Safari 等） | 否 | 依赖真实 launchd、backboardd、cfprefsd、securityd、IOKit 与平台签名 |
| 整机模拟（Android、旧版 iOS） | 否 | 无 JIT 与 hypervisor 支持 |

Nyxian 仅模拟系统调用层，不模拟内核对象与驱动，因此"环境完整性"的上限由该模拟层决定。

### 1.2 与官方版本的关系

本工程基于公开源码构建。官方发布版 0.11.6.1 在引导器中加入了 ROM 发布签名与 TrustStore 校验，自建 ROM 无法通过该校验。本工程使用公开 `main` 分支，该分支具备完整槽系统，且不包含上述校验。

---

## 2. 术语

| 术语 | 含义 |
| --- | --- |
| 槽（slot） | 引导器加载的系统入口，位于 `Library/Boot/Slot/A` 或 `B` |
| 引导器（bootloader） | Nyxian 主程序中负责选择并加载槽的组件 |
| 内置槽 | `Frameworks/SuperSlot.dylib`，未刷入任何槽时的回退入口 |
| 刷机（flash） | 将 ROM 压缩包解压到槽目录并完成签名、封印的过程 |
| ksurface | Nyxian 的用户空间内核实现，提供进程、权限、文件系统与 IPC 模拟 |
| NXT2 | Nyxian 自定义的权限块（entitlement blob），附加在 Mach-O 之后 |
| LiveProcess | 承载 guest 进程的应用扩展（`PlugIns/LiveProcess.appex`） |

---

## 3. 版本前提

公开仓库的版本情况如下（核对自 GitHub 文件树）：

| 引用 | 槽系统 | ROM 发布签名 / TrustStore |
| --- | --- | --- |
| `0.11.4`（最新 tag） | 无 | 无 |
| `20251113a` / `20251122a` / `20251128a` | 无 | 无 |
| `main` @ `0d573db99dca`（2026-10-31） | 有 | 无 |
| `0.11.6.1`（官方发布 IPA） | 有 | 有 |

`0.11.4` 及更早的 tag 不包含 `BootViewController.swift`、`SlotEntry.swift`、`nxromgen.sh` 与 Recovery 界面，因此无法承载 ROM。本工程以 `main` @ `0d573db99dca` 为基准版本，该版本提供完整槽系统且不对 ROM 做发布签名校验，仅校验 `manifest.plist` 与 `NXRomMinimumNyxianVersion`。

---

## 4. 系统结构

### 4.1 槽加载逻辑

引导器按以下顺序确定系统入口（对应 `BootViewController.swift` 中 `loadSlot()`）：

1. 若活动槽存在 `manifest.plist`，读取其中的 `NXRomExecutable`，加载槽内对应文件；
2. 否则加载 `Frameworks/SuperSlot.dylib`；
3. 两者均不存在时进入 Recovery。

加载成功后，引导器依次解析并调用：

```c
void *NXSlotMain(void);                  /* 必需，返回 UIViewController 的持有指针 */
void *NXSlotCreateWindow(void *scene);   /* 可选，UIWindowScene* -> NXWindowServer* */
void  NXSlotDidAppear(void);             /* 可选，界面呈现后回调 */
```

`NXSlotMain` 在主线程同步调用，必须尽快返回。

### 4.2 引导时序

顺序不可调整，否则会触发 `trust_enforcement` 与 `klog` 的单次初始化断言：

```
trust_enforcement_set_mode
  -> klog_set_obfuscation
  -> （可选）NXBootstrap
  -> PEUserspaceManager bootWithKextLoadingEnabled
  -> 加载 ROM 自带 kext
  -> 返回根视图控制器
```

---

## 5. 目录结构

```
NyxianROM/
├── build.sh                   一键构建：nxromgen -> overlay -> make -> rom.zip
├── Makefile                   构建 main 动态库、应用与 kext
├── overlay/rom/src/
│   ├── NXMainSlot.m           槽入口与 kext 加载
│   └── NXROM/                 桌面、设置、应用注册表、系统信息
├── appsrc/                    guest 应用示例（Hello、Files）
├── kexts/                     内核扩展源码与说明
├── ci/                        GitHub Actions 与 Codemagic 配置
└── tools/
    ├── mkrom.py               生成 rom.zip 与 manifest.plist
    ├── mkkext.py              生成 .kext 包
    ├── fetch_kexts.sh         获取上游示例 kext 源码
    ├── bake_ipa.py            将槽写入宿主 IPA
    ├── verify_rom.py          刷机前校验
    ├── deps.py                查看 Mach-O 依赖
    └── install_into_fork.py   将本工程并入 Nyxian fork
```

---

## 6. 构建

### 6.1 环境要求

- macOS 与完整 Xcode（非 Command Line Tools）；工程使用 `#available(iOS 26.0, *)`，需含 iOS 26/27 SDK 的 Xcode
- Homebrew 依赖：`pkgconf cmake libarchive dpkg openssl ninja`
- Theos（`Makefile` 会将 `$(THEOS)/bin` 加入 `PATH`）

### 6.2 获取源码

```bash
git clone https://github.com/emexlab/Nyxian.git
cd Nyxian
git checkout 0d573db99dca
git submodule update --init --recursive
```

`LLVM-On-iOS` 子模块体积较大，构建 `CoreCompiler` 时会在本地编译 Swift/LLVM 工具链，耗时以小时计。

### 6.3 构建宿主程序

```bash
make            # 等价于 make clean check compile package-app clean
```

产物为未签名的 `Nyxian.ipa`。首次构建会先行编译 `LLVM-On-iOS`，后续构建复用 `Frameworks/CoreCompiler/CoreCompilerSupportLibs`。

若使用 Xcode 直接运行，可在 `Signing & Capabilities` 中指定开发团队并修改 Bundle Identifier，`LiveProcess` 扩展需使用同一团队签名。

### 6.4 构建 ROM

```bash
cd NyxianROM
./build.sh /path/to/Nyxian
```

产物：

- `rom.zip`：槽安装包
- `Nyxian-baked.ipa`：仅当追加 `--ipa` 且宿主目录存在 `Nyxian.ipa` 时生成

### 6.5 使用 GitHub Actions 构建

无 macOS 环境时，可在 CI 中构建。

- runner：`xcode-27`（macOS 27，Xcode 27.1，含 iOS 27.x SDK）。公开仓库的标准 macOS runner 不产生费用，单 job 上限 6 小时。
- 工作流：`ci/build-ipa-standalone.yml`，该文件会克隆 `emexlab/Nyxian` 并固定到指定 commit，无需 fork 上游仓库。
- 仓库根目录需存在 `.github/workflows/build-ipa.yml`，内容为该文件；`NyxianROM/` 目录需位于仓库根目录。
- 构建分两个 job：`llvm` 负责编译并缓存 LLVM 工具链；`app` 负责构建宿主程序与 ROM。缓存以子模块 commit 为键。
- 工作流仅通过 `workflow_dispatch` 触发。并发执行会导致较早的运行被取消，且取消的运行不会写入缓存。

可选方案：`ci/codemagic.yaml`（Codemagic，`mac_mini_m2` 实例，磁盘容量更大）。

---

## 7. ROM 包格式

### 7.1 压缩包布局

刷机时使用 `unzipArchiveAtPathWithoutParentDirectory()` 解压，该函数会移除每个条目的第一层路径，因此压缩包必须包含一层 `ROM/` 作为包装目录：

```
rom.zip
└── ROM/
    ├── manifest.plist
    ├── main
    ├── Application/
    │   └── Hello.app/{Info.plist, Hello}
    └── kexts/
        └── NXROMHello.kext/{Info.plist, NXROMHello}
```

缺少 `manifest.plist` 时刷机会失败并输出 `failed to extract ROM`。

### 7.2 manifest.plist 字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `NXRomManifestVersion` | 整数 | 当前为 1 |
| `NXRomIdentifier` | 字符串 | ROM 标识 |
| `NXRomName` | 字符串 | 显示名称 |
| `NXRomVersion` | 字符串 | 版本号 |
| `NXRomMinimumNyxianVersion` | 字符串 | 最低宿主版本，`0.0.0` 表示不限制 |
| `NXRomMaximumNyxianVersion` | 字符串 | 可选 |
| `NXRomExecutable` | 字符串 | 槽内可执行文件相对路径，通常为 `main` |
| `NXRomDefaultFilePermission` | 整数 | 默认文件权限，缺省 0644 |
| `NXRomDefaultDirectoryPermission` | 整数 | 默认目录权限，缺省 0755 |
| `NXRomPaths` | 数组 | 需要指定权限或重新签名的文件 |
| `NXRomInstaller` / `NXRomUninstaller` | 字符串 | 可选，安装/卸载时执行的槽内脚本 |
| `NXRomBootLogo` | 字典 | 可选，开机图标（`Light` / `Dark`） |

`NXRomPaths` 元素字段：

```xml
<dict>
  <key>NXPath</key><string>main</string>
  <key>NXRequiresCodeSigning</key><true/>
  <key>NXT2Entitlements</key><dict/>
</dict>
```

`NXRequiresCodeSigning` 为真时，刷机过程调用 `NXSignMachOAuto()` 重新签名并刷新 vnode。`NXT2Entitlements` 键存在时，额外调用 `trust_nxt2_sign()`；空字典同样触发签名，但不附加额外权限。

### 7.3 打包工具

```bash
python3 tools/mkrom.py <staging> -o rom.zip \
    --identifier org.example.nyxrom \
    --name NyxROM --version 0.1.0 --min-nyxian 0.0.0
```

`<staging>` 需包含 `main`，可选包含 `Application/` 与 `kexts/`。工具根据目录内容生成 `manifest.plist` 并完成压缩。

---

## 8. 刷机

1. 在宿主程序的设置中导入签名证书（`.p12` 与描述文件）。刷机过程需要使用该证书重新签名槽内文件，缺失时终止并输出 `failed to sign ...`。
2. 启动 Nyxian 时按住音量键进入 Recovery。两种方向分别对应"强制使用内置槽"与"进入 Recovery"，可通过日志 `bootloader: forcing SuperSlot.dylib` 与 `bootloader: recovery requested` 判断。
3. 选择 `Flash ROM`，选中 `rom.zip`。
4. 日志依次输出解压、签名、刷新 vnode、写入完成。
5. 同时按住两个音量键重启。正常启动时日志为 `bootloader: loading slot <A|B>`。

回滚：Recovery 中选择 `Unflash ROM` 清除槽目录；或在引导时强制使用内置槽。

---

## 9. 制作可直接安装的 IPA

槽在未刷入时由内置槽 `Frameworks/SuperSlot.dylib` 承担系统入口。将该文件替换为本工程的 `main`，安装后即直接进入本工程提供的系统，无需刷机。

```bash
./build.sh /path/to/Nyxian --ipa
```

工具 `tools/bake_ipa.py` 依次执行：

1. 将 `Payload/<App>.app/Frameworks/SuperSlot.dylib` 替换为 `main`；
2. 将原文件另存为 `SuperSlot.official.dylib`（可用 `--strip-official` 省略）；
3. 可选将 `rom.zip` 写入 `BakedROM.zip`；
4. 回读输出包，校验替换后的字节与输入一致。

常用参数：

| 参数 | 说明 |
| --- | --- |
| `--report` | 列出包内占用最大的条目 |
| `--strip-official` | 不保留官方槽备份，减少约 19.8 MB |
| `--strip <path>` | 剔除指定路径，相对 `Payload/<App>.app/`，可重复 |
| `--dylib <path>` | 指定替换用的槽动态库，默认为 `main` |

两种交付物的差异：

| 包 | 启动进入 | 官方界面 | 需要刷机 |
| --- | --- | --- | --- |
| `Nyxian.ipa` | 官方界面 | 保留 | 是 |
| `Nyxian-baked.ipa` | 本工程系统 | 被替换 | 否 |

槽动态库不能单独发布为 IPA：其符号依赖宿主进程中的 ksurface 与 LindChain 实现，不构成独立应用。

---

## 10. 内核扩展

### 10.1 构建与加载

`make kexts` 将 `kexts/<Name>/Main.{c,m}` 编译为 `kexts-bin/<Name>.kext/`，并由 `mkkext.py` 生成 `Info.plist`。`make` 会将其一并写入 `rom.zip`，刷机时按 `NXRomPaths` 重新签名并附加 NXT2 块。启动时 `NXROMLoadROMKexts()` 依次调用 `[[PEKext alloc] initWithPath:]` 与 `[kext load]`，由 ksurface 完成签名校验、映射、符号修正与初始化。

### 10.2 依赖与版本约束

| kext | 依赖 | 说明 |
| --- | --- | --- |
| `NXROMHello` | `ksurface >= 0.11.0` | 本工程自带，用于验证流水线 |
| `NyxianMount` | `ksurface 0.11.5` | 将 `Documents/mntfs/nyxianfs` 挂载至 guest 根目录 |
| `RelHomeMount` | `ksurface` | 相对路径挂载 |
| `KRW` | `ksurface 0.11.4`（精确匹配） | 注册内核读写系统调用；在 0.11.5 上会被拒绝 |
| `TestTweak` | `ksurface 0.11.5`、`BasePreferenceLoader` | 在设置中注册页面 |
| `BasePreferenceLoader` | `ksurface` | 提供 `PreferenceLoaderAppendEntry()` |
| `BaseEntitlementLoader` | `ksurface` | 自定义权限加载 |
| `CrashReporter` | `ksurface` | 崩溃报告；文件较多 |
| `ColorWinMix` / `SharedTheme` / `UISingleFlight` | `ksurface` | 界面相关，需 `Nyxian/UI` 头文件 |

获取上游示例：

```bash
./tools/fetch_kexts.sh                # 全部
./tools/fetch_kexts.sh KRW NyxianMount
```

上游 `KEXTs/*.zip` 为 IDE 工程模板（`Main.c` 与 `Config/Project.plist`），不包含编译产物，需在本工程中编译。

kext 运行于宿主进程地址空间，拥有与宿主相同的权限，不具备沙箱隔离。

---

## 11. 运行时组件

| 组件 | 职责 |
| --- | --- |
| `NXROMHomeViewController` | 桌面：图标网格、Dock、时钟、主机名 |
| `NXROMAppRegistry` | 扫描 `rootfs/Application`、槽内 `Application`、`Cache/Payload`，解析图标并启动应用 |
| `NXROMSystemInfo` | 读取 ksurface 进程表、kext 表与主机名 |
| `NXROMSettingsViewController` | 系统状态、用户空间控制、权限模式、kext 加载状态、内核日志 |
| `NXROMShellViewController` | 容器与设置入口 |

`NXROMSystemInfo` 与 `NXROMAppRegistry` 通过 `dladdr` 定位所在槽目录，不依赖固定路径。

---

## 12. 故障排查

| 现象 / 日志 | 原因 | 处理 |
| --- | --- | --- |
| `failed to extract ROM` | 压缩包缺少 `ROM/` 包装或 `manifest.plist` | 使用 `tools/mkrom.py` 打包 |
| `malformed manifest plist` | 字段缺失或类型错误 | 对照 7.2 节 |
| `failed to sign <path>` | 宿主未导入签名证书 | 在设置中导入证书 |
| `this ROM needs ... this is Nyxian ...` | `NXRomMinimumNyxianVersion` 高于宿主版本 | 设为 `0.0.0` |
| `couldnt load ...` | 架构或文件类型不符 | 使用 arm64 Mach-O，`main` 必须为动态库 |
| `... has no NXSlotMain entry point` | 入口符号未导出 | 检查可见性属性，避免 strip |
| `NXSlotMain returned no view controller` | 根视图控制器初始化失败 | 先返回空白控制器以排除界面问题 |
| `Kext 'x' requires kext 'y'` | 依赖缺失或版本不匹配 | 补全依赖或调整 `KMOD_VERSION` |
| `kext ... load -> 非 0` | 签名或 NXT2 校验失败 | 确认刷机日志包含对应 `signed ...` 记录 |
| 启动仍为官方界面 | 使用未替换槽的 IPA，或槽未刷入 | 检查 `bootloader: forcing SuperSlot.dylib` |

刷机前可使用 `python3 tools/verify_rom.py rom.zip` 校验：入口符号、架构、`manifest.plist` 字段、`NXRomPaths` 与 `Application`、`kexts` 结构。

---

## 13. 已知限制

- 无法运行 Apple 系统应用：缺少真实系统服务、驱动与平台签名。
- 进程数量上限由 ksurface 设定（`PROC_MAX 500`），受 jetsam 约束。
- 无法拦截 `svc` 指令：guest 直接发起系统调用会交由真实内核处理，因此不获得额外权限。
- 构建与运行依赖开发证书：宿主必须以包含 `get-task-allow` 的开发描述文件签名，否则 `LiveProcess` 扩展无法启动。
- 本工程未在 iOS 设备上完成编译验证。已完成的验证为：打包工具与校验工具基于真实 Mach-O 的端到端测试，以及槽符号在官方 `SuperSlot.dylib` 上的确认。

---

## 14. 参考

- [emexlab/Nyxian](https://github.com/emexlab/Nyxian)：`Nyxian/UI/BootViewController.swift`（引导、刷机与 `ROMManifest`）、`Nyxian/UI/SlotEntry.swift`（槽接口实现）、`Nyxian/LindChain/Utils/Zip.m`（解压实现）、`Makefile`
- [actions/runner-images#14404](https://github.com/actions/runner-images/issues/14404)：`xcode-27` runner 镜像说明
- 仓库内 `Nyxian-技术解剖.md`：宿主程序与 ksurface 的结构分析
