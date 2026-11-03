/*
 * NXROMShellViewController.m
 */

#import "NXROMShellViewController.h"
#import "NXROMHomeViewController.h"
#import "NXROMSettingsViewController.h"

#import <LindChain/WindowServer/NXWindowServer.h>

@interface NXROMShellViewController ()
@property (nonatomic, readwrite) UIViewController *homeViewController;
@end

@implementation NXROMShellViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;

    NXROMHomeViewController *home = [[NXROMHomeViewController alloc] init];
    __weak typeof(self) weakSelf = self;
    home.openSettingsHandler = ^{
        [weakSelf presentSettings];
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
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)presentSettings
{
    NXROMSettingsViewController *settings = [[NXROMSettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settings];
    navigation.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void)presentAppSwitcher
{
    Class serverClass = NSClassFromString(@"NXWindowServer");
    if(serverClass == Nil || ![serverClass respondsToSelector:@selector(shared)])
    {
        return;
    }

    id server = [serverClass performSelector:@selector(shared)];
    if([server respondsToSelector:@selector(showAppSwitcherExternal)])
    {
        [server performSelector:@selector(showAppSwitcherExternal)];
    }
}

@end
