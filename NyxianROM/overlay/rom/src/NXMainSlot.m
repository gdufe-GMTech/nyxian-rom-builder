/*
 * NXMainSlot.m — Nyxian ROM 槽入口
 *
 * 这个文件就是 bootloader 通过 dlsym 找的三个符号：
 *   void *NXSlotMain(void)          -> 返回一个 retained UIViewController（根界面）
 *   void *NXSlotCreateWindow(void*) -> 传入 UIWindowScene*，返回 NXWindowServer*
 *   void  NXSlotDidAppear(void)     -> 根界面已经上屏，做首启/欢迎/自检
 *
 * 与官方 SlotEntry.swift 等价的 ObjC 版本：不依赖 Swift 运行时，
 * 也就不用把 Nyxian 的 Swift 桥接头打进 ROM。
 *
 * SPDX-License-Identifier: LicenseRef-EPSL-1.1（与 Nyxian 的 LindChain 源码保持一致）
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <limits.h>
#include <stdlib.h>

#import <LindChain/IDEFoundation/NXBootstrap.h>
#import <LindChain/ProcEnvironment/PEUserspaceManager.h>
#import <LindChain/ProcEnvironment/Surface/trust/trust.h>
#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#import <LindChain/WindowServer/NXWindowServer.h>

#if __has_include(<LindChain/ProcEnvironment/KextLoader/PEKext.h>)
#import <LindChain/ProcEnvironment/KextLoader/PEKext.h>
#define NXROM_HAVE_PEKEXT 1
#else
#define NXROM_HAVE_PEKEXT 0
#endif

#include <dlfcn.h>

#import "NXROM/NXROMShellViewController.h"

/* main.dylib 里的锚点，用来定位槽目录（Library/Boot/Slot/A） */
static void NXROMSlotAnchor(void) {}

static BOOL NXROMBoolDefault(NSString *key, BOOL fallback);

static NSString *NXROMSlotDirectory(void)
{
    Dl_info info = {0};
    if(dladdr((const void *)NXROMSlotAnchor, &info) == 0 || info.dli_fname == NULL)
    {
        return nil;
    }
    return [[NSString stringWithUTF8String:info.dli_fname] stringByDeletingLastPathComponent];
}

/*
 * 加载 ROM 自带的 kext：<slot>/kexts/*.kext
 *
 * 走 PEKext 的完整流水线（代码签名校验、NXT2 信任 blob、kxld 映射/fixup/reseal、
 * 依赖解析、初始化），和官方 PEKextLoader 用的是同一套东西。
 * 这里不按依赖排序（kext 数量少），失败只记日志，不阻断启动。
 */
static void NXROMLoadROMKexts(void)
{
    if(!NXROMBoolDefault(@"nyxian.boot.kextLoading", YES))
    {
        klog_log("rom", "kext loading disabled, skipping ROM kexts");
        return;
    }

    NSString *slot = NXROMSlotDirectory();
    if(slot.length == 0)
    {
        klog_log("rom", "could not locate ROM slot, skipping kexts");
        return;
    }

    NSString *directory = [slot stringByAppendingPathComponent:@"kexts"];
    NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil];
    if(entries.count == 0)
    {
        return;
    }

#if NXROM_HAVE_PEKEXT
    for(NSString *entry in [entries sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)])
    {
        if(![entry.pathExtension isEqualToString:@"kext"])
        {
            continue;
        }

        NSString *path = [directory stringByAppendingPathComponent:entry];
        PEKext *kext = [[PEKext alloc] initWithPath:path];
        if(kext == nil)
        {
            klog_log("rom", "failed to parse kext %s", entry.UTF8String);
            continue;
        }

        kext.isEnabled = YES;
        int rc = [kext load];
        klog_log("rom", "kext %s (%s) load -> %d", entry.UTF8String, kext.bundleID.UTF8String, rc);
    }
#else
    klog_log("rom", "PEKext is not part of this ROM build, %lu kexts ignored", (unsigned long)entries.count);
#endif
}

static BOOL NXROMBoolDefault(NSString *key, BOOL fallback)
{
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return value ? [value boolValue] : fallback;
}

static PEEnforcementMode NXROMEnforcementMode(void)
{
    NSString *mode = [NSUserDefaults.standardUserDefaults stringForKey:@"nyxian.boot.entitlements.mode"];
    if([mode isEqualToString:@"permissive"])
    {
        return kPEEnforcementModePermissive;
    }
    if([mode isEqualToString:@"disabled"])
    {
        return kPEEnforcementModeDisabled;
    }
    return kPEEnforcementModeEnforcing;
}

/*
 * 引导顺序刻意与官方模板保持一致：
 *   权限模式 -> 日志混淆 -> bootstrap 目录/SDK -> 用户空间（含 kext）-> 返回根界面
 * 顺序反了会触发 trust_enforcement / klog 的断言（它们的全局量只能设置一次）。
 */
UIViewController *NXROMBootAndMakeRootViewController(void)
{
    klog_log("rom", "NXSlotMain: boot begin");

    if(!trust_enforcement_set_mode(NXROMEnforcementMode()))
    {
        klog_log("rom", "NXSlotMain: trust_enforcement_set_mode failed (already initialized?)");
    }

    klog_set_obfuscation(NXROMBoolDefault(@"nyxian.boot.log.obfuscated", YES));

    /*
     * NXBootstrap 会去下 SDK / swift 资源（几百 MB），ROM 里默认不需要：
     * 除非用户显式打开 nxrom.wants.bootstrap，否则跳过，保证 NXSlotMain 快速返回。
     */
    if(NXROMBoolDefault(@"nxrom.wants.bootstrap", NO))
    {
        Class bootstrapClass = NSClassFromString(@"NXBootstrap");
        if(bootstrapClass != Nil &&
           [bootstrapClass respondsToSelector:@selector(shared)])
        {
            id bootstrap = [bootstrapClass performSelector:@selector(shared)];
            if([bootstrap respondsToSelector:@selector(bootstrap)])
            {
                [bootstrap performSelector:@selector(bootstrap)];
            }
            if([bootstrap respondsToSelector:@selector(waitTillDoneNoButton)])
            {
                [bootstrap performSelector:@selector(waitTillDoneNoButton)];
            }
        }
    }

    BOOL loadKexts = NXROMBoolDefault(@"nyxian.boot.kextLoading", YES);
    [[PEUserspaceManager shared] bootWithKextLoadingEnabled:loadKexts];

    klog_log("rom", "NXSlotMain: userspace booted (kexts=%s)", loadKexts ? "on" : "off");

    /* ksurface 已经起来了，再装 ROM 自带的 kext */
    NXROMLoadROMKexts();

    return [[NXROMShellViewController alloc] init];
}

#pragma mark - 导出给 bootloader 的符号

__attribute__((visibility("default")))
void *NXSlotMain(void)
{
    UIViewController *root = NXROMBootAndMakeRootViewController();
    return (__bridge_retained void *)root;
}

__attribute__((visibility("default")))
void *NXSlotCreateWindow(void *scenePtr)
{
    if(scenePtr == NULL)
    {
        return NULL;
    }

    UIWindowScene *scene = (__bridge UIWindowScene *)scenePtr;
    NXWindowServer *window = [NXWindowServer sharedWithWindowScene:scene];
    return window ? (__bridge_retained void *)window : NULL;
}

__attribute__((visibility("default")))
void NXSlotDidAppear(void)
{
    klog_log("rom", "NXSlotDidAppear");

    Class serverClass = NSClassFromString(@"NXWindowServer");
    if(serverClass != Nil && [serverClass respondsToSelector:@selector(shared)])
    {
        id server = [serverClass performSelector:@selector(shared)];
        if([server isKindOfClass:UIWindow.class])
        {
            [(UIWindow *)server makeKeyAndVisible];
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"NXROMDidAppearNotification" object:nil];
}
