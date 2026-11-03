/*
 * NXROMShellViewController.h — 外壳：锁屏、主屏、系统 UI 与全屏应用转场
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NXROMShellViewController : UIViewController

@property (nonatomic, readonly) UIViewController *homeViewController;

- (void)presentSettings;
- (void)presentAppSwitcher;

@end

NS_ASSUME_NONNULL_END
