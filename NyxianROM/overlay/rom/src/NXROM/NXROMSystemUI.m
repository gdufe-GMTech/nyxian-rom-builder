/*
 * NXROMSystemUI.m
 *
 * 控制中心与 App 切换器。
 *
 * 版式按 iOS 26：整块 UIGlassContainerEffect 打底，内部每个模块本身也是
 * UIGlassEffect（容器会把相邻玻璃元素融合成一体）。按钮用 SF Symbol，
 * 滑块用系统 UISlider。
 */

#import "NXROMSystemUI.h"
#import "NXROMDesign.h"

#pragma mark - 控制中心

@interface NXROMControlCenterViewController ()

@property (nonatomic, strong) UIVisualEffectView *container;
@property (nonatomic, strong) NSMutableArray<UIVisualEffectView *> *toggles;

@end

@implementation NXROMControlCenterViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.36];
    self.toggles = [NSMutableArray array];

    self.container = [NXROMDesign glassContainerWithSpacing:12.0];
    [self.view addSubview:self.container];

    UIStackView *column = [[UIStackView alloc] initWithFrame:CGRectZero];
    column.translatesAutoresizingMaskIntoConstraints = NO;
    column.axis = UILayoutConstraintAxisVertical;
    column.spacing = 12.0;
    column.alignment = UIStackViewAlignmentFill;
    [self.container.contentView addSubview:column];

    [column addArrangedSubview:[self buildConnectivityGrid]];
    [column addArrangedSubview:[self buildSliderModuleWithTitle:@"亮度" symbol:@"sun.max.fill"]];
    [column addArrangedSubview:[self buildSliderModuleWithTitle:@"音量" symbol:@"speaker.wave.2.fill"]];
    [column addArrangedSubview:[self buildShortcutRow]];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.container.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:14.0],
        [self.container.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-14.0],
        [self.container.topAnchor constraintEqualToAnchor:safe.topAnchor constant:14.0],

        [column.leadingAnchor constraintEqualToAnchor:self.container.contentView.leadingAnchor constant:14.0],
        [column.trailingAnchor constraintEqualToAnchor:self.container.contentView.trailingAnchor constant:-14.0],
        [column.topAnchor constraintEqualToAnchor:self.container.contentView.topAnchor constant:14.0],
        [column.bottomAnchor constraintEqualToAnchor:self.container.contentView.bottomAnchor constant:-14.0],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
    [self.view addGestureRecognizer:tap];
}

- (void)backgroundTapped:(UITapGestureRecognizer *)tap
{
    CGPoint point = [tap locationInView:self.view];
    UIView *hit = [self.view hitTest:point withEvent:nil];
    if (hit == self.view && self.dismissHandler)
    {
        self.dismissHandler();
    }
}

#pragma mark - 模块

- (UIVisualEffectView *)moduleTile
{
    UIVisualEffectView *tile = [NXROMDesign glassViewWithCornerRadius:24.0 style:1 interactive:YES];
    [self.container.contentView addSubview:tile];
    [self.toggles addObject:tile];
    return tile;
}

- (UIButton *)buttonWithSymbol:(NSString *)symbol inTile:(UIVisualEffectView *)tile
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = UIColor.whiteColor;
    [button setImage:[NXROMDesign symbolNamed:symbol pointSize:22.0 weight:UIFontWeightMedium]
            forState:UIControlStateNormal];
    [tile.contentView addSubview:button];

    [NSLayoutConstraint activateConstraints:@[
        [button.centerXAnchor constraintEqualToAnchor:tile.contentView.centerXAnchor],
        [button.centerYAnchor constraintEqualToAnchor:tile.contentView.centerYAnchor],
        [button.widthAnchor constraintEqualToConstant:44.0],
        [button.heightAnchor constraintEqualToConstant:44.0],
    ]];

    return button;
}

- (UIView *)buildConnectivityGrid
{
    NSArray<NSArray<NSString *> *> *rows = @[
        @[ @"airplane", @"wifi" ],
        @[ @"bluetooth", @"antenna.radiowaves.left.and.right" ],
    ];

    UIStackView *column = [[UIStackView alloc] initWithFrame:CGRectZero];
    column.axis = UILayoutConstraintAxisVertical;
    column.spacing = 10.0;
    column.distribution = UIStackViewDistributionFillEqually;

    for (NSArray<NSString *> *row in rows)
    {
        UIStackView *line = [[UIStackView alloc] initWithFrame:CGRectZero];
        line.axis = UILayoutConstraintAxisHorizontal;
        line.spacing = 10.0;
        line.distribution = UIStackViewDistributionFillEqually;

        for (NSString *symbol in row)
        {
            UIVisualEffectView *tile = [self moduleTile];
            UIButton *button = [self buttonWithSymbol:symbol inTile:tile];
            [button addTarget:self action:@selector(toggleTapped:) forControlEvents:UIControlEventTouchUpInside];
            [tile.heightAnchor constraintEqualToConstant:72.0].active = YES;
            [line addArrangedSubview:tile];
        }

        [column addArrangedSubview:line];
    }

    return column;
}

- (void)toggleTapped:(UIButton *)sender
{
    [NXROMDesign lightImpact];

    UIVisualEffectView *tile = (UIVisualEffectView *)sender.superview.superview;
    BOOL active = (tile.backgroundColor != nil);

    UIColor *highlight = active ? nil : [UIColor colorWithWhite:1.0 alpha:0.22];
    [UIView animateWithDuration:0.18 animations:^{
        tile.contentView.backgroundColor = highlight;
        tile.contentView.layer.cornerRadius = 24.0;
        tile.contentView.layer.cornerCurve = kCACornerCurveContinuous;
        tile.contentView.clipsToBounds = YES;
    }];
}

- (UIView *)buildSliderModuleWithTitle:(NSString *)title symbol:(NSString *)symbol
{
    UIVisualEffectView *tile = [self moduleTile];
    [tile.heightAnchor constraintEqualToConstant:74.0].active = YES;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[NXROMDesign symbolNamed:symbol
                                                                         pointSize:15.0
                                                                            weight:UIFontWeightSemibold]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [UIColor colorWithWhite:1.0 alpha:0.85];
    [tile.contentView addSubview:icon];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    label.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    [tile.contentView addSubview:label];

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectZero];
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    slider.minimumValue = 0.0;
    slider.maximumValue = 1.0;
    slider.value = (title.hash % 100) / 100.0;
    slider.minimumTrackTintColor = UIColor.whiteColor;
    [tile.contentView addSubview:slider];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:tile.contentView.leadingAnchor constant:16.0],
        [icon.topAnchor constraintEqualToAnchor:tile.contentView.topAnchor constant:14.0],

        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:6.0],
        [label.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],

        [slider.leadingAnchor constraintEqualToAnchor:tile.contentView.leadingAnchor constant:14.0],
        [slider.trailingAnchor constraintEqualToAnchor:tile.contentView.trailingAnchor constant:-14.0],
        [slider.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:8.0],
    ]];

    return tile;
}

- (UIView *)buildShortcutRow
{
    NSArray<NSString *> *symbols = @[ @"flashlight.off.fill", @"timer", @"camera.fill", @"square.grid.2x2.fill" ];

    UIStackView *row = [[UIStackView alloc] initWithFrame:CGRectZero];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10.0;
    row.distribution = UIStackViewDistributionFillEqually;

    for (NSString *symbol in symbols)
    {
        UIVisualEffectView *tile = [NXROMDesign glassViewWithCornerRadius:26.0 style:1 interactive:YES];
        [self.container.contentView addSubview:tile];
        [tile.heightAnchor constraintEqualToConstant:56.0].active = YES;
        [self buttonWithSymbol:symbol inTile:tile];
        [row addArrangedSubview:tile];
    }

    return row;
}

@end

#pragma mark - App 切换器

@interface NXROMAppSwitcherViewController ()

@property (nonatomic, strong) UIVisualEffectView *sheet;

@end

@implementation NXROMAppSwitcherViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.42];

    self.sheet = [NXROMDesign glassContainerWithSpacing:12.0];
    [self.view addSubview:self.sheet];

    UIStackView *column = [[UIStackView alloc] initWithFrame:CGRectZero];
    column.translatesAutoresizingMaskIntoConstraints = NO;
    column.axis = UILayoutConstraintAxisVertical;
    column.spacing = 14.0;
    [self.sheet.contentView addSubview:column];

    NSArray *windows = [self runningWindows];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.text = windows.count > 0 ? @"正在运行" : @"没有运行中的应用";
    title.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    [column addArrangedSubview:title];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scroll.showsHorizontalScrollIndicator = NO;
    [scroll.heightAnchor constraintEqualToConstant:420.0].active = YES;

    UIStackView *cards = [[UIStackView alloc] initWithFrame:CGRectZero];
    cards.translatesAutoresizingMaskIntoConstraints = NO;
    cards.axis = UILayoutConstraintAxisHorizontal;
    cards.spacing = 14.0;
    [scroll addSubview:cards];

    [NSLayoutConstraint activateConstraints:@[
        [cards.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [cards.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [cards.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [cards.heightAnchor constraintEqualToAnchor:scroll.heightAnchor],
    ]];

    for (NSUInteger index = 0; index < windows.count; index++)
    {
        UIVisualEffectView *card = [NXROMDesign glassViewWithCornerRadius:26.0 style:0 interactive:NO];
        [cards addArrangedSubview:card];
        [card.widthAnchor constraintEqualToConstant:250.0].active = YES;

        UILabel *name = [[UILabel alloc] initWithFrame:CGRectZero];
        name.translatesAutoresizingMaskIntoConstraints = NO;
        name.text = [NSString stringWithFormat:@"窗口 %lu", (unsigned long)(index + 1)];
        name.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        name.textColor = UIColor.whiteColor;
        [card.contentView addSubview:name];

        [NSLayoutConstraint activateConstraints:@[
            [name.centerXAnchor constraintEqualToAnchor:card.contentView.centerXAnchor],
            [name.centerYAnchor constraintEqualToAnchor:card.contentView.centerYAnchor],
        ]];
    }

    if (windows.count == 0)
    {
        UILabel *hint = [[UILabel alloc] initWithFrame:CGRectZero];
        hint.text = @"上滑打开应用后，这里会列出它们的窗口。";
        hint.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
        hint.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
        hint.numberOfLines = 0;
        [column addArrangedSubview:hint];
    }
    else
    {
        [column addArrangedSubview:scroll];
    }

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.sheet.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16.0],
        [self.sheet.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16.0],
        [self.sheet.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],

        [column.leadingAnchor constraintEqualToAnchor:self.sheet.contentView.leadingAnchor constant:18.0],
        [column.trailingAnchor constraintEqualToAnchor:self.sheet.contentView.trailingAnchor constant:-18.0],
        [column.topAnchor constraintEqualToAnchor:self.sheet.contentView.topAnchor constant:18.0],
        [column.bottomAnchor constraintEqualToAnchor:self.sheet.contentView.bottomAnchor constant:-18.0],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
    [self.view addGestureRecognizer:tap];
}

- (NSArray *)runningWindows
{
    Class serverClass = NSClassFromString(@"NXWindowServer");
    if (serverClass == Nil || ![serverClass respondsToSelector:@selector(shared)])
    {
        return @[];
    }

    id server = [serverClass performSelector:@selector(shared)];
    if (![server respondsToSelector:NSSelectorFromString(@"windowOrder")])
    {
        return @[];
    }

    id order = [server valueForKey:@"windowOrder"];
    return [order isKindOfClass:NSArray.class] ? order : @[];
}

- (void)backgroundTapped:(UITapGestureRecognizer *)tap
{
    CGPoint point = [tap locationInView:self.view];
    UIView *hit = [self.view hitTest:point withEvent:nil];
    if (hit == self.view && self.dismissHandler)
    {
        self.dismissHandler();
    }
}

@end
