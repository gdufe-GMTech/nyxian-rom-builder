/*
 * NXROMSystemInfo.h — 从 ksurface 读"内核"状态（只读）
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NXROMSystemInfo : NSObject

+ (BOOL)isKernelAvailable;
+ (NSString *)hostname;
+ (NSUInteger)processCount;
+ (NSUInteger)kextCount;
+ (NSArray<NSString *> *)kextIdentifiers;

/* 每项：@{@"pid": @(pid), @"name": NSString, @"uid": @(uid)} */
+ (NSArray<NSDictionary *> *)processes;
+ (NSString *)summary;

/* ROM 槽目录（Library/Boot/Slot/<A|B>），以及槽里 kexts/*.kext 的清单 */
+ (nullable NSString *)romSlotDirectory;

/* 每项：@{@"bundle": NSString, @"identifier": NSString, @"loaded": @(BOOL)} */
+ (NSArray<NSDictionary *> *)romKexts;

@end

NS_ASSUME_NONNULL_END
