/*
 * NXROMHomeViewController.m
 */

#import "NXROMHomeViewController.h"
#import "NXROMAppRegistry.h"

#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>

@interface NXROMAppCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *iconBackground;
@property (nonatomic, strong) UILabel *fallbackLabel;
- (void)configureWithApplication:(NXROMApplication *)application;
@end

@implementation NXROMAppCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        _iconBackground = [[UIView alloc] init];
        _iconBackground.translatesAutoresizingMaskIntoConstraints = NO;
        _iconBackground.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        _iconBackground.layer.cornerRadius = 15.0;
        _iconBackground.layer.cornerCurve = kCACornerCurveContinuous;
        _iconBackground.clipsToBounds = YES;
        [self.contentView addSubview:_iconBackground];

        _iconView = [[UIImageView alloc] init];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFill;
        _iconView.clipsToBounds = YES;
        _iconView.layer.cornerRadius = 15.0;
        _iconView.layer.cornerCurve = kCACornerCurveContinuous;
        [_iconBackground addSubview:_iconView];

        _fallbackLabel = [[UILabel alloc] init];
        _fallbackLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fallbackLabel.font = [UIFont systemFontOfSize:30.0 weight:UIFontWeightSemibold];
        _fallbackLabel.textAlignment = NSTextAlignmentCenter;
        _fallbackLabel.textColor = UIColor.whiteColor;
        [_iconBackground addSubview:_fallbackLabel];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.92];
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconBackground.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
            [_iconBackground.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:2.0],
            [_iconBackground.widthAnchor constraintEqualToConstant:62.0],
            [_iconBackground.heightAnchor constraintEqualToConstant:62.0],

            [_iconView.leadingAnchor constraintEqualToAnchor:_iconBackground.leadingAnchor],
            [_iconView.trailingAnchor constraintEqualToAnchor:_iconBackground.trailingAnchor],
            [_iconView.topAnchor constraintEqualToAnchor:_iconBackground.topAnchor],
            [_iconView.bottomAnchor constraintEqualToAnchor:_iconBackground.bottomAnchor],

            [_fallbackLabel.centerXAnchor constraintEqualToAnchor:_iconBackground.centerXAnchor],
            [_fallbackLabel.centerYAnchor constraintEqualToAnchor:_iconBackground.centerYAnchor],

            [_titleLabel.topAnchor constraintEqualToAnchor:_iconBackground.bottomAnchor constant:5.0],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:-2.0],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:2.0],
        ]];
    }
    return self;
}

- (void)configureWithApplication:(NXROMApplication *)application
{
    self.titleLabel.text = application.displayName;
    self.iconView.image = application.icon;
    self.fallbackLabel.hidden = (application.icon != nil);
    self.fallbackLabel.text = application.displayName.length > 0
        ? [application.displayName substringToIndex:1].uppercaseString
        : @"?";
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.12 animations:^{
        self.iconBackground.transform = highlighted
            ? CGAffineTransformMakeScale(0.9, 0.9)
            : CGAffineTransformIdentity;
    }];
}

@end

#pragma mark -

@interface NXROMHomeViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIView *dockView;
@property (nonatomic, strong) UILabel *clockLabel;
@property (nonatomic, strong) UILabel *hostLabel;
@property (nonatomic, strong) NSTimer *clockTimer;
@property (nonatomic, strong) NSArray<NXROMApplication *> *applications;
@property (nonatomic, strong) CAGradientLayer *wallpaperLayer;

- (void)buildWallpaper;
- (void)buildStatusBar;
- (void)buildCollectionView;
- (void)buildDock;
- (UIButton *)dockButtonWithSymbol:(NSString *)symbol action:(SEL)action;
- (void)startClock;
- (void)updateClock;
- (nullable NXROMApplication *)firstApplicationWithIdentifierPrefix:(NSString *)prefix;

@end

@implementation NXROMHomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self buildWallpaper];
    [self buildStatusBar];
    [self buildCollectionView];
    [self buildDock];

    [self reloadApplications];
    [self startClock];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.wallpaperLayer.frame = self.view.bounds;
}

#pragma mark - 外观

- (void)buildWallpaper
{
    self.wallpaperLayer = [CAGradientLayer layer];
    self.wallpaperLayer.colors = @[
        (id)[UIColor colorWithRed:0.05 green:0.06 blue:0.10 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.10 green:0.09 blue:0.20 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.20 green:0.12 blue:0.28 alpha:1.0].CGColor,
    ];
    self.wallpaperLayer.startPoint = CGPointMake(0.1, 0.0);
    self.wallpaperLayer.endPoint = CGPointMake(0.9, 1.0);
    [self.view.layer addSublayer:self.wallpaperLayer];
}

- (void)buildStatusBar
{
    self.clockLabel = [[UILabel alloc] init];
    self.clockLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.clockLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    self.clockLabel.textColor = UIColor.whiteColor;
    self.clockLabel.alpha = 0.9;

    self.hostLabel = [[UILabel alloc] init];
    self.hostLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.hostLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    self.hostLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
    self.hostLabel.text = [[NSProcessInfo processInfo] hostName];

    [self.view addSubview:self.clockLabel];
    [self.view addSubview:self.hostLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.clockLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:22.0],
        [self.clockLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:6.0],

        [self.hostLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-22.0],
        [self.hostLabel.centerYAnchor constraintEqualToAnchor:self.clockLabel.centerYAnchor],
    ]];
}

- (void)buildCollectionView
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(74.0, 92.0);
    layout.minimumInteritemSpacing = 12.0;
    layout.minimumLineSpacing = 20.0;
    layout.sectionInset = UIEdgeInsetsMake(18.0, 20.0, 18.0, 20.0);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:NXROMAppCell.class forCellWithReuseIdentifier:@"app"];
    [self.view addSubview:self.collectionView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.topAnchor constraintEqualToAnchor:self.clockLabel.bottomAnchor constant:8.0],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-104.0],
    ]];
}

- (void)buildDock
{
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    UIVisualEffectView *dock = [[UIVisualEffectView alloc] initWithEffect:effect];
    dock.translatesAutoresizingMaskIntoConstraints = NO;
    dock.layer.cornerRadius = 27.0;
    dock.layer.cornerCurve = kCACornerCurveContinuous;
    dock.clipsToBounds = YES;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self dockButtonWithSymbol:@"gearshape.fill" action:@selector(settingsTapped)],
        [self dockButtonWithSymbol:@"folder.fill" action:@selector(filesTapped)],
        [self dockButtonWithSymbol:@"iphone.app.switcher" action:@selector(switcherTapped)],
        [self dockButtonWithSymbol:@"chevron.left.forwardslash.chevron.right" action:@selector(debugTapped)],
    ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionEqualSpacing;
    stack.alignment = UIStackViewAlignmentCenter;

    [dock.contentView addSubview:stack];
    [self.view addSubview:dock];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [dock.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:18.0],
        [dock.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-18.0],
        [dock.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10.0],
        [dock.heightAnchor constraintEqualToConstant:74.0],

        [stack.leadingAnchor constraintEqualToAnchor:dock.contentView.leadingAnchor constant:22.0],
        [stack.trailingAnchor constraintEqualToAnchor:dock.contentView.trailingAnchor constant:-22.0],
        [stack.centerYAnchor constraintEqualToAnchor:dock.contentView.centerYAnchor],
    ]];

    self.dockView = dock;
}

- (UIButton *)dockButtonWithSymbol:(NSString *)symbol action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *image = [UIImage systemImageNamed:symbol];
    [button setImage:image forState:UIControlStateNormal];
    button.tintColor = UIColor.whiteColor;
    button.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:25.0 weight:UIImageSymbolWeightMedium];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.widthAnchor constraintEqualToConstant:54.0].active = YES;
    [button.heightAnchor constraintEqualToConstant:54.0].active = YES;
    return button;
}

#pragma mark - 时钟

- (void)startClock
{
    [self updateClock];
    self.clockTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                                                       target:self
                                                     selector:@selector(updateClock)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)updateClock
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm";
    self.clockLabel.text = [formatter stringFromDate:NSDate.date];
}

#pragma mark - 数据

- (void)reloadApplications
{
    self.applications = [[NXROMAppRegistry shared] reload];
    [self.collectionView reloadData];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return (NSInteger)self.applications.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NXROMAppCell *cell = (NXROMAppCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"app" forIndexPath:indexPath];
    [cell configureWithApplication:self.applications[(NSUInteger)indexPath.item]];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [collectionView deselectItemAtIndexPath:indexPath animated:NO];

    NXROMApplication *application = self.applications[(NSUInteger)indexPath.item];
    pid_t pid = [[NXROMAppRegistry shared] launchApplication:application];
    if(pid < 0)
    {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"启动失败"
                                                                       message:[NSString stringWithFormat:@"%@ 没能被拉起，看 Settings → 内核日志。", application.displayName]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - Dock 动作

- (void)settingsTapped
{
    if(self.openSettingsHandler)
    {
        self.openSettingsHandler();
    }
}

- (void)filesTapped
{
    NXROMApplication *files = [self firstApplicationWithIdentifierPrefix:@"org.emexlabs.rom.files"];
    if(files != nil)
    {
        [[NXROMAppRegistry shared] launchApplication:files];
        return;
    }

    /* Files.app 不在 ROM 里时，给一条能看的提示，别弹一个需要 entitlements 的 picker */
    NSString *rootfs = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/rootfs"];
    NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:rootfs error:nil];
    NSString *message = [NSString stringWithFormat:@"rootfs: %@\n\n%@",
                         rootfs,
                         [entries componentsJoinedByString:@"  "]];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"文件系统"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)switcherTapped
{
    if(self.openAppSwitcherHandler)
    {
        self.openAppSwitcherHandler();
    }
}

- (void)debugTapped
{
    NSMutableString *text = [NSMutableString string];
    [text appendString:klog_dump() ?: @"(empty)"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"内核日志"
                                                                   message:[text length] > 1500 ? [text substringToIndex:1500] : text
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (nullable NXROMApplication *)firstApplicationWithIdentifierPrefix:(NSString *)prefix
{
    for(NXROMApplication *application in self.applications)
    {
        if([application.bundleIdentifier hasPrefix:prefix])
        {
            return application;
        }
    }
    return nil;
}

@end
