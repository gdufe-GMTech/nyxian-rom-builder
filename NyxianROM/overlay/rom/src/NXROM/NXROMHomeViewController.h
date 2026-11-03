/*
 * NXROMHomeViewController.h — ROM 桌面（图标网格 + Dock + 时钟）
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NXROMHomeViewController : UIViewController

/* 重新扫描应用并刷新网格 */
- (void)reloadApplications;

@property (nonatomic, copy, nullable) void (^openSettingsHandler)(void);
@property (nonatomic, copy, nullable) void (^openAppSwitcherHandler)(void);

@end

NS_ASSUME_NONNULL_END
