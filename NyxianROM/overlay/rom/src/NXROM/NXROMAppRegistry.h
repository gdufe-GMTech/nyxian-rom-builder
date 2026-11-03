/*
 * NXROMAppRegistry.h — 桌面条目来源
 *
 * 条目分两类：
 *   guest   从 Application/*.app 扫描出来的真实应用（走 PEProcessManager 启动）
 *   builtin 编进 ROM 的系统 App（进程内视图控制器，由外壳直接呈现）
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NXROMAppKind) {
    NXROMAppKindGuest = 0,
    NXROMAppKindBuiltin = 1,
    NXROMAppKindFolder = 2,
};

@interface NXROMApplication : NSObject

@property (nonatomic) NXROMAppKind kind;
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *bundlePath;
@property (nonatomic, copy, nullable) NSString *executablePath;
@property (nonatomic, assign, getter=isFromROM) BOOL fromROM;
@property (nonatomic, strong, nullable) UIImage *icon;

/* builtin 专用 */
@property (nonatomic, copy, nullable) NSString *builtinIdentifier;
@property (nonatomic, copy, nullable) NSString *symbolName;
@property (nonatomic, strong, nullable) UIColor *tintColor;

/* folder 专用：图标由子项预览合成 */
@property (nonatomic, copy, nullable) NSArray<NXROMApplication *> *children;

@end

@interface NXROMAppRegistry : NSObject

+ (instancetype)shared;

/* 重新扫描；返回系统 App + guest 应用 */
- (NSArray<NXROMApplication *> *)reload;

@property (nonatomic, readonly) NSArray<NXROMApplication *> *applications;

/* 仅 guest：启动进程并开窗，返回 pid，失败返回 -1 */
- (pid_t)launchApplication:(NXROMApplication *)application;

- (nullable NXROMApplication *)applicationWithBuiltinIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
