/*
 * NXROMLockScreenViewController.m
 *
 * iOS 26/27 风格锁屏：
 *   日期 → 大号细体时间 → “无闹钟” 玻璃胶囊
 *   底部：手电筒 / 相机圆形玻璃按钮 + 中间“勿扰模式”玻璃胶囊，上滑解锁
 *
 * 玻璃一律走系统的 UIGlassEffect（NXROMDesign 封装，老系统退回 UIBlurEffect），
 * 不再自绘遮罩——上一版用 CGContextClipToMask 做“玻璃数字”，坐标系搞反导致数字镜像。
 */

#import "NXROMLockScreenViewController.h"
#import "NXROMDesign.h"
#import <CoreText/CoreText.h>

@interface NXROMLockScreenViewController () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) CAGradientLayer *scrimLayer;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *unlockHintLabel;
@property (nonatomic, strong) UIVisualEffectView *alarmPill;
@property (nonatomic, strong) UIVisualEffectView *dndPill;
@property (nonatomic, strong) UIVisualEffectView *flashlightGlass;
@property (nonatomic, strong) UIVisualEffectView *cameraGlass;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) UIPanGestureRecognizer *pan;
@property (nonatomic, assign) CGPoint panOrigin;

@end

@implementation NXROMLockScreenViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;
    [NXROMDesign applyWallpaperToView:self.view];

    /* 上下压暗，保证白色文字在任何壁纸上都可读 */
    CAGradientLayer *scrim = [CAGradientLayer layer];
    scrim.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.45].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.35].CGColor,
    ];
    scrim.locations = @[ @0.0, @0.45, @1.0 ];
    scrim.startPoint = CGPointMake(0.5, 0.0);
    scrim.endPoint = CGPointMake(0.5, 1.0);
    scrim.frame = self.view.bounds;
    [self.view.layer addSublayer:scrim];
    self.scrimLayer = scrim;

    [self buildClock];
    [self buildPills];
    [self buildBottomControls];

    self.pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    self.pan.delegate = self;
    [self.view addGestureRecognizer:self.pan];

    [self refreshClock];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                  target:self
                                                selector:@selector(refreshClock)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.scrimLayer.frame = self.view.bounds;
}

- (void)dealloc
{
    [self.timer invalidate];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - 构成

- (UIFont *)clockFontWithSize:(CGFloat)size
{
    UIFont *font = [UIFont systemFontOfSize:size weight:UIFontWeightLight];
    /* 等宽数字，避免每分钟跳宽 */
    UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorByAddingAttributes:@{
        UIFontDescriptorFeatureSettingsAttribute: @[
            @{
                UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
                UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector),
            },
        ],
    }];
    return [UIFont fontWithDescriptor:descriptor size:size];
}

- (void)buildClock
{
    self.dateLabel = [UILabel new];
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dateLabel.textAlignment = NSTextAlignmentCenter;
    self.dateLabel.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightSemibold];
    self.dateLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.82];
    [self.view addSubview:self.dateLabel];

    self.timeLabel = [UILabel new];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.textAlignment = NSTextAlignmentCenter;
    self.timeLabel.font = [self clockFontWithSize:96.0];
    self.timeLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.94];
    self.timeLabel.adjustsFontSizeToFitWidth = YES;
    self.timeLabel.minimumScaleFactor = 0.6;
    [self.view addSubview:self.timeLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.dateLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.dateLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:56.0],

        [self.timeLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.timeLabel.topAnchor constraintEqualToAnchor:self.dateLabel.bottomAnchor constant:2.0],
        [self.timeLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.timeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-16.0],
    ]];
}

- (void)buildPills
{
    /* 无闹钟 */
    self.alarmPill = [NXROMDesign glassViewWithCornerRadius:20.0 style:1 interactive:NO];
    [self.view addSubview:self.alarmPill];

    UIImageView *bell = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"alarm"]];
    bell.translatesAutoresizingMaskIntoConstraints = NO;
    bell.tintColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    bell.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                        weight:UIImageSymbolWeightSemibold];
    [self.alarmPill.contentView addSubview:bell];

    UILabel *alarmLabel = [UILabel new];
    alarmLabel.translatesAutoresizingMaskIntoConstraints = NO;
    alarmLabel.text = @"无闹钟";
    alarmLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    alarmLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    [self.alarmPill.contentView addSubview:alarmLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.alarmPill.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.alarmPill.topAnchor constraintEqualToAnchor:self.timeLabel.bottomAnchor constant:14.0],
        [self.alarmPill.heightAnchor constraintEqualToConstant:40.0],

        [bell.leadingAnchor constraintEqualToAnchor:self.alarmPill.contentView.leadingAnchor constant:16.0],
        [bell.centerYAnchor constraintEqualToAnchor:self.alarmPill.contentView.centerYAnchor],

        [alarmLabel.leadingAnchor constraintEqualToAnchor:bell.trailingAnchor constant:6.0],
        [alarmLabel.trailingAnchor constraintEqualToAnchor:self.alarmPill.contentView.trailingAnchor constant:-16.0],
        [alarmLabel.centerYAnchor constraintEqualToAnchor:self.alarmPill.contentView.centerYAnchor],
    ]];
}

- (UIVisualEffectView *)circleGlassButtonWithSymbol:(NSString *)symbol action:(SEL)action
{
    UIVisualEffectView *glass = [NXROMDesign glassViewWithCornerRadius:26.0 style:1 interactive:YES];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    icon.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                                                        weight:UIImageSymbolWeightMedium];
    [glass.contentView addSubview:icon];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [glass.contentView addSubview:button];

    [NSLayoutConstraint activateConstraints:@[
        [icon.centerXAnchor constraintEqualToAnchor:glass.contentView.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:glass.contentView.centerYAnchor],
        [button.leadingAnchor constraintEqualToAnchor:glass.contentView.leadingAnchor],
        [button.trailingAnchor constraintEqualToAnchor:glass.contentView.trailingAnchor],
        [button.topAnchor constraintEqualToAnchor:glass.contentView.topAnchor],
        [button.bottomAnchor constraintEqualToAnchor:glass.contentView.bottomAnchor],
    ]];

    return glass;
}

- (void)buildBottomControls
{
    self.flashlightGlass = [self circleGlassButtonWithSymbol:@"flashlight.off.fill" action:@selector(flashlightTapped)];
    self.cameraGlass = [self circleGlassButtonWithSymbol:@"camera.fill" action:@selector(cameraTapped)];
    [self.view addSubview:self.flashlightGlass];
    [self.view addSubview:self.cameraGlass];

    self.dndPill = [NXROMDesign glassViewWithCornerRadius:22.0 style:1 interactive:YES];
    [self.view addSubview:self.dndPill];

    UIImageView *moon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"moon.fill"]];
    moon.translatesAutoresizingMaskIntoConstraints = NO;
    moon.tintColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    moon.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                        weight:UIImageSymbolWeightSemibold];
    [self.dndPill.contentView addSubview:moon];

    UILabel *dndLabel = [UILabel new];
    dndLabel.translatesAutoresizingMaskIntoConstraints = NO;
    dndLabel.text = @"勿扰模式";
    dndLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    dndLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    [self.dndPill.contentView addSubview:dndLabel];

    self.unlockHintLabel = [UILabel new];
    self.unlockHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.unlockHintLabel.text = @"上滑解锁";
    self.unlockHintLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.unlockHintLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
    [self.view addSubview:self.unlockHintLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.flashlightGlass.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:26.0],
        [self.flashlightGlass.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-34.0],
        [self.flashlightGlass.widthAnchor constraintEqualToConstant:52.0],
        [self.flashlightGlass.heightAnchor constraintEqualToConstant:52.0],

        [self.cameraGlass.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-26.0],
        [self.cameraGlass.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-34.0],
        [self.cameraGlass.widthAnchor constraintEqualToConstant:52.0],
        [self.cameraGlass.heightAnchor constraintEqualToConstant:52.0],

        [self.dndPill.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.dndPill.centerYAnchor constraintEqualToAnchor:self.flashlightGlass.centerYAnchor],
        [self.dndPill.heightAnchor constraintEqualToConstant:44.0],

        [moon.leadingAnchor constraintEqualToAnchor:self.dndPill.contentView.leadingAnchor constant:16.0],
        [moon.centerYAnchor constraintEqualToAnchor:self.dndPill.contentView.centerYAnchor],

        [dndLabel.leadingAnchor constraintEqualToAnchor:moon.trailingAnchor constant:6.0],
        [dndLabel.trailingAnchor constraintEqualToAnchor:self.dndPill.contentView.trailingAnchor constant:-16.0],
        [dndLabel.centerYAnchor constraintEqualToAnchor:self.dndPill.contentView.centerYAnchor],

        [self.unlockHintLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.unlockHintLabel.bottomAnchor constraintEqualToAnchor:self.flashlightGlass.topAnchor constant:-22.0],
    ]];
}

#pragma mark - 时间

- (void)refreshClock
{
    NSDate *now = NSDate.date;

    NSDateFormatter *timeFormatter = [NSDateFormatter new];
    timeFormatter.dateFormat = @"HH:mm";
    self.timeLabel.text = [timeFormatter stringFromDate:now];

    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_Hans_CN"];
    dateFormatter.dateFormat = @"M月d日EEEE";
    NSString *date = [dateFormatter stringFromDate:now];
    self.dateLabel.text = [date stringByReplacingOccurrencesOfString:@"星期" withString:@"周"];
}

- (void)setLocked:(BOOL)locked
{
    _locked = locked;
    if (locked)
    {
        [self refreshClock];
    }
}

#pragma mark - 按钮

- (void)flashlightTapped
{
    [NXROMDesign mediumImpact];
}

- (void)cameraTapped
{
    [NXROMDesign mediumImpact];
}

#pragma mark - 上滑解锁

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    /* 让底部玻璃按钮先拿到点击 */
    UIView *view = touch.view;
    while (view != nil)
    {
        if ([view isKindOfClass:UIControl.class])
        {
            return NO;
        }
        view = view.superview;
    }
    return YES;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan
{
    CGPoint translation = [pan translationInView:self.view];

    switch (pan.state)
    {
        case UIGestureRecognizerStateBegan:
            self.panOrigin = self.view.center;
            break;

        case UIGestureRecognizerStateChanged:
        {
            CGFloat offset = MIN(0.0, translation.y);
            self.view.center = CGPointMake(self.panOrigin.x, self.panOrigin.y + offset);
            CGFloat progress = MIN(1.0, -offset / 220.0);
            self.view.alpha = 1.0 - progress * 0.35;
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            BOOL shouldUnlock = (translation.y < -90.0 || [pan velocityInView:self.view].y < -600.0);
            if (shouldUnlock)
            {
                [NXROMDesign lightImpact];
                if (self.unlockHandler)
                {
                    self.unlockHandler();
                }
                self.view.center = self.panOrigin;
                self.view.alpha = 1.0;
            }
            else
            {
                [UIView animateWithDuration:0.32
                                      delay:0.0
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                                     self.view.center = self.panOrigin;
                                     self.view.alpha = 1.0;
                                 }
                                 completion:nil];
            }
            break;
        }

        default:
            break;
    }
}

@end
