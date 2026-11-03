/*
 * NXROMBuiltinApps.h — ROM 内置系统 App（进程内视图控制器）
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NXROMClockViewController : UIViewController
@end

@interface NXROMCalculatorViewController : UIViewController
@end

@interface NXROMFilesViewController : UIViewController

- (instancetype)initWithPath:(nullable NSString *)path;

@end

NS_ASSUME_NONNULL_END
