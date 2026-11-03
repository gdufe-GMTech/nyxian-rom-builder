/*
 * NXROMShellViewController.m
 */

#import "NXROMShellViewController.h"
#import "NXROMHomeViewController.h"
#import "NXROMLockScreenViewController.h"
#import "NXROMSettingsViewController.h"
#import "NXROMSystemUI.h"
#import "NXROMBuiltinApps.h"
#import "NXROMAppRegistry.h"
#import "NXROMDesign.h"

#import <LindChain/WindowServer/NXWindowServer.h>
#import <LindChain/WindowServer/Window/NXWindow.h>

@interface NXROMShellViewController () <UIGestureRecognizerDelegate>

@property (nonatomic, readwrite) UIViewController *homeViewController;
@property (nonatomic, strong) NXROMLockScreenViewController *lockScreen;
@property (nonatomic, assign) BOOL unlocked;
@property (nonatomic, strong) UIScreenEdgePanGestureRecognizer *controlCenterGesture;
@property (nonatomic, strong) UIScreenEdgePanGestureRecognizer *appSwitcherGesture;

@end

@implementation NXROMShellViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;

    NXROMHomeViewController *home = [[NXROMHomeViewController alloc] init];
    __weak typeof(self) weakSelf = self;

    home.openApplicationHandler = ^(NXROMApplication *application, UIView *sourceView) {
        [weakSelf openApplication:application fromView:sourceView];
    };
    home.openControlCenterHandler = ^{
        [weakSelf presentControlCenter];
    };
    home.openAppSwitcherHandler = ^{
        [weakSelf presentAppSwitcher];
    };

    [self addChildViewController:home];
    home.view.frame = self.view.bounds;
    home.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:home.view];
    [home didMoveToParentViewController:self];
    self.homeViewController = home;

    [self buildLockScreen];
    [self buildGestures];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if(!self.unlocked)
    {
        self.controlCenterGesture.enabled = NO;
        self.appSwitcherGesture.enabled = NO;
    }
}

#pragma mark - 锁屏

- (void)buildLockScreen
{
    __weak typeof(self) weakSelf = self;

    NXROMLockScreenViewController *lock = [[NXROMLockScreenViewController alloc] init];
    lock.unlockHandler = ^{
        [weakSelf unlock];
    };

    [self addChildViewController:lock];
    lock.view.frame = self.view.bounds;
    lock.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:lock.view];
    [lock didMoveToParentViewController:self];
    self.lockScreen = lock;
}

- (void)unlock
{
    if(self.unlocked)
    {
        return;
    }
    self.unlocked = YES;
    self.controlCenterGesture.enabled = YES;
    self.appSwitcherGesture.enabled = YES;

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.36
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        weakSelf.lockScreen.view.alpha = 0.0;
        weakSelf.lockScreen.view.transform = CGAffineTransformMakeScale(1.06, 1.06);
        weakSelf.homeViewController.view.alpha = 1.0;
    }
                     completion:^(BOOL finished) {
        [weakSelf.lockScreen willMoveToParentViewController:nil];
        [weakSelf.lockScreen.view removeFromSuperview];
        [weakSelf.lockScreen removeFromParentViewController];
        weakSelf.lockScreen = nil;
    }];
}

#pragma mark - 手势

- (void)buildGestures
{
    UIScreenEdgePanGestureRecognizer *controlCenter =
        [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleControlCenterGesture:)];
    controlCenter.edges = UIRectEdgeTop;
    controlCenter.delegate = self;
    [self.view addGestureRecognizer:controlCenter];
    self.controlCenterGesture = controlCenter;

    UIScreenEdgePanGestureRecognizer *switcher =
        [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwitcherGesture:)];
    switcher.edges = UIRectEdgeBottom;
    switcher.delegate = self;
    [self.view addGestureRecognizer:switcher];
    self.appSwitcherGesture = switcher;
}

- (void)handleControlCenterGesture:(UIScreenEdgePanGestureRecognizer *)gesture
{
    if(gesture.state == UIGestureRecognizerStateEnded)
    {
        [self presentControlCenter];
    }
}

- (void)handleSwitcherGesture:(UIScreenEdgePanGestureRecognizer *)gesture
{
    if(gesture.state != UIGestureRecognizerStateEnded)
    {
        return;
    }

    CGPoint velocity = [gesture velocityInView:self.view];
    if(velocity.y < -400.0)
    {
        [self presentAppSwitcher];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other
{
    return NO;
}

#pragma mark - 系统 UI

- (void)presentControlCenter
{
    if(!self.unlocked || self.presentedViewController != nil)
    {
        return;
    }

    __weak typeof(self) weakSelf = self;

    NXROMControlCenterViewController *controlCenter = [[NXROMControlCenterViewController alloc] init];
    controlCenter.modalPresentationStyle = UIModalPresentationOverFullScreen;
    controlCenter.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    controlCenter.dismissHandler = ^{
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };
    controlCenter.openCalculatorHandler = ^{
        NXROMApplication *application = [[NXROMAppRegistry shared] applicationWithBuiltinIdentifier:@"calculator"];
        if(application != nil)
        {
            [weakSelf openApplication:application fromView:nil];
        }
    };

    [self presentViewController:controlCenter animated:YES completion:nil];
}

- (void)presentAppSwitcher
{
    if(!self.unlocked || self.presentedViewController != nil)
    {
        return;
    }

    __weak typeof(self) weakSelf = self;

    NXROMAppSwitcherViewController *switcher = [[NXROMAppSwitcherViewController alloc] init];
    switcher.modalPresentationStyle = UIModalPresentationOverFullScreen;
    switcher.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    switcher.dismissHandler = ^{
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };

    [self presentViewController:switcher animated:YES completion:nil];
}

- (void)presentSettings
{
    NXROMApplication *application = [[NXROMAppRegistry shared] applicationWithBuiltinIdentifier:@"settings"];
    if(application != nil)
    {
        [self openApplication:application fromView:nil];
    }
}

#pragma mark - 打开应用

- (void)openApplication:(NXROMApplication *)application fromView:(nullable UIView *)sourceView
{
    if(application == nil)
    {
        return;
    }

    [NXROMDesign lightImpact];

    if(application.kind == NXROMAppKindBuiltin)
    {
        UIViewController *controller = [self viewControllerForBuiltin:application];
        if(controller == nil)
        {
            return;
        }

        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:controller];
        navigation.modalPresentationStyle = UIModalPresentationFullScreen;
        navigation.navigationBarHidden = ([application.builtinIdentifier isEqualToString:@"calculator"] ||
                                          [application.builtinIdentifier isEqualToString:@"clock"]);

        [self presentZoomed:navigation fromView:sourceView];
        return;
    }

    /* guest 应用：走 ksurface 进程模型，在窗口服务器里开窗 */
    pid_t pid = [[NXROMAppRegistry shared] launchApplication:application];
    if(pid < 0)
    {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法启动"
                                                                      message:application.displayName
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    /* 开窗后自动最大化，接近 iOS 的全屏应用观感 */
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NXWindowServer *server = [NXWindowServer shared];
        NSNumber *identifier = server.windowOrder.lastObject;
        if(identifier == nil)
        {
            return;
        }
        NXWindow *window = server.windows[identifier];
        if([window respondsToSelector:@selector(maximizeWindow:)])
        {
            [window maximizeWindow:YES];
        }
    });
}

- (nullable UIViewController *)viewControllerForBuiltin:(NXROMApplication *)application
{
    NSString *identifier = application.builtinIdentifier ?: @"";

    if([identifier isEqualToString:@"settings"])
    {
        return [[NXROMSettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    }
    if([identifier isEqualToString:@"clock"])
    {
        return [[NXROMClockViewController alloc] init];
    }
    if([identifier isEqualToString:@"calculator"])
    {
        return [[NXROMCalculatorViewController alloc] init];
    }
    if([identifier isEqualToString:@"files"])
    {
        return [[NXROMFilesViewController alloc] initWithPath:nil];
    }
    return nil;
}

#pragma mark - 缩放转场

- (void)presentZoomed:(UIViewController *)controller fromView:(nullable UIView *)sourceView
{
    if(sourceView == nil || sourceView.window == nil)
    {
        [self presentViewController:controller animated:YES completion:nil];
        return;
    }

    CGRect startFrame = [sourceView.window convertRect:sourceView.bounds fromView:sourceView];
    CGFloat screenWidth = CGRectGetWidth(self.view.bounds);
    CGFloat screenHeight = CGRectGetHeight(self.view.bounds);

    CGFloat scaleX = MAX(0.05, CGRectGetWidth(startFrame) / MAX(1.0, screenWidth));
    CGFloat scaleY = MAX(0.05, CGRectGetHeight(startFrame) / MAX(1.0, screenHeight));

    CGFloat offsetX = CGRectGetMidX(startFrame) - screenWidth / 2.0;
    CGFloat offsetY = CGRectGetMidY(startFrame) - screenHeight / 2.0;

    CGAffineTransform startTransform =
        CGAffineTransformMakeTranslation(offsetX, offsetY);
    startTransform = CGAffineTransformScale(startTransform, scaleX, scaleY);

    controller.view.transform = startTransform;
    controller.view.alpha = 0.0;
    controller.view.layer.cornerRadius = 26.0;
    controller.view.layer.cornerCurve = kCACornerCurveContinuous;
    controller.view.clipsToBounds = YES;

    [self presentViewController:controller animated:NO completion:^{
        [UIView animateWithDuration:0.42
                              delay:0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            controller.view.transform = CGAffineTransformIdentity;
            controller.view.alpha = 1.0;
            controller.view.layer.cornerRadius = 0.0;
        }
                         completion:nil];
    }];
}

#pragma mark - 状态栏

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

@end
