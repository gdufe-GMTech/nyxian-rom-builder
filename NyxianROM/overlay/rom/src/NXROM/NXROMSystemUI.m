/*
 * NXROMSystemUI.m
 *
 * 控制中心版式参照 iOS 26/27：
 *   顶部左右为「+」与电源按钮
 *   运营商/信号/电量的状态行
 *   连接模块（2x2 圆形开关）与媒体模块（封面 + 未在播放 + 传输控制）
 *   专注模式 / 引导式访问 两个胶囊
 *   亮度与音量两条竖向胶囊滑杆
 *   底部两行共 8 个圆形快捷按钮
 */

#import "NXROMSystemUI.h"
#import "NXROMDesign.h"

#include <stdlib.h>

#import <LindChain/WindowServer/NXWindowServer.h>
#import <LindChain/WindowServer/Window/NXWindow.h>
#import <LindChain/WindowServer/Window/NXWindowSession.h>

#pragma mark - 竖向胶囊滑杆

@interface NXROMVerticalSlider : UIControl

@property (nonatomic, assign) CGFloat value;         /* 0...1 */
@property (nonatomic, copy, nullable) NSString *symbolName;

@end

@implementation NXROMVerticalSlider
{
    UIView *_fill;
    UIImageView *_symbolView;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.clipsToBounds = YES;

        _fill = [UIView new];
        _fill.translatesAutoresizingMaskIntoConstraints = NO;
        _fill.backgroundColor = UIColor.whiteColor;
        _fill.layer.cornerCurve = kCACornerCurveContinuous;
        [self addSubview:_fill];

        _symbolView = [[UIImageView alloc] init];
        _symbolView.translatesAutoresizingMaskIntoConstraints = NO;
        _symbolView.contentMode = UIViewContentModeScaleAspectFit;
        _symbolView.tintColor = [UIColor colorWithWhite:0.32 alpha:1.0];
        [self addSubview:_symbolView];

        [NSLayoutConstraint activateConstraints:@[
            [_symbolView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_symbolView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12.0],
            [_symbolView.widthAnchor constraintEqualToConstant:20.0],
            [_symbolView.heightAnchor constraintEqualToConstant:20.0],
        ]];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];

        _value = 0.55;
    }
    return self;
}

- (void)setValue:(CGFloat)value
{
    _value = MAX(0.0, MIN(1.0, value));
    [self setNeedsLayout];
}

- (void)setSymbolName:(NSString *)symbolName
{
    _symbolName = [symbolName copy];
    _symbolView.image = [UIImage systemImageNamed:symbolName];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat fillHeight = MAX(34.0, height * self.value);

    self.layer.cornerRadius = width / 2.0;
    _fill.frame = CGRectMake(0, height - fillHeight, width, fillHeight);
    _fill.layer.cornerRadius = width / 2.0;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan
{
    CGPoint location = [pan locationInView:self];
    self.value = 1.0 - (location.y / MAX(1.0, CGRectGetHeight(self.bounds)));
}

@end

#pragma mark - 控制中心

@interface NXROMControlCenterViewController ()
@property (nonatomic, strong) UIVisualEffectView *scrim;
@property (nonatomic, strong) NSMutableArray<UIButton *> *toggleButtons;
@end

@implementation NXROMControlCenterViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.clearColor;
    self.toggleButtons = [NSMutableArray array];

    UIVisualEffectView *scrim = [NXROMDesign blurViewWithStyle:UIBlurEffectStyleSystemChromeMaterialDark cornerRadius:0];
    scrim.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrim];
    self.scrim = scrim;

    [NSLayoutConstraint activateConstraints:@[
        [scrim.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrim.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrim.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrim.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    [scrim addGestureRecognizer:tap];

    [self buildChrome];
    [self buildModules];
}

- (UIView *)moduleView
{
    UIView *view = [UIView new];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.13];
    view.layer.cornerRadius = 26.0;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.clipsToBounds = YES;
    return view;
}

- (UIButton *)circleButtonWithSymbol:(NSString *)symbol diameter:(CGFloat)diameter
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
    button.layer.cornerRadius = diameter / 2.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.tintColor = UIColor.whiteColor;

    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    [button setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:diameter * 0.42
                                                                                            weight:UIImageSymbolWeightMedium]
                                   forState:UIControlStateNormal];
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:diameter],
        [button.heightAnchor constraintEqualToConstant:diameter],
    ]];
    return button;
}

#pragma mark - 顶部控件

- (void)buildChrome
{
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    UIButton *addButton = [self circleButtonWithSymbol:@"plus" diameter:30.0];
    addButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];

    UIButton *powerButton = [self circleButtonWithSymbol:@"power" diameter:30.0];
    powerButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    [powerButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:addButton];
    [self.view addSubview:powerButton];

    [NSLayoutConstraint activateConstraints:@[
        [addButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
        [addButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8.0],

        [powerButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],
        [powerButton.centerYAnchor constraintEqualToAnchor:addButton.centerYAnchor],
    ]];
}

#pragma mark - 模块

- (void)buildModules
{
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    CGFloat sideInset = 18.0;
    CGFloat gap = 12.0;

    /* 状态行 */
    UILabel *statusLeft = [UILabel new];
    statusLeft.translatesAutoresizingMaskIntoConstraints = NO;
    statusLeft.numberOfLines = 2;
    statusLeft.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    statusLeft.textColor = [UIColor colorWithWhite:1.0 alpha:0.88];
    statusLeft.text = [self carrierText];

    UILabel *statusRight = [UILabel new];
    statusRight.translatesAutoresizingMaskIntoConstraints = NO;
    statusRight.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightSemibold];
    statusRight.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    statusRight.textAlignment = NSTextAlignmentRight;
    statusRight.text = [self batteryText];

    [self.view addSubview:statusLeft];
    [self.view addSubview:statusRight];

    /* 连接模块：2x2 */
    UIView *connectivity = [self moduleView];
    UIButton *airplane = [self toggleWithSymbol:@"airplane" identifier:@"airplane" diameter:46.0];
    UIButton *wifi = [self toggleWithSymbol:@"wifi" identifier:@"wifi" diameter:46.0];
    UIButton *cellular = [self toggleWithSymbol:@"cellularbars" identifier:@"cellular" diameter:46.0];
    UIButton *bluetooth = [self toggleWithSymbol:@"bluetooth" identifier:@"bluetooth" diameter:46.0];

    UIStackView *connectionRow1 = [[UIStackView alloc] initWithArrangedSubviews:@[ airplane, wifi ]];
    UIStackView *connectionRow2 = [[UIStackView alloc] initWithArrangedSubviews:@[ cellular, bluetooth ]];
    for(UIStackView *row in @[ connectionRow1, connectionRow2 ])
    {
        row.axis = UILayoutConstraintAxisHorizontal;
        row.distribution = UIStackViewDistributionFillEqually;
        row.alignment = UIStackViewAlignmentCenter;
    }

    UIStackView *connectionColumn = [[UIStackView alloc] initWithArrangedSubviews:@[ connectionRow1, connectionRow2 ]];
    connectionColumn.translatesAutoresizingMaskIntoConstraints = NO;
    connectionColumn.axis = UILayoutConstraintAxisVertical;
    connectionColumn.distribution = UIStackViewDistributionFillEqually;
    [connectivity addSubview:connectionColumn];
    [NSLayoutConstraint activateConstraints:@[
        [connectionColumn.leadingAnchor constraintEqualToAnchor:connectivity.leadingAnchor constant:12.0],
        [connectionColumn.trailingAnchor constraintEqualToAnchor:connectivity.trailingAnchor constant:-12.0],
        [connectionColumn.topAnchor constraintEqualToAnchor:connectivity.topAnchor constant:12.0],
        [connectionColumn.bottomAnchor constraintEqualToAnchor:connectivity.bottomAnchor constant:-12.0],
    ]];

    /* 媒体模块 */
    UIView *music = [self moduleView];
    UIView *artwork = [UIView new];
    artwork.translatesAutoresizingMaskIntoConstraints = NO;
    artwork.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    artwork.layer.cornerRadius = 12.0;
    artwork.layer.cornerCurve = kCACornerCurveContinuous;

    UILabel *musicTitle = [UILabel new];
    musicTitle.translatesAutoresizingMaskIntoConstraints = NO;
    musicTitle.text = @"未在播放";
    musicTitle.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    musicTitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];

    UIStackView *transport = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self transportButton:@"backward.fill"],
        [self transportButton:@"play.fill"],
        [self transportButton:@"forward.fill"],
    ]];
    transport.translatesAutoresizingMaskIntoConstraints = NO;
    transport.axis = UILayoutConstraintAxisHorizontal;
    transport.distribution = UIStackViewDistributionFillEqually;

    [music addSubview:artwork];
    [music addSubview:musicTitle];
    [music addSubview:transport];

    [NSLayoutConstraint activateConstraints:@[
        [artwork.leadingAnchor constraintEqualToAnchor:music.leadingAnchor constant:12.0],
        [artwork.topAnchor constraintEqualToAnchor:music.topAnchor constant:12.0],
        [artwork.trailingAnchor constraintEqualToAnchor:music.trailingAnchor constant:-12.0],
        [artwork.heightAnchor constraintEqualToAnchor:artwork.widthAnchor],

        [musicTitle.leadingAnchor constraintEqualToAnchor:artwork.leadingAnchor],
        [musicTitle.topAnchor constraintEqualToAnchor:artwork.bottomAnchor constant:6.0],

        [transport.leadingAnchor constraintEqualToAnchor:music.leadingAnchor constant:12.0],
        [transport.trailingAnchor constraintEqualToAnchor:music.trailingAnchor constant:-12.0],
        [transport.topAnchor constraintEqualToAnchor:musicTitle.bottomAnchor constant:8.0],
        [transport.bottomAnchor constraintEqualToAnchor:music.bottomAnchor constant:-10.0],
        [transport.heightAnchor constraintEqualToConstant:30.0],
    ]];

    /* 专注模式 / 引导式访问 */
    UIButton *focus = [self pillButtonWithTitle:@"专注模式" symbol:@"moon.fill"];
    UIButton *guided = [self pillButtonWithTitle:@"引导式访问" symbol:@"lock.fill"];

    UIStackView *leftColumn = [[UIStackView alloc] initWithArrangedSubviews:@[ focus, guided ]];
    leftColumn.translatesAutoresizingMaskIntoConstraints = NO;
    leftColumn.axis = UILayoutConstraintAxisVertical;
    leftColumn.spacing = gap;
    leftColumn.distribution = UIStackViewDistributionFillEqually;

    /* 亮度 / 音量 */
    NXROMVerticalSlider *brightness = [[NXROMVerticalSlider alloc] initWithFrame:CGRectZero];
    brightness.translatesAutoresizingMaskIntoConstraints = NO;
    brightness.symbolName = @"sun.max.fill";
    brightness.value = 0.62;

    NXROMVerticalSlider *volume = [[NXROMVerticalSlider alloc] initWithFrame:CGRectZero];
    volume.translatesAutoresizingMaskIntoConstraints = NO;
    volume.symbolName = @"speaker.wave.2.fill";
    volume.value = 0.44;

    UIStackView *rightColumn = [[UIStackView alloc] initWithArrangedSubviews:@[ brightness, volume ]];
    rightColumn.translatesAutoresizingMaskIntoConstraints = NO;
    rightColumn.axis = UILayoutConstraintAxisHorizontal;
    rightColumn.spacing = 12.0;
    rightColumn.distribution = UIStackViewDistributionFillEqually;

    /* 底部 8 个快捷 */
    NSArray<NSString *> *shortcutSymbols = @[
        @"flashlight.off.fill", @"rectangle.on.rectangle", @"lock.rotation", @"record.circle",
        @"timer", @"shuffle", @"battery.100", @"camera.fill",
    ];
    NSMutableArray<UIButton *> *shortcutButtons = [NSMutableArray array];
    for(NSString *symbol in shortcutSymbols)
    {
        UIButton *button = [self toggleWithSymbol:symbol identifier:symbol diameter:46.0];
        [shortcutButtons addObject:button];
    }

    UIStackView *shortcutRow1 = [[UIStackView alloc] initWithArrangedSubviews:
        [shortcutButtons subarrayWithRange:NSMakeRange(0, 4)]];
    UIStackView *shortcutRow2 = [[UIStackView alloc] initWithArrangedSubviews:
        [shortcutButtons subarrayWithRange:NSMakeRange(4, 4)]];
    for(UIStackView *row in @[ shortcutRow1, shortcutRow2 ])
    {
        row.axis = UILayoutConstraintAxisHorizontal;
        row.distribution = UIStackViewDistributionEqualSpacing;
        row.alignment = UIStackViewAlignmentCenter;
    }

    UIStackView *shortcutColumn = [[UIStackView alloc] initWithArrangedSubviews:@[ shortcutRow1, shortcutRow2 ]];
    shortcutColumn.translatesAutoresizingMaskIntoConstraints = NO;
    shortcutColumn.axis = UILayoutConstraintAxisVertical;
    shortcutColumn.distribution = UIStackViewDistributionFillEqually;
    shortcutColumn.alignment = UIStackViewAlignmentFill;

    /* 整体纵向排布 */
    UIStackView *topRow = [[UIStackView alloc] initWithArrangedSubviews:@[ connectivity, music ]];
    topRow.axis = UILayoutConstraintAxisHorizontal;
    topRow.distribution = UIStackViewDistributionFillEqually;
    topRow.spacing = gap;

    UIStackView *middleRow = [[UIStackView alloc] initWithArrangedSubviews:@[ leftColumn, rightColumn ]];
    middleRow.axis = UILayoutConstraintAxisHorizontal;
    middleRow.distribution = UIStackViewDistributionFillEqually;
    middleRow.spacing = gap;

    UIStackView *column = [[UIStackView alloc] initWithArrangedSubviews:@[ topRow, middleRow, shortcutColumn ]];
    column.translatesAutoresizingMaskIntoConstraints = NO;
    column.axis = UILayoutConstraintAxisVertical;
    column.spacing = gap;
    column.distribution = UIStackViewDistributionFill;

    [self.view addSubview:column];

    [NSLayoutConstraint activateConstraints:@[
        [statusLeft.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:sideInset],
        [statusLeft.topAnchor constraintEqualToAnchor:safe.topAnchor constant:52.0],

        [statusRight.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-sideInset],
        [statusRight.centerYAnchor constraintEqualToAnchor:statusLeft.centerYAnchor],

        [column.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:sideInset],
        [column.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-sideInset],
        [column.topAnchor constraintEqualToAnchor:statusLeft.bottomAnchor constant:14.0],
        [column.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor constant:-30.0],

        [topRow.heightAnchor constraintEqualToConstant:150.0],
        [middleRow.heightAnchor constraintEqualToConstant:112.0],
        [shortcutColumn.heightAnchor constraintEqualToConstant:110.0],
    ]];
}

- (NSString *)carrierText
{
    NSString *carrier = @"中国移动";
    return [NSString stringWithFormat:@"▮▮▮ 数据 %@ 5G\n▮▮▮ 电话 %@", carrier, carrier];
}

- (NSString *)batteryText
{
    UIDevice *device = UIDevice.currentDevice;
    device.batteryMonitoringEnabled = YES;
    float level = device.batteryLevel;
    if(level < 0)
    {
        return @"—";
    }
    return [NSString stringWithFormat:@"%.0f%%", level * 100.0];
}

- (UIButton *)toggleWithSymbol:(NSString *)symbol identifier:(NSString *)identifier diameter:(CGFloat)diameter
{
    UIButton *button = [self circleButtonWithSymbol:symbol diameter:diameter];
    button.accessibilityIdentifier = identifier;
    [button addTarget:self action:@selector(toggleTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.toggleButtons addObject:button];
    return button;
}

- (UIButton *)transportButton:(NSString *)symbol
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tintColor = UIColor.whiteColor;
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    [button setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                                                            weight:UIImageSymbolWeightSemibold]
                                   forState:UIControlStateNormal];
    return button;
}

- (UIButton *)pillButtonWithTitle:(NSString *)title symbol:(NSString *)symbol
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.13];
    button.layer.cornerRadius = 24.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.tintColor = UIColor.whiteColor;

    UIImage *image = [UIImage systemImageNamed:symbol];
    [button setImage:image forState:UIControlStateNormal];
    [button setTitle:[NSString stringWithFormat:@"  %@", title] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.9] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 16.0, 0, 12.0);
    return button;
}

- (void)toggleTapped:(UIButton *)sender
{
    [NXROMDesign lightImpact];

    BOOL active = !sender.isSelected;
    sender.selected = active;
    sender.backgroundColor = active
        ? [UIColor colorWithRed:0.20 green:0.52 blue:0.96 alpha:1.0]
        : [UIColor colorWithWhite:1.0 alpha:0.16];
    sender.tintColor = UIColor.whiteColor;

    if([sender.accessibilityIdentifier isEqualToString:@"calculator"] && self.openCalculatorHandler)
    {
        [self dismiss];
        self.openCalculatorHandler();
    }
}

- (void)dismiss
{
    if(self.dismissHandler)
    {
        self.dismissHandler();
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end

#pragma mark - App 切换器

@interface NXROMAppSwitcherViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UIVisualEffectView *scrim;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<NSNumber *> *identifiers;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation NXROMAppSwitcherViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.clearColor;

    UIVisualEffectView *scrim = [NXROMDesign blurViewWithStyle:UIBlurEffectStyleSystemChromeMaterialDark cornerRadius:0];
    scrim.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrim];
    self.scrim = scrim;

    [NSLayoutConstraint activateConstraints:@[
        [scrim.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrim.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrim.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrim.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(260.0, 420.0);
    layout.minimumLineSpacing = 18.0;
    layout.sectionInset = UIEdgeInsetsMake(0, 24.0, 0, 24.0);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    [self.collectionView registerClass:UICollectionViewCell.class forCellWithReuseIdentifier:@"card"];
    [self.view addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.collectionView.heightAnchor constraintEqualToConstant:460.0],
    ]];

    self.emptyLabel = [UILabel new];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.text = @"没有最近使用的应用";
    self.emptyLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    self.emptyLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    [self.view addSubview:self.emptyLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    [scrim addGestureRecognizer:tap];

    [self reloadIdentifiers];
}

- (void)reloadIdentifiers
{
    NXWindowServer *server = [NXWindowServer shared];
    NSMutableArray<NSNumber *> *identifiers = [NSMutableArray array];

    for(NSNumber *identifier in server.windowOrder)
    {
        if(server.windows[identifier] != nil)
        {
            [identifiers addObject:identifier];
        }
    }

    self.identifiers = identifiers;
    self.emptyLabel.hidden = identifiers.count > 0;
    [self.collectionView reloadData];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return (NSInteger)self.identifiers.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"card" forIndexPath:indexPath];

    for(UIView *subview in cell.contentView.subviews.copy)
    {
        [subview removeFromSuperview];
    }

    NSNumber *identifier = self.identifiers[(NSUInteger)indexPath.item];
    NXWindowSession *session = [[NXWindowServer shared] windowSessionForIdentifier:identifier.unsignedLongLongValue];

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    card.layer.cornerRadius = 22.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.clipsToBounds = YES;
    [cell.contentView addSubview:card];

    UIImageView *snapshot = [[UIImageView alloc] initWithImage:[session snapshotWindow]];
    snapshot.translatesAutoresizingMaskIntoConstraints = NO;
    snapshot.contentMode = UIViewContentModeScaleAspectFill;
    snapshot.clipsToBounds = YES;
    snapshot.layer.cornerRadius = 14.0;
    snapshot.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:snapshot];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = session.windowName.length > 0 ? session.windowName : [NSString stringWithFormat:@"窗口 %@", identifier];
    title.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    title.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    [card addSubview:title];

    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [card.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [card.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],

        [snapshot.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:8.0],
        [snapshot.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8.0],
        [snapshot.topAnchor constraintEqualToAnchor:card.topAnchor constant:8.0],
        [snapshot.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-34.0],

        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [title.centerYAnchor constraintEqualToAnchor:snapshot.bottomAnchor constant:17.0],
    ]];

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSNumber *identifier = self.identifiers[(NSUInteger)indexPath.item];
    [[NXWindowServer shared] activateWindowForIdentifier:identifier.unsignedLongLongValue
                                                animated:YES
                                          withCompletion:^{
        if(self.dismissHandler)
        {
            self.dismissHandler();
        }
    }];
}

- (void)dismiss
{
    if(self.dismissHandler)
    {
        self.dismissHandler();
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end
