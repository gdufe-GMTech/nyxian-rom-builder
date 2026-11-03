# NyxianROM — 自己造一个 Nyxian 启动槽（"重建这个环境"）

**目标**：不碰 0.11.6.1 的 ROM 信任链，用**公开源码自己编一个 Nyxian**，然后在它上面刷自己写的 ROM 槽（桌面 + 设置 + 自己的 App）。

---

## 0. 先纠正一个前提（很重要）

我查了公开仓库的所有 tag 和 `main` 的文件树：

| 版本 | 有槽/引导器吗 | 有 ROM 签名/TrustStore 吗 |
|---|---|---|
| `0.11.4`（最新 tag，2026-09） | ❌ 没有 `BootViewController.swift`、`SlotEntry.swift`、`NXRecoveryViewController`、`nxromgen.sh` | — |
| `20251113a` / `20251122a` / `20251128a`（日期 tag） | ❌ 同上 | — |
| **`main` HEAD `0d573db99dca`（2026-10-31）** | ✅ 完整引导器 + Recovery + Flash ROM + Slot A/B | **❌ 没有**（`NXROMTrust` / `NXBootLockdown` / `NXTrustStore` 这些文件在公开树里根本不存在） |
| 你手上那个 `0.11.6.1` IPA | ✅ | ✅ 有（`ROM release signature does not match any trusted release key`） |

结论：**0.11.4 刷不了 ROM**（它还没有这套东西）。要"最稳妥"，正确路线是 **编 `main`**——它的引导器只校验 `manifest.plist` 和 `NXRomMinimumNyxianVersion`，**不校验发布签名**，所以你自己做的 ROM 直接能刷、能启动。0.11.6.1 那套 TrustStore 是后来闭源加的。

（也就是说：你选的"0.11.4 最省事"这个假设不成立，但结论反而更好——公开 `main` 就是"没有强制校验"的版本，而且带完整槽系统。）

---

## 1. 能力边界（先看清，别白折腾）

| 想要 | 能不能 | 为什么 |
|---|---|---|
| 自己的 App（含界面） | ✅ | `PEProcessManager` + `NXWindowSessionApplication` |
| 自己的桌面 / Dock / 设置 / 文件管理器 | ✅ | 本项目就是 |
| 更多命令行工具（bash、curl、python…） | ✅ | 往 rootfs 塞 arm64 Mach-O（binpack 已是这套） |
| 自己的守护进程、开机自启 | ✅ | `PEServiceMain` + `LaunchServices/*.plist` |
| 自己的 kext | ✅ | `__ksurfacemod` + kxld，加载进 Nyxian 地址空间 |
| Apple 的「设置」/ SpringBoard / Safari | ❌ | 要真 launchd、backboardd、cfprefsd、securityd、IOKit、平台签名；Nyxian 只模拟 syscall 层 |
| Android / 整机模拟 | ❌ | 没有 JIT / hypervisor |

所以 ROM 给你的是"长得像 iOS 的自建桌面 + 自己的系统 App"，不是把 iOS 搬进来。

---

## 2. 编 Nyxian（macOS）

### 2.1 取源码并钉死 commit

```bash
git clone https://github.com/emexlab/Nyxian.git
cd Nyxian

# 钉住我核对过的这版（有槽系统、没有 ROM 信任链）
git checkout 0d573db99dca

# 子模块（LLVM-On-iOS 很大，几百 MB ~ 几 GB）
git submodule update --init --recursive
```

### 2.2 依赖

- macOS + **完整 Xcode**（不是 CLT）。`main` 里用了 `#available(iOS 26.0, *)`，所以要带 iOS 26/27 SDK 的新版 Xcode；项目 `MinimumOSVersion` 是 18.0
- `brew install pkgconf cmake libarchive dpkg openssl ninja`
- Theos（`Makefile` 会把 `$(THEOS)/bin` 加进 PATH；如果 `make` 报找不到 `ldid` 之类再装：<https://theos.dev>）

> 没有 Mac 的话这条路走不通（iOS App 只能在 macOS 上编）。替代方案见文末「其他路线」。

### 2.3 一条命令构建

```bash
make            # = clean + check + compile + package-app + clean
# 产物：Nyxian.ipa（未签名）
```

`make` 会先编 `LLVM-On-iOS`（`CoreCompiler` 那个 188 MB 的编译器），**这一步是几十分钟到几小时**，慢是正常的。

> 只想快速试：直接用 Xcode 打开 `Nyxian.xcodeproj`，选你的 Team，Run 到设备。
> 这样会自动签名、带 `get-task-allow`，比 `make` + 重签省事（但拿不到 ipa）。

### 2.4 安装

`make` 出来的是 `CODE_SIGNING_ALLOWED=NO` 的**未签名 ipa**，必须自己签：

- **AltStore / Sideloadly**（用你的 Apple ID 开发证书）→ 推荐，`get-task-allow` 一定有
- 或者 **TrollStore**（如果设备支持）

⚠️ 必须是**带 `get-task-allow` 的开发者签名**，否则 `LiveProcess` 扩展起不来（`PEGetNSExtension`/`PEExtensionHasGetTaskAllowed` 会失败）。

### 2.5 没有 Mac：用在线 CI 编（GitHub Actions）

可以。GitHub 的 **`xcode-27`** 镜像基于 macOS 27，自带 **Xcode 27.1 + iOS 27.0/27.1/27.2 SDK**——正好是 Nyxian 需要的那个 SDK（`macos-26` 只有 iOS 26.x，可能编不过）。公开仓库的标准 macOS runner **不计费**，单 job 上限 6 小时。

步骤：

1. Fork [emexlab/Nyxian](https://github.com/emexlab/Nyxian) 到你自己的账号（**保持 public**，私有仓库的 macOS 分钟数会 ×10 计费）
2. 把本项目的 `NyxianROM/` 整个目录提交进那个 fork 的根目录
3. 把 `ci/build-ipa.yml` 复制成 `.github/workflows/build-ipa.yml`
4. 仓库 → Actions → `build-ipa` → **Run workflow**（可以填要编的 commit）
5. 跑完在 run 页面底部下载 artifact：`Nyxian.ipa`、`rom.zip`、`Nyxian-baked.ipa`

工作流是拆成两个 job 的：`llvm` 先把 `LLVM-On-iOS` 编出来并塞进 `actions/cache`（按 submodule 的 SHA 做 key），`app` 再编 Nyxian 和 ROM。**第一次跑很慢**（LLVM 那步几十分钟到几小时），之后命中缓存只编 App，十几分钟。

#### 把项目塞进 fork（两种方式）

**A. 一键脚本**（把目录 + 工作流都装好，Windows 也能跑）

```bash
python3 tools/install_into_fork.py /path/to/Nyxian-fork          # 真装
python3 tools/install_into_fork.py /path/to/Nyxian-fork --dry-run # 只看会干什么
```

它会复制 `NyxianROM/`、装 `.github/workflows/build-ipa.yml`、补 shell 脚本的可执行位，并清掉构建残留。

**B. git subtree**（想保留独立历史）

```bash
cd /path/to/Nyxian-fork
git subtree add --prefix=NyxianROM https://github.com/<you>/NyxianROM.git main --squash
mkdir -p .github/workflows && cp NyxianROM/ci/build-ipa.yml .github/workflows/
git add . && git commit -m 'add NyxianROM + CI'
```

（`install_into_fork.py --subtree` 会把这几条命令按你的路径打印出来。）

诚实提醒：

- 标准 macOS runner 磁盘比较紧（~14 GB 量级），LLVM 全量编译有可能撞上限；真撞了就用 `xcode-27-xlarge`（付费）或下面两个备选
- 6 小时是硬上限，`llvm` job 里我设了 `timeout-minutes: 350` 留余量
- 产物是**未签名**的 ipa，装之前还要签名（见 2.4）
- 备选：[Codemagic](https://codemagic.io)（`mac_mini_m2`，磁盘更大，免费 500 分钟/月，配置见 `ci/codemagic.yaml`）、或者按小时租一台 Mac（MacinCloud / Scaleway / MacStadium）跑同样的 `make`

---

## 3. 刷你自己的 ROM

### 3.1 先导入签名证书

Nyxian → Settings → 证书/签名：导入你**签 Nyxian 时用的那个 `.p12`**（同一个开发者证书）。
刷机时 `NXSignMachOAuto()` 要用它给 ROM 里的可执行文件签名——**没证书刷机会在 "failed to sign ..." 停住**。

### 3.2 打包

```bash
cd NyxianROM
./build.sh ~/Nyxian          # 生成 .work 工程 + 编 main + 打包 → rom.zip
```

只想要打包/校验工具（在别的机器上编）：

```bash
python3 tools/mkrom.py <staging> -o rom.zip \
    --identifier org.example.nyxrom --name NyxROM --version 0.1.0

python3 tools/verify_rom.py rom.zip
```

`<staging>` 里只要有 `main`（槽 dylib）和可选的 `Application/`。工具会自动生成 `manifest.plist`。

### 3.3 刷机

1. 进 Nyxian，**启动时按住一个音量键**（上/下分别是"强制回 SuperSlot"和"进 Recovery"，以日志为准：出现 `bootloader: recovery requested` 就是 Recovery，出现 `forcing SuperSlot.dylib` 就换另一个键）
2. `Flash ROM` → 选 `rom.zip`
3. 看日志：`extracting` → `signed main` → `signed Application/...` → `flashed ... into slot B`
4. **同时按两个音量键**重启
5. 正常启动时日志是 `bootloader: loading slot B`；想回官方环境：Recovery → `Unflash ROM`

### 3.4 做成"装了就是自己系统"的 ipa（不用刷）

`make` 出来的 `Nyxian.ipa` 是**官方界面**，我们的 ROM 得手动刷。想开箱即用，可以把 ROM 直接换到内置槽：

```bash
./build.sh ~/Nyxian --ipa
# 产物：rom.zip（手动刷用）+ Nyxian-baked.ipa（装了直接进我们的桌面）

# 想顺便省掉官方 SuperSlot 的备份（-19.8 MB）
NXROM_STRIP_OFFICIAL=1 ./build.sh ~/Nyxian --ipa
```

原理在 `BootViewController.swift` 的 `loadSlot()` 里：**没刷任何槽时，它会去 dlopen
`Payload/Nyxian.app/Frameworks/SuperSlot.dylib` 当作内置槽**。所以把我们的 `main` 换到那个位置，
启动就直接进我们的 ROM，`manifest.plist`、签名、刷机全都不用管。

`tools/bake_ipa.py` 会做三件事并自检：

- 把 `Frameworks/SuperSlot.dylib` 换成我们的 `main`
- 官方那份备份成 `SuperSlot.official.dylib`（`--strip-official` 可省掉这 19.8 MB，但就换不回去了）
- 把 `rom.zip` 塞进包里当 `BakedROM.zip`（留着给 Recovery 刷，或做对照）

想压体积，先看包里谁最占地方，再决定砍谁：

```bash
python3 tools/bake_ipa.py --ipa Nyxian.ipa --report
python3 tools/bake_ipa.py --ipa Nyxian.ipa --dylib main --strip-official \
    --strip Shared/swift.zip -o Nyxian-baked.ipa
```

`--report` 实测（0.11.6.1）：`CoreCompiler` 188 MB、`SuperSlot` 19.8 MB、`Assets.car` 19.7 MB、
`binpack.zip` 19.4 MB、`swift.zip` 17.7 MB。其中：

- `SuperSlot`：`--strip-official` 直接省
- `swift.zip` / `include.zip`：只有 IDE 编译时才用，`--strip` 掉没风险（你不打算在设备上编译的话）
- `binpack.zip`：Recovery 的终端依赖它（`nano`、`bash` 在里面），**别删**
- `Assets.car`：是编译后的资源包，里面的启动 logo/图标 bootloader 和 Recovery 还在用；**没有 `actool` 切不了**，我上面说"裁掉没用的图标"是我夸大了，做不到
- `CoreCompiler`：`Nyxian` 主二进制**没有**直接链接它（我查了 `LC_LOAD_DYLIB`，只链了 `libBroadpatch` + OpenSSL + libarchive），但 `MobileDevelopmentKit` 链着它；只要有代码在运行时 dlopen MDK（`PEProcess` 里就引用了 `MDKThreadPool`），删了就会崩。**不建议删**

⚠️ 两种包的区别：

| 包 | 开机进哪 | 官方 IDE 还在吗 | 需要刷机吗 |
|---|---|---|---|
| `Nyxian.ipa`（原样） | 官方界面 | ✅ | 要，Flash ROM |
| `Nyxian-baked.ipa` | 我们的桌面 | ❌ 被替换 | 不用 |

**ROM 本身不能单独变成 ipa**——`main` 是个 dylib，靠 Nyxian 进程里的 ksurface/LindChain 符号活着，
它不是 App。要么烤进 Nyxian，要么刷进槽。

---

## 4. ROM 的格式（这是硬约束，照抄就行）

刷机时 `unzipArchiveAtPathWithoutParentDirectory()` 会**剥掉每个条目的第一层目录**，所以 zip 必须有一层 `ROM/` 包着：

```
rom.zip
└── ROM/
    ├── manifest.plist        ← ROMManifest 解析，缺了 = "failed to extract ROM"
    ├── main                  ← NXRomExecutable，必须导出 NXSlotMain
    ├── Application/
    │   ├── Hello.app/{Info.plist, Hello}
    │   └── Files.app/{Info.plist, Files}
    └── kexts/
        └── NXROMHello.kext/{Info.plist, NXROMHello}
```

`manifest.plist` 的键（全部来自 `BootViewController.swift` 的 `ROMManifest`）：

```xml
<key>NXRomManifestVersion</key><integer>1</integer>
<key>NXRomIdentifier</key><string>org.example.nyxrom</string>
<key>NXRomName</key><string>NyxROM</string>
<key>NXRomVersion</key><string>0.1.0</string>
<key>NXRomMinimumNyxianVersion</key><string>0.0.0</string>   <!-- 必填；0.0.0 = 永远满足 -->
<key>NXRomMaximumNyxianVersion</key><string>…</string>        <!-- 可选 -->
<key>NXRomExecutable</key><string>main</string>               <!-- 必填，槽内相对路径 -->
<key>NXRomDefaultFilePermission</key><integer>420</integer>    <!-- 0644 -->
<key>NXRomDefaultDirectoryPermission</key><integer>493</integer> <!-- 0755 -->
<key>NXRomPaths</key>
<array>
  <dict>
    <key>NXPath</key><string>main</string>
    <key>NXRequiresCodeSigning</key><true/>          <!-- 刷机时用你的证书重签 -->
    <key>NXT2Entitlements</key><dict>…</dict>        <!-- 可选：NXT2 权限 blob -->
  </dict>
</array>
```

`NXRomPaths` 里 `NXRequiresCodeSigning=true` 的文件，刷机时会被 `NXSignMachOAuto()` 重签并 refresh vnode；带 `NXT2Entitlements` 的还会走 `trust_nxt2_sign()`。

注意 `NXT2Entitlements` 的语义是"这个键**存在**就做 NXT2 签名"，哪怕是空字典
（`ROMManifest` 里：有键 → `requiresNXT2Signing` 保持 true；没键 → 降级成只做普通签名）。
`mkrom.py` 给 kext 生成的就是空字典，即"签 NXT2，但不给额外权限"。

---

## 5. 项目结构

```
NyxianROM/
├── build.sh                   nxromgen → overlay → make → rom.zip
├── Makefile                   main dylib + appsrc/* + kexts/* 全自动
├── overlay/rom/src/
│   ├── NXMainSlot.m           槽入口（NXSlotMain/NXSlotCreateWindow/NXSlotDidAppear）+ kext 加载
│   └── NXROM/                 桌面、设置、应用扫描、ksurface 状态
├── appsrc/{Hello,Files}/      两个 guest 示例
├── kexts/
│   ├── NXROMHello/            自带的最小 kext（只依赖 ksurface）
│   └── README.md              依赖表 / 拉上游示例
├── ci/
│   ├── build-ipa.yml          GitHub Actions 工作流（runs-on: xcode-27）
│   └── codemagic.yaml         Codemagic 备选
└── tools/
    ├── mkrom.py               打 rom.zip（自动生成 manifest.plist）
    ├── mkkext.py              kext 二进制 → .kext bundle（写 Info.plist）
    ├── fetch_kexts.sh         拉上游 KEXTs/*.zip 示例源码
    ├── bake_ipa.py            把 main 换进 Frameworks/SuperSlot.dylib → 开箱即用的 ipa
    └── verify_rom.py          刷前自检
```

槽 ABI（官方 `SlotEntry.swift` 同款）：

```c
void *NXSlotMain(void);                 // 返回 retained UIViewController*，主线程调用
void *NXSlotCreateWindow(void *scene);  // UIWindowScene* → NXWindowServer*（可选）
void  NXSlotDidAppear(void);            // （可选）
```

引导顺序（顺序反了会命中 `trust_enforcement` / `klog` 的断言）：

```
trust_enforcement_set_mode → klog_set_obfuscation → （可选 NXBootstrap）
  → bootWithKextLoadingEnabled → 加载 ROM kext → 返回根 VC
```

### 5.1 kext（ROM 自带的扩展）

`make kexts` 把每个 `kexts/<Name>/Main.{c,m}` 编成 `kexts-bin/<Name>.kext/`，`make` 会一起打进
`rom.zip`，刷机时由 `NXRomPaths` 里带 `NXT2Entitlements` 的条目重签 + 打 NXT2 blob，开机时
`NXROMLoadROMKexts()` 逐个 `[[PEKext alloc] initWithPath:]` + `[kext load]`。

自带 `NXROMHello` 只依赖 `ksurface`，任何版本都能加载，用来验证流水线。要更多：

```bash
./tools/fetch_kexts.sh                  # 拉上游 10 个示例到 kexts/upstream/
./tools/fetch_kexts.sh KRW NyxianMount   # 或挑几个
make kexts
```

⚠️ 上游示例有版本锁和依赖：`KRW` 精确要求 `ksurface 0.11.4`（main 是 0.11.5，会被拒），
`TestTweak` 需要 `BasePreferenceLoader`。完整的依赖表在 [`kexts/README.md`](kexts/README.md)。
加载失败会在内核日志里写 `Kext '<id>' requires kext '<dep>' ...`。

---

## 6. 你刷完会看到

- **桌面**：渐变壁纸、时钟、主机名、图标网格、Dock（设置/文件/App Switcher/内核日志）
- **设置**：真实进程表（pid/名字/uid，直接走 `ksurface->proc_info`）、kext 列表（`kext_info.kexts`）、权限模式、开机 kext 开关、**ROM 自带 kext 的加载状态**、内核日志、用户空间重启
- **Files.app**：从 vroot 的 `/` 浏览 ROM 的 rootfs
- **Hello.app**：链路验证（能出界面 = 槽→ksurface→NSExtension→dyld→窗口全通）

---

## 7. 排错（按刷机日志里的原文对）

| 日志 | 原因 | 修法 |
|---|---|---|
| `failed to extract ROM` | zip 没有 `ROM/` 包装，或里面没 `manifest.plist` | 用 `tools/mkrom.py` 打，别手 zip |
| `malformed manifest plist` | 少键 / 类型不对（`NXRomManifestVersion` 必须是 Int） | 对照第 4 节 |
| `failed to sign main` | Nyxian 里没导入证书 | Settings → 证书，导入签 Nyxian 用的 `.p12` |
| `this ROM needs ... this is Nyxian ...` | `NXRomMinimumNyxianVersion` 高于你编的版本 | 设成 `0.0.0` |
| `couldnt load main: ...` | dylib 架构不对 / 用了 ELF | arm64 iOS Mach-O，`-dynamiclib` |
| `main has no NXSlotMain entry point` | 符号没导出 | 加 `__attribute__((visibility("default")))`，别 strip |
| `NXSlotMain returned no view controller` | 根 VC 初始化崩了 | 先返回一个纯色 VC 排除 UI 问题 |
| `a ROM operation is still running` | 上一次还在跑 | 等它结束/重启再刷 |
| 黑屏但日志正常 | `NXSlotCreateWindow` 返回了但窗口没内容 | 先删掉 `NXSlotCreateWindow` 导出，走宿主窗口 |
| 日志 `Kext 'x' requires kext 'y'` | 依赖没打包或版本不匹配 | 按提示补 kext / 放宽 `KMOD_VERSION` |
| 日志 `kext ... load -> 非 0` | 签名或 NXT2 校验没过 | 确认刷机日志里有 `signed kexts/...`；否则说明 `NXRomPaths` 没列它 |
| 设置里 `ROM 自带 kext 0/N` | 槽里没有 `kexts/`，或 `nyxian.boot.kextLoading` 关了 | 看 `make` 有没有 `>> kext ...`，打开开关后重启用户空间 |

---

## 8. 已知未验证项

我在 Windows 上分析 IPA，**没有 iOS SDK，代码没有编译过**：

- 已验证：`mkrom.py` 能生成符合 `ROMManifest` 解析的 manifest 并打包；`verify_rom.py` 能在官方 `SuperSlot.dylib` 上正确识别 `NXSlotMain/NXSlotDidAppear/NXSlotCreateWindow` 三个导出符号
- 未验证：ObjC 源码的编译（第一次 `make` 大概率要修 API 细节，比如你的 `main` commit 上 `NXWindowServer`/`PEProcessManager` 的方法签名）
- 最多三类报错：① 方法签名变了；② `rom/stubs/` 缺头（nxromgen 会列出来）；③ `NXBootstrap` 在你的版本里是 Swift 的（那就删掉 `NXMainSlot.m` 里那段 `NSClassFromString`，默认也已经是关的）

把编译错误贴给我，我按你钉的 commit 改。

---

## 9. 参考 / 其他路线

没有 Mac、或者不想等 LLVM 编译的话，只剩两条：

- 用别人编好的 `main` 版本（未签名 ipa，自己重签）——但 `main` 是移动分支，我钉的 `0d573db99dca` 是唯一核对过的
- 继续用 0.11.6.1，patch 掉 `NXROMVerifySeal`/TrustStore 校验再重签（要维护 fork，而且丢了回滚保护）

参考：

- [emexlab/Nyxian](https://github.com/emexlab/Nyxian) — `Nyxian/UI/BootViewController.swift`（引导器 + 刷机 + `ROMManifest` + 内置 `SuperSlot.dylib` 回退）、`Nyxian/UI/SlotEntry.swift`（槽 ABI 官方实现）、`Nyxian/LindChain/Utils/Zip.m`（`unzipArchiveAtPathWithoutParentDirectory` 剥第一层目录）、`Makefile`
- 本仓库 `Nyxian-技术解剖.md` — 0.11.6.1 的分层拆解与二进制证据
