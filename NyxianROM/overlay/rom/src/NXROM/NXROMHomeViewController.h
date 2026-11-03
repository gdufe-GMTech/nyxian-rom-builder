/*
 * NXROMHomeViewController.h — 主屏
 */

#import <UIKit/UIKit.h>
#import "NXROMAppRegistry.h"

NS_ASSUME_NONNULL_BEGIN

@interface NXROMHomeViewController : UIViewController

/* 点击图标：sourceView 用于缩放转场的起点 */
@property (nonatomic, copy, nullable) void (^openApplicationHandler)(NXROMApplication *application, UIView *sourceView);
@property (nonatomic, copy, nullable) void (^openControlCenterHandler)(void);
@property (nonatomic, copy, nullable) void (^openAppSwitcherHandler)(void);

- (void)reloadApplications;
- (void)exitEditingIfNeeded;

@end

NS_ASSUME_NONNULL_END
