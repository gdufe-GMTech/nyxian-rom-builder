/*
 * NXROMLockScreenViewController.h
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NXROMLockScreenViewController : UIViewController

@property (nonatomic, copy, nullable) void (^unlockHandler)(void);
@property (nonatomic, assign) BOOL locked;   /* 重新上锁时刷新时间 */

- (void)refreshClock;

@end

NS_ASSUME_NONNULL_END
