/*
 * NXROMAppRegistry.h — ROM 里的"已安装应用"扫描 + 启动
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NXROMApplication : NSObject

@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *bundlePath;
@property (nonatomic, copy) NSString *executablePath;
@property (nonatomic, assign, getter=isFromROM) BOOL fromROM;
@property (nonatomic, strong, nullable) UIImage *icon;

@end

@interface NXROMAppRegistry : NSObject

+ (instancetype)shared;

/* 重新扫描 rootfs/Application 与 Cache/Payload 下的 .app */
- (NSArray<NXROMApplication *> *)reload;

/* 当前列表（含缓存的图标） */
@property (nonatomic, readonly) NSArray<NXROMApplication *> *applications;

/* 启动一个应用；成功返回 pid，失败返回 -1 */
- (pid_t)launchApplication:(NXROMApplication *)application;

- (NSArray<NSString *> *)scannedDirectories;

@end

NS_ASSUME_NONNULL_END
