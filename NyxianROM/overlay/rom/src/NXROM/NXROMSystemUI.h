/*
 * NXROMSystemUI.h — 控制中心与 App 切换器
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NXROMControlCenterViewController : UIViewController

@property (nonatomic, copy, nullable) void (^openCalculatorHandler)(void);
@property (nonatomic, copy, nullable) void (^dismissHandler)(void);

@end

@interface NXROMAppSwitcherViewController : UIViewController

@property (nonatomic, copy, nullable) void (^dismissHandler)(void);

@end

NS_ASSUME_NONNULL_END
