/*
 * NXROMShellViewController.h — ROM 的外壳：桌面 + 设置
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NXROMShellViewController : UIViewController

@property (nonatomic, readonly) UIViewController *homeViewController;

- (void)presentSettings;
- (void)presentAppSwitcher;

@end

NS_ASSUME_NONNULL_END
