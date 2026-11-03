/*
 * NXROMAppRegistry.m
 */

#import "NXROMAppRegistry.h"
#import "NXROMDesign.h"

#include <dlfcn.h>

#import <LindChain/IDEFoundation/NXBootstrap.h>
#import <LindChain/ProcEnvironment/PEProcessManager.h>
#import <LindChain/ProcEnvironment/PEProcess.h>
#import <LindChain/WindowServer/NXWindowServer.h>
#import <LindChain/WindowServer/Session/NXWindowSessionApplication.h>
#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>

@implementation NXROMApplication
@end

/* 系统 App 定义：标识、显示名、SF Symbol、图标底色 */
static NSArray<NSArray<NSString *> *> *NXROMBuiltinDefinitions(void)
{
    return @[
        @[ @"settings",   @"设置",   @"gearshape.fill",           @"systemGray" ],
        @[ @"clock",      @"时钟",   @"clock.fill",               @"systemOrange" ],
        @[ @"calculator", @"计算器", @"plus.forwardslash.minus",  @"systemTeal" ],
        @[ @"files",      @"文件",   @"folder.fill",              @"systemBlue" ],
    ];
}

static UIColor *NXROMColorNamed(NSString *name)
{
    if([name isEqualToString:@"systemGray"])
    {
        return [UIColor systemGrayColor];
    }
    if([name isEqualToString:@"systemOrange"])
    {
        return [UIColor systemOrangeColor];
    }
    if([name isEqualToString:@"systemTeal"])
    {
        return [UIColor systemTealColor];
    }
    if([name isEqualToString:@"systemBlue"])
    {
        return [UIColor systemBlueColor];
    }
    return [UIColor systemGrayColor];
}

/* 本文件编进 ROM 的 main.dylib，dladdr 到它即可定位槽目录 */
static void NXROMSlotAnchor(void) {}

@interface NXROMAppRegistry ()
@property (nonatomic, readwrite) NSArray<NXROMApplication *> *applications;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIImage *> *iconCache;
@property (nonatomic, strong) NSArray<NXROMApplication *> *builtins;
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
        _builtins = [self makeBuiltins];
    }
    return self;
}

- (NSArray<NXROMApplication *> *)makeBuiltins
{
    NSMutableArray<NXROMApplication *> *result = [NSMutableArray array];
    for(NSArray<NSString *> *definition in NXROMBuiltinDefinitions())
    {
        NXROMApplication *application = [NXROMApplication new];
        application.kind = NXROMAppKindBuiltin;
        application.builtinIdentifier = definition[0];
        application.bundleIdentifier = [@"org.example.nyxrom." stringByAppendingString:definition[0]];
        application.displayName = definition[1];
        application.symbolName = definition[2];
        application.tintColor = NXROMColorNamed(definition[3]);
        application.icon = [self iconForSymbol:definition[2] tint:application.tintColor name:definition[0]];
        [result addObject:application];
    }
    return result;
}

- (UIImage *)iconForSymbol:(NSString *)symbol tint:(UIColor *)tint name:(NSString *)name
{
    UIImage *cached = self.iconCache[name];
    if(cached != nil)
    {
        return cached;
    }

    CGFloat size = 180.0;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size)];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGRect rect = CGRectMake(0, 0, size, size);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:size * NXROMIconCornerRatio];
        [path addClip];

        UIColor *top = [tint colorWithAlphaComponent:0.95];
        UIColor *bottom = [tint colorWithAlphaComponent:0.62];
        CGGradientRef gradient = CGGradientCreateWithColors(NULL, (__bridge CFArrayRef)@[ (id)top.CGColor, (id)bottom.CGColor ], NULL);
        CGContextDrawLinearGradient(context.CGContext, gradient, CGPointMake(0, 0), CGPointMake(0, size), 0);
        CGGradientRelease(gradient);

        UIImage *symbolImage = [UIImage systemImageNamed:symbol];
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:size * 0.46
                                                                                                  weight:UIImageSymbolWeightMedium];
        symbolImage = [symbolImage imageByApplyingSymbolConfiguration:configuration];
        CGSize symbolSize = symbolImage.size;
        [symbolImage drawInRect:CGRectMake((size - symbolSize.width) / 2.0, (size - symbolSize.height) / 2.0,
                                           symbolSize.width, symbolSize.height)
                      blendMode:kCGBlendModeNormal
                          alpha:1.0];
    }];

    self.iconCache[name] = image;
    return image;
}

- (nullable NSString *)rootfsPath
{
    NSString *home = NSHomeDirectory();
    return [home stringByAppendingPathComponent:@"Documents/rootfs"];
}

- (nullable NSString *)slotPath
{
    Dl_info info = {0};
    if(dladdr((const void *)NXROMSlotAnchor, &info) == 0 || info.dli_fname == NULL)
    {
        return nil;
    }
    return [[NSString stringWithUTF8String:info.dli_fname] stringByDeletingLastPathComponent];
}

- (NSArray<NSString *> *)scannedDirectories
{
    NSMutableArray<NSString *> *directories = [NSMutableArray array];

    NSString *slot = [self slotPath];
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
    NSMutableArray<NXROMApplication *> *found = [NSMutableArray arrayWithArray:self.builtins];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for(NSString *directory in [self scannedDirectories])
    {
        BOOL isROM = [directory containsString:@"/rootfs/"] || [directory containsString:@"/Slot/"];
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

    self.applications = [self applyingFoldersTo:found];
    klog_log("rom", "app registry: %{public}lu tiles", (unsigned long)self.applications.count);
    return self.applications;
}

/*
 * 文件夹来自槽内的 nxrom.folders.plist：
 *   { "效率": ["org.example.a", "org.example.b"], ... }
 * 没有该文件时按平铺展示。
 */
- (NSArray<NXROMApplication *> *)applyingFoldersTo:(NSArray<NXROMApplication *> *)applications
{
    NSString *slot = [self slotPath];
    if(slot.length == 0)
    {
        return applications;
    }

    NSString *plistPath = [slot stringByAppendingPathComponent:@"nxrom.folders.plist"];
    NSDictionary<NSString *, NSArray<NSString *> *> *config = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    if(config.count == 0)
    {
        return applications;
    }

    NSMutableDictionary<NSString *, NXROMApplication *> *byIdentifier = [NSMutableDictionary dictionary];
    for(NXROMApplication *application in applications)
    {
        if(application.bundleIdentifier.length > 0)
        {
            byIdentifier[application.bundleIdentifier] = application;
        }
    }

    NSMutableSet<NXROMApplication *> *consumed = [NSMutableSet set];
    NSMutableArray<NXROMApplication *> *result = [NSMutableArray array];

    for(NSString *folderName in config)
    {
        NSMutableArray<NXROMApplication *> *children = [NSMutableArray array];
        for(NSString *identifier in config[folderName])
        {
            NXROMApplication *child = byIdentifier[identifier];
            if(child != nil && ![consumed containsObject:child])
            {
                [children addObject:child];
                [consumed addObject:child];
            }
        }

        if(children.count == 0)
        {
            continue;
        }

        NXROMApplication *folder = [NXROMApplication new];
        folder.kind = NXROMAppKindFolder;
        folder.bundleIdentifier = [@"org.example.nyxrom.folder." stringByAppendingString:folderName];
        folder.displayName = folderName;
        folder.children = children;
        folder.icon = [self folderIconForChildren:children];
        [result addObject:folder];
    }

    for(NXROMApplication *application in applications)
    {
        if(![consumed containsObject:application])
        {
            [result addObject:application];
        }
    }

    return result;
}

- (UIImage *)folderIconForChildren:(NSArray<NXROMApplication *> *)children
{
    CGFloat size = 180.0;
    CGFloat inner = 46.0;
    CGFloat gap = 6.0;

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGRect rect = CGRectMake(0, 0, size, size);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:size * NXROMIconCornerRatio];
        [[UIColor colorWithWhite:1.0 alpha:0.18] setFill];
        [path fill];

        CGFloat startX = (size - (inner * 3.0 + gap * 2.0)) / 2.0;
        CGFloat startY = startX;

        for(NSUInteger index = 0; index < MIN(children.count, (NSUInteger)9); index++)
        {
            NSUInteger column = index % 3;
            NSUInteger row = index / 3;
            CGRect frame = CGRectMake(startX + (inner + gap) * (CGFloat)column,
                                      startY + (inner + gap) * (CGFloat)row,
                                      inner, inner);
            UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:inner * NXROMIconCornerRatio];
            CGContextSaveGState(context.CGContext);
            [clip addClip];
            [children[index].icon drawInRect:frame];
            CGContextRestoreGState(context.CGContext);
        }
    }];
}

- (nullable NXROMApplication *)applicationAtBundlePath:(NSString *)bundlePath fromROM:(BOOL)fromROM
{
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSDictionary *info = bundle.infoDictionary;

    if(info == nil)
    {
        info = [NSDictionary dictionaryWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"Info.plist"]];
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
    application.kind = NXROMAppKindGuest;
    application.bundleIdentifier = identifier;
    application.bundlePath = bundlePath;
    application.executablePath = executablePath;
    application.displayName = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: identifier;
    application.fromROM = fromROM;
    application.icon = [self iconForBundlePath:bundlePath info:info identifier:identifier title:application.displayName];
    return application;
}

- (nullable UIImage *)iconForBundlePath:(NSString *)bundlePath
                                   info:(NSDictionary *)info
                             identifier:(NSString *)identifier
                                  title:(NSString *)title
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
    [candidates addObjectsFromArray:@[ @"AppIcon60x60@2x.png", @"AppIcon60x60@3x.png", @"Icon@2x.png", @"Icon.png" ]];

    for(NSString *name in candidates)
    {
        for(NSString *candidate in @[ name, [name stringByAppendingString:@".png"] ])
        {
            UIImage *image = [UIImage imageWithContentsOfFile:[bundlePath stringByAppendingPathComponent:candidate]];
            if(image != nil)
            {
                self.iconCache[identifier] = image;
                return image;
            }
        }
    }

    UIImage *placeholder = [NXROMDesign placeholderIconWithTitle:title size:180.0];
    self.iconCache[identifier] = placeholder;
    return placeholder;
}

- (nullable NXROMApplication *)applicationWithBuiltinIdentifier:(NSString *)identifier
{
    for(NXROMApplication *application in self.builtins)
    {
        if([application.builtinIdentifier isEqualToString:identifier])
        {
            return application;
        }
    }
    return nil;
}

- (pid_t)launchApplication:(NXROMApplication *)application
{
    if(application.kind != NXROMAppKindGuest || application.executablePath.length == 0)
    {
        return -1;
    }

    NSDictionary *items = @{
        @"PEExecutablePath": application.executablePath,
        @"PEArguments": @[ application.executablePath ],
        @"PEWorkingDirectory": application.bundlePath ?: NSHomeDirectory(),
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
        return pid;
    }

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
