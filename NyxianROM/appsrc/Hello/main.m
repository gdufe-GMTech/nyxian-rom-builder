/*
 * Hello.app — ROM 里的示例 guest 应用
 *
 * 它证明三件事同时成立：
 *   1. ROM 里的 .app 能被 PEProcessManager 拉起来
 *   2. 它的界面能通过 NXWindowSessionApplication 挂进 Nyxian 的窗口
 *   3. 它调用的 libSystem 走的是 ksurface 的 syscall proxy
 */

#import <UIKit/UIKit.h>

@interface NXHelloViewController : UIViewController
@end

@implementation NXHelloViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"Hello";

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = UIColor.systemIndigoColor;
    [icon.widthAnchor constraintEqualToConstant:64.0].active = YES;
    [icon.heightAnchor constraintEqualToConstant:64.0].active = YES;

    UILabel *title = [UILabel new];
    title.text = @"Hello from ROM";
    title.font = [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *subtitle = [UILabel new];
    subtitle.text = [NSString stringWithFormat:@"%@ · iOS %@\npid %d",
                     UIDevice.currentDevice.model,
                     UIDevice.currentDevice.systemVersion,
                     getpid()];
    subtitle.numberOfLines = 0;
    subtitle.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    subtitle.textColor = UIColor.secondaryLabelColor;
    subtitle.textAlignment = NSTextAlignmentCenter;

    UILabel *hint = [UILabel new];
    hint.text = @"如果你看到这个界面，说明：\nROM 槽 → ksurface → NSExtension → dyld → UIScene 这条链路是通的。";
    hint.numberOfLines = 0;
    hint.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    hint.textColor = UIColor.tertiaryLabelColor;
    hint.textAlignment = NSTextAlignmentCenter;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ icon, title, subtitle, hint ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 16.0;
    [self.view addSubview:stack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:28.0],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-28.0],
        [stack.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
    ]];
}

@end

@interface NXHelloAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation NXHelloAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[NXHelloViewController new]];
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool
    {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(NXHelloAppDelegate.class));
    }
}
