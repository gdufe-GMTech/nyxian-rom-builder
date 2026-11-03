/*
 * NXROMSystemInfo.m
 */

#import "NXROMSystemInfo.h"

#include <dlfcn.h>
#include <string.h>

#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/lock.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/libkern/radix/radix.h>
#import <LindChain/ProcEnvironment/Surface/libkern/kxld/image.h>

/* 本文件编进 ROM 的 main.dylib，dladdr 它就能找到槽目录 */
static void NXROMSystemInfoAnchor(void) {}

/*
 * radix_walk 收的是 C 函数指针（typedef void (*radix_walk_fn)(uint64_t, void*, void*)），
 * 不是 block，所以这里必须用静态 C 函数 + ctx。
 */
static void NXROMCollectProcess(uint64_t ident, void *value, void *ctx)
{
    NSMutableArray<NSDictionary *> *result = (__bridge NSMutableArray<NSDictionary *> *)ctx;
    ksurface_proc_t *process = (ksurface_proc_t *)value;
    if(process == NULL || result == nil)
    {
        return;
    }

    char comm[sizeof(process->bsd.kp_proc.p_comm) + 1] = {0};
    memcpy(comm, process->bsd.kp_proc.p_comm, sizeof(process->bsd.kp_proc.p_comm));

    [result addObject:@{
        @"pid": @(proc_getpid(process)),
        @"name": [NSString stringWithUTF8String:comm] ?: @"?",
        @"uid": @(proc_geteuid(process)),
    }];
}

static void NXROMCollectKext(uint64_t ident, void *value, void *ctx)
{
    NSMutableArray<NSString *> *result = (__bridge NSMutableArray<NSString *> *)ctx;
    kxld_image_info_t *image = (kxld_image_info_t *)value;
    if(image == NULL || image->mod == NULL || result == nil)
    {
        return;
    }

    char identifier[KMOD_MAX_NAME + 1] = {0};
    memcpy(identifier, image->mod->identifier, KMOD_MAX_NAME);

    uint32_t version = image->mod->version;
    [result addObject:[NSString stringWithFormat:@"%s %u.%u.%u",
                       identifier,
                       KMOD_VERSION_MAJOR(version),
                       KMOD_VERSION_MINOR(version),
                       KMOD_VERSION_PATCH(version)]];
}

@implementation NXROMSystemInfo

+ (BOOL)isKernelAvailable
{
    return ksurface != NULL;
}

+ (NSString *)hostname
{
    if(ksurface == NULL)
    {
        return @"(ksurface not booted)";
    }

    host_rdlock();
    NSString *hostname = [NSString stringWithUTF8String:ksurface->host_info.hostname] ?: @"localhost";
    host_unlock();
    return hostname;
}

+ (NSUInteger)processCount
{
    if(ksurface == NULL)
    {
        return 0;
    }

    proc_table_rdlock();
    NSUInteger count = ksurface->proc_info.proc_count;
    proc_table_unlock();
    return count;
}

+ (NSArray<NSDictionary *> *)processes
{
    if(ksurface == NULL)
    {
        return @[];
    }

    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];

    proc_table_rdlock();
    radix_walk(&ksurface->proc_info.tree, NXROMCollectProcess, (__bridge void *)result);
    proc_table_unlock();

    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"pid"] compare:b[@"pid"]];
    }];
    return result;
}

+ (NSArray<NSString *> *)kextIdentifiers
{
    if(ksurface == NULL)
    {
        return @[];
    }

    NSMutableArray<NSString *> *result = [NSMutableArray array];

    kext_table_rdlock();
    radix_walk(&ksurface->kext_info.kexts, NXROMCollectKext, (__bridge void *)result);
    kext_table_unlock();

    [result sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return result;
}

+ (NSUInteger)kextCount
{
    return [self kextIdentifiers].count;
}

+ (NSString *)summary
{
    if(![self isKernelAvailable])
    {
        return @"ksurface 未启动";
    }

    return [NSString stringWithFormat:@"%@ · %lu 进程 · %lu kext",
            [self hostname],
            (unsigned long)[self processCount],
            (unsigned long)[self kextCount]];
}

+ (nullable NSString *)romSlotDirectory
{
    Dl_info info = {0};
    if(dladdr((const void *)NXROMSystemInfoAnchor, &info) == 0 || info.dli_fname == NULL)
    {
        return nil;
    }
    return [[NSString stringWithUTF8String:info.dli_fname] stringByDeletingLastPathComponent];
}

+ (NSArray<NSDictionary *> *)romKexts
{
    NSString *slot = [self romSlotDirectory];
    if(slot.length == 0)
    {
        return @[];
    }

    NSString *directory = [slot stringByAppendingPathComponent:@"kexts"];
    NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil];
    NSArray<NSString *> *loaded = [self kextIdentifiers];
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];

    for(NSString *entry in entries)
    {
        if(![entry.pathExtension isEqualToString:@"kext"])
        {
            continue;
        }

        NSString *bundlePath = [directory stringByAppendingPathComponent:entry];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                              [bundlePath stringByAppendingPathComponent:@"Info.plist"]];

        NSString *identifier = info[@"NXKextIdentifier"] ?: info[@"CFBundleIdentifier"] ?: entry;

        BOOL isLoaded = NO;
        for(NSString *line in loaded)
        {
            if([line hasPrefix:identifier])
            {
                isLoaded = YES;
                break;
            }
        }

        [result addObject:@{
            @"bundle": entry,
            @"identifier": identifier,
            @"loaded": @(isLoaded),
        }];
    }

    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"bundle"] localizedCaseInsensitiveCompare:b[@"bundle"]];
    }];
    return result;
}

@end
