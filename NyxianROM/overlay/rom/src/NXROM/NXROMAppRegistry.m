/*
 * NXROMAppRegistry.m
 */

#import "NXROMAppRegistry.h"

#include <dlfcn.h>

#import <LindChain/IDEFoundation/NXBootstrap.h>
#import <LindChain/ProcEnvironment/PEProcessManager.h>
#import <LindChain/ProcEnvironment/PEProcess.h>
#import <LindChain/WindowServer/NXWindowServer.h>
#import <LindChain/WindowServer/Session/NXWindowSessionApplication.h>
#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>

/* 本文件编进 ROM 的 main.dylib，所以 dladdr 到它就能拿到槽目录（Library/Boot/Slot/A）。 */
static void NXROMSlotAnchor(void) {}

static NSString *NXROMSlotDirectory(void)
{
    Dl_info info = {0};
    if(dladdr((const void *)NXROMSlotAnchor, &info) == 0 || info.dli_fname == NULL)
    {
        return nil;
    }
    return [[NSString stringWithUTF8String:info.dli_fname] stringByDeletingLastPathComponent];
}

@implementation NXROMApplication
@end

@interface NXROMAppRegistry ()
@property (nonatomic, readwrite) NSArray<NXROMApplication *> *applications;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIImage *> *iconCache;
@end

@implementation NXROMAppRegistry

+ (instancetype)shared
{
    static NXROMAppRegistry *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[NXROMAppRegistry alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _applications = @[];
        _iconCache = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - 扫描

- (NSString *)rootfsPath
{
    NSString *home = NSHomeDirectory();
    return [home stringByAppendingPathComponent:@"Documents/rootfs"];
}

- (NSArray<NSString *> *)scannedDirectories
{
    NSMutableArray<NSString *> *directories = [NSMutableArray array];

    /* 首选：ROM 槽里的 Application/（nxromgen 会把它挂进 rootfs） */
    NSString *slot = NXROMSlotDirectory();
    if(slot.length > 0)
    {
        [directories addObject:[slot stringByAppendingPathComponent:@"Application"]];
    }

    NSString *rootfs = [self rootfsPath];
    NSString *home = NSHomeDirectory();
    [directories addObjectsFromArray:@[
        [rootfs stringByAppendingPathComponent:@"Application"],
        [home stringByAppendingPathComponent:@"Documents/Cache/Payload"],
        [home stringByAppendingPathComponent:@"Documents/Cache"],
    ]];

    return directories;
}

- (NSArray<NXROMApplication *> *)reload
{
    NSMutableArray<NXROMApplication *> *found = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for(NSString *directory in [self scannedDirectories])
    {
        BOOL isROM = [directory containsString:@"/rootfs/"];
        NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil];
        for(NSString *entry in entries)
        {
            if(![entry.pathExtension isEqualToString:@"app"])
            {
                continue;
            }

            NSString *bundlePath = [directory stringByAppendingPathComponent:entry];
            NXROMApplication *application = [self applicationAtBundlePath:bundlePath fromROM:isROM];
            if(application == nil || [seen containsObject:application.bundleIdentifier])
            {
                continue;
            }

            [seen addObject:application.bundleIdentifier];
            [found addObject:application];
        }
    }

    [found sortUsingComparator:^NSComparisonResult(NXROMApplication *a, NXROMApplication *b) {
        return [a.displayName localizedCaseInsensitiveCompare:b.displayName];
    }];

    self.applications = found;
    klog_log("rom", "app registry: %{public}lu applications", (unsigned long)found.count);
    return found;
}

- (nullable NXROMApplication *)applicationAtBundlePath:(NSString *)bundlePath fromROM:(BOOL)fromROM
{
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSDictionary *info = bundle.infoDictionary;

    if(info == nil)
    {
        NSString *plistPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
        info = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    }
    if(info == nil)
    {
        return nil;
    }

    NSString *identifier = info[@"CFBundleIdentifier"];
    NSString *executableName = info[@"CFBundleExecutable"];
    if(identifier.length == 0 || executableName.length == 0)
    {
        return nil;
    }

    NSString *executablePath = [bundlePath stringByAppendingPathComponent:executableName];
    if(![NSFileManager.defaultManager isReadableFileAtPath:executablePath])
    {
        return nil;
    }

    NXROMApplication *application = [NXROMApplication new];
    application.bundleIdentifier = identifier;
    application.bundlePath = bundlePath;
    application.executablePath = executablePath;
    application.displayName = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: identifier;
    application.fromROM = fromROM;
    application.icon = [self iconForBundlePath:bundlePath info:info identifier:identifier];
    return application;
}

#pragma mark - 图标

- (nullable UIImage *)iconForBundlePath:(NSString *)bundlePath
                                   info:(NSDictionary *)info
                             identifier:(NSString *)identifier
{
    UIImage *cached = self.iconCache[identifier];
    if(cached != nil)
    {
        return cached;
    }

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];

    id icons = info[@"CFBundleIcons"];
    if([icons isKindOfClass:NSDictionary.class])
    {
        id primary = icons[@"CFBundlePrimaryIcon"];
        if([primary isKindOfClass:NSDictionary.class])
        {
            id files = primary[@"CFBundleIconFiles"];
            if([files isKindOfClass:NSArray.class])
            {
                for(NSString *name in [files reverseObjectEnumerator])
                {
                    if([name isKindOfClass:NSString.class])
                    {
                        [candidates addObject:name];
                    }
                }
            }
        }
    }

    [candidates addObjectsFromArray:@[
        @"AppIcon60x60@2x.png", @"AppIcon60x60@3x.png",
        @"Icon@2x.png", @"Icon.png", @"AppIcon.png",
    ]];

    for(NSString *name in candidates)
    {
        NSArray<NSString *> *names = @[name, [name stringByAppendingString:@".png"]];
        for(NSString *candidate in names)
        {
            NSString *path = [bundlePath stringByAppendingPathComponent:candidate];
            UIImage *image = [UIImage imageWithContentsOfFile:path];
            if(image != nil)
            {
                self.iconCache[identifier] = image;
                return image;
            }
        }
    }

    return nil;
}

#pragma mark - 启动

- (pid_t)launchApplication:(NXROMApplication *)application
{
    if(application.executablePath.length == 0)
    {
        return -1;
    }

    NSDictionary *items = @{
        @"PEExecutablePath": application.executablePath,
        @"PEArguments": @[ application.executablePath ],
        @"PEWorkingDirectory": application.bundlePath,
        @"PEEnvironment": @{},
    };

    pid_t pid = [[PEProcessManager shared] spawnProcessWithItems:items withKernelSurfaceProcess:NULL];
    if(pid < 0)
    {
        klog_log("rom", "launch failed: %{public}s", application.bundleIdentifier.UTF8String);
        return -1;
    }

    PEProcess *process = [[PEProcessManager shared] processForProcessIdentifier:pid];
    if(process == nil)
    {
        klog_log("rom", "launch: spawned pid %d but no PEProcess", pid);
        return pid;
    }

    process.applicationObject = nil;
    process.bundleIdentifier = application.bundleIdentifier;
    process.displayName = application.displayName;

    NXWindowSessionApplication *session = [[NXWindowSessionApplication alloc] initWithProcess:process];
    [[NXWindowServer shared] openWindowWithSession:session withCompletion:^(BOOL success) {
        klog_log("rom", "window for %{public}s: %{public}s",
                 application.bundleIdentifier.UTF8String,
                 success ? "opened" : "failed");
    }];

    return pid;
}

@end
