/*
 * NXROMLockScreenViewController.m
 *
 * 版式参照 iOS 26/27 锁屏：
 *   状态栏由系统提供（不隐藏）
 *   日期（18pt 半粗）在上，大号玻璃质感时间（约 96pt）在下
 *   底部左右各一个圆形毛玻璃按钮（手电筒 / 相机）
 *   上滑解锁
 */

#import "NXROMLockScreenViewController.h"
#import "NXROMDesign.h"

#pragma mark - 玻璃质感时间

@interface NXROMGlassTimeView : UIView

@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) void (^flashlightHandler)(void);
@property (nonatomic, copy) void (^cameraHandler)(void);

@end

@implementation NXROMGlassTimeView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)setText:(NSString *)text
{
    _text = [text copy];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    if(self.text.length == 0)
    {
        return;
    }

    CGContextRef context = UIGraphicsGetCurrentContext();
    if(context == NULL)
    {
        return;
    }

    UIFont *font = [UIFont systemFontOfSize:CGRectGetHeight(rect) * 0.86 weight:UIFontWeightBold];
    NSDictionary *attributes = @{ NSFontAttributeName: font };

    CGSize textSize = [self.text sizeWithAttributes:attributes];
    CGRect textRect = CGRectMake((CGRectGetWidth(rect) - textSize.width) / 2.0,
                                 (CGRectGetHeight(rect) - textSize.height) / 2.0,
                                 textSize.width, textSize.height);

    /* 先把字形画进一层遮罩，再用渐变填充，模拟玻璃折射的通透文字 */
    UIGraphicsBeginImageContextWithOptions(textSize, NO, 0);
    [self.text drawAtPoint:CGPointZero withAttributes:attributes];
    UIImage *glyphMask = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMinX(textRect), CGRectGetMinY(textRect));

    CGContextClipToMask(context, CGRectMake(0, 0, textSize.width, textSize.height), glyphMask.CGImage);

    CGGradientRef gradient = CGGradientCreateWithColors(NULL, (__bridge CFArrayRef)@[
        (id)[UIColor colorWithWhite:1.0 alpha:0.97].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.72].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.86].CGColor,
    ], (CGFloat[]){ 0.0, 0.55, 1.0 });

    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(0, 0),
                                CGPointMake(0, textSize.height),
                                0);
    CGGradientRelease(gradient);

    CGContextRestoreGState(context);
}

@end

#pragma mark - 锁屏

@interface NXROMLockScreenViewController () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) NXROMGlassTimeView *timeView;
@property (nonatomic, strong) UIImageView *lockIcon;
@property (nonatomic, strong) UIButton *flashlightButton;
@property (nonatomic, strong) UIButton *cameraButton;
@property (nonatomic, strong) UIView *homeIndicator;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) UIPanGestureRecognizer *pan;

@end

@implementation NXROMLockScreenViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [NXROMDesign applyWallpaperToView:self.view];

    self.lockIcon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"lock.fill"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                weight:UIImageSymbolWeightSemibold]]];
    self.lockIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.lockIcon.tintColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    self.lockIcon.contentMode = UIViewContentModeScaleAspectFit;

    self.dateLabel = [UILabel new];
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dateLabel.textAlignment = NSTextAlignmentCenter;
    self.dateLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    self.dateLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.94];

    self.timeView = [[NXROMGlassTimeView alloc] initWithFrame:CGRectZero];
    self.timeView.translatesAutoresizingMaskIntoConstraints = NO;

    self.flashlightButton = [self glassButtonWithSymbol:@"flashlight.off.fill"];
    [self.flashlightButton addTarget:self action:@selector(flashlightTapped) forControlEvents:UIControlEventTouchUpInside];

    self.cameraButton = [self glassButtonWithSymbol:@"camera.fill"];
    [self.cameraButton addTarget:self action:@selector(cameraTapped) forControlEvents:UIControlEventTouchUpInside];

    self.homeIndicator = [UIView new];
    self.homeIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.homeIndicator.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.82];
    self.homeIndicator.layer.cornerRadius = 2.5;
    self.homeIndicator.layer.cornerCurve = kCACornerCurveContinuous;

    for(UIView *view in @[ self.lockIcon, self.dateLabel, self.timeView,
                           self.flashlightButton, self.cameraButton, self.homeIndicator ])
    {
        [self.view addSubview:view];
    }

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.lockIcon.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.lockIcon.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10.0],
        [self.lockIcon.widthAnchor constraintEqualToConstant:16.0],
        [self.lockIcon.heightAnchor constraintEqualToConstant:18.0],

        [self.dateLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.dateLabel.topAnchor constraintEqualToAnchor:self.lockIcon.bottomAnchor constant:22.0],

        [self.timeView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.timeView.topAnchor constraintEqualToAnchor:self.dateLabel.bottomAnchor constant:-8.0],
        [self.timeView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12.0],
        [self.timeView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12.0],
        [self.timeView.heightAnchor constraintEqualToConstant:116.0],

        [self.flashlightButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:44.0],
        [self.flashlightButton.bottomAnchor constraintEqualToAnchor:self.homeIndicator.topAnchor constant:-44.0],
        [self.flashlightButton.widthAnchor constraintEqualToConstant:46.0],
        [self.flashlightButton.heightAnchor constraintEqualToConstant:46.0],

        [self.cameraButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-44.0],
        [self.cameraButton.centerYAnchor constraintEqualToAnchor:self.flashlightButton.centerYAnchor],
        [self.cameraButton.widthAnchor constraintEqualToConstant:46.0],
        [self.cameraButton.heightAnchor constraintEqualToConstant:46.0],

        [self.homeIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.homeIndicator.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8.0],
        [self.homeIndicator.widthAnchor constraintEqualToConstant:134.0],
        [self.homeIndicator.heightAnchor constraintEqualToConstant:5.0],
    ]];

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

- (void)dealloc
{
    [self.timer invalidate];
}

- (UIButton *)glassButtonWithSymbol:(NSString *)symbol
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.42];
    button.layer.cornerRadius = 23.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.tintColor = [UIColor colorWithWhite:1.0 alpha:0.92];

    UIImage *image = [UIImage systemImageNamed:symbol];
    [button setImage:image forState:UIControlStateNormal];
    [button setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                                                            weight:UIImageSymbolWeightMedium]
                                   forState:UIControlStateNormal];
    return button;
}

- (void)refreshClock
{
    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    timeFormatter.dateFormat = @"HH:mm";
    self.timeView.text = [timeFormatter stringFromDate:NSDate.date];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_Hans_CN"];
    dateFormatter.dateFormat = @"M月d日EEEE";
    NSString *date = [dateFormatter stringFromDate:NSDate.date];
    self.dateLabel.text = [date stringByReplacingOccurrencesOfString:@"星期" withString:@"周"];
}

- (void)setLocked:(BOOL)locked
{
    _locked = locked;
    [self refreshClock];
}

#pragma mark - 按钮

- (void)flashlightTapped
{
    [NXROMDesign lightImpact];
    self.flashlightButton.selected = !self.flashlightButton.isSelected;
    self.flashlightButton.backgroundColor = self.flashlightButton.isSelected
        ? [UIColor colorWithWhite:1.0 alpha:0.9]
        : [UIColor colorWithWhite:0.12 alpha:0.42];
    self.flashlightButton.tintColor = self.flashlightButton.isSelected
        ? UIColor.blackColor
        : [UIColor colorWithWhite:1.0 alpha:0.92];
}

- (void)cameraTapped
{
    [NXROMDesign lightImpact];
}

#pragma mark - 上滑解锁

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    /* 按钮区域交给按钮自身处理 */
    for(UIButton *button in @[ self.flashlightButton, self.cameraButton ])
    {
        if([touch.view isDescendantOfView:button])
        {
            return NO;
        }
    }
    return YES;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan
{
    CGPoint translation = [pan translationInView:self.view];
    CGFloat progress = MAX(0.0, -translation.y / 240.0);

    switch(pan.state)
    {
        case UIGestureRecognizerStateChanged:
        {
            CGFloat offset = MAX(MIN(translation.y, 0.0), -320.0);
            self.view.transform = CGAffineTransformMakeTranslation(0, offset);
            self.view.alpha = 1.0 - progress * 0.55;
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            BOOL unlock = progress > 0.35 || [pan velocityInView:self.view].y < -900.0;
            [UIView animateWithDuration:0.28
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                self.view.transform = CGAffineTransformIdentity;
                self.view.alpha = 1.0;
            }
                             completion:nil];

            if(unlock)
            {
                [NXROMDesign mediumImpact];
                if(self.unlockHandler)
                {
                    self.unlockHandler();
                }
            }
            break;
        }
        default:
            break;
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end
