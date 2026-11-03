# kexts/

ROM 会把这些目录编成 `.kext` 并打进包里，开机时由 `NXMainSlot.m` 的 `NXROMLoadROMKexts()`
用 ksurface 自己的 `PEKext` 加载（代码签名校验 → NXT2 → kxld 映射/fixup/reseal → init）。

## 目录约定

```
kexts/<Name>/
├── Main.m       或 Main.c      ← 必须有，编成 kexts-bin/<Name>.kext/<Name>
└── kext.plist                  ← NXKextIdentifier / NXKextVersion / CFBundleExecutable
```

`make kexts` 只编 kext；`make` 会顺带编并打进 `rom.zip`。

## 自带示例：NXROMHello

只依赖 `ksurface`，没有其他依赖，用来验证流水线：刷完机在
Settings → 内核扩展 里应该能看到 `org.example.nxrom.hello 1.0.0`，
`ROM 自带 kext` 显示 `1/1 已加载`，内核日志里有 `hello from a ROM-bundled kext`。

## 拉上游示例

```bash
./tools/fetch_kexts.sh                 # 全部
./tools/fetch_kexts.sh KRW NyxianMount  # 挑几个
```

它们会落到 `kexts/upstream/<Name>/`，`kext.plist` 是从 `EXPORT_KSURFACE_MODULE` 的
`.identifier` 里抠出来的。

### 依赖关系（拉之前先看，不然会加载失败）

| kext | 依赖 | 备注 |
|---|---|---|
| `NXROMHello` | `ksurface ≥ 0.11.0` | 自带，永远能加载 |
| `NyxianMount` | `ksurface 0.11.5` | 把 `Documents/mntfs/nyxianfs/...` 挂进 guest root |
| `RelHomeMount` | `ksurface` | 相对路径的 home 挂载 |
| `KRW` | `ksurface 0.11.4` **精确匹配** | 给 ksurface 注册 kernel rw 系统调用；版本锁死，0.11.5 上会被拒 |
| `TestTweak` | `ksurface 0.11.5` + `BasePreferenceLoader` | 需要在 Settings 里加一页 |
| `BasePreferenceLoader` | `ksurface` | 提供 `PreferenceLoaderAppendEntry()`，上面那个的前置 |
| `BaseEntitlementLoader` | `ksurface` | 自定义 entitlements 加载 |
| `CrashReporter` | `ksurface` | 崩溃报告（handoffep 扩展），文件多、最容易编不过 |
| `ColorWinMix` / `SharedTheme` / `UISingleFlight` | `ksurface` | UI 相关，会 `#import <UI/...>` |

`ksurface` 的版本号取自 ROM 里 `ksurfaceMainKext` 上报的值（main 上是 `0.11.5`）。
加载失败时内核日志会写 `Kext '<id>' requires kext '<dep>'...`，按提示改 `kext.plist`
或改源码里的 `KMOD_VERSION` 即可。

## 注意

- kext 跑在 **Nyxian 进程的地址空间里**，拥有 Nyxian 的全部权限——不是沙盒。
- 上游示例的源码是 emexLabs 的（EPSL 1.1），`kexts/upstream/` 已在 `.gitignore` 里，不会误提交。
- `NXROMHello` 用了 `__has_include` 兼容 `Surface/kxld/image.h`（main）和
  `Surface/libkern/kxld/image.h`（0.11.6.1）两种布局。
