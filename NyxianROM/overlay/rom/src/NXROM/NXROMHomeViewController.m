/*
 * NXROMHomeViewController.m
 *
 * 主屏：壁纸 + 分页图标网格 + 系统 UIPageControl + 液态玻璃 Dock。
 *
 * 全部用系统组件：
 *   - 图标是 systemFill 圆角块 + SF Symbol + 系统字号标签（不自绘位图）
 *   - 页点用 UIPageControl（backgroundStyle = prominent，自带胶囊底）
 *   - Dock / 文件夹面板用 UIGlassEffect
 */

#import "NXROMHomeViewController.h"
#import "NXROMDesign.h"

static NSUInteger const kNXROMColumns = 4;
static NSUInteger const kNXROMRows = 6;
static CGFloat const kNXROMGridInsetX = 22.0;
static CGFloat const kNXROMGridTop = 58.0;

@class NXROMIconButton;

@protocol NXROMIconButtonDelegate <NSObject>
- (void)iconButtonTapped:(NXROMIconButton *)button;
@end

#pragma mark - 图标

@interface NXROMIconButton : UIControl

@property (nonatomic, strong, readonly) NXROMApplication *application;
@property (nonatomic, weak) id<NXROMIconButtonDelegate> delegate;
@property (nonatomic, assign) BOOL showsLabel;

- (instancetype)initWithApplication:(NXROMApplication *)application size:(CGFloat)size;

@end

@interface NXROMIconButton ()
@property (nonatomic, strong, readwrite) NXROMApplication *application;
@property (nonatomic, strong) UIView *tile;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) CGFloat iconSize;
@end

@implementation NXROMIconButton

- (instancetype)initWithApplication:(NXROMApplication *)application size:(CGFloat)size
{
    self = [super initWithFrame:CGRectZero];

    if (self)
    {
        _application = application;
        _iconSize = size;
        _showsLabel = YES;

        _tile = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
        _tile.userInteractionEnabled = NO;
        _tile.layer.cornerRadius = size * 0.2237;
        _tile.layer.cornerCurve = kCACornerCurveContinuous;
        _tile.clipsToBounds = YES;
        _tile.backgroundColor = application.tintColor
            ?: [NXROMDesign tintForBuiltinIdentifier:application.builtinIdentifier ?: @""];
        [self addSubview:_tile];

        UIImage *image = application.icon;
        if (image == nil)
        {
            NSString *symbol = application.symbolName;
            if (symbol.length == 0)
            {
                symbol = (application.kind == NXROMAppKindFolder) ? @"folder.fill" : @"app.fill";
            }
            image = [NXROMDesign symbolNamed:symbol pointSize:size * 0.48 weight:UIFontWeightSemibold];
        }

        UIImageView *glyph = [[UIImageView alloc] initWithImage:image];
        glyph.userInteractionEnabled = NO;
        glyph.contentMode = UIViewContentModeScaleAspectFit;
        glyph.tintColor = UIColor.whiteColor;
        glyph.frame = CGRectInset(_tile.bounds, size * 0.22, size * 0.22);
        glyph.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_tile addSubview:glyph];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.text = application.displayName;
        _titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _titleLabel.layer.shadowColor = UIColor.blackColor.CGColor;
        _titleLabel.layer.shadowOpacity = 0.4;
        _titleLabel.layer.shadowRadius = 2.0;
        _titleLabel.layer.shadowOffset = CGSizeMake(0, 1);
        [self addSubview:_titleLabel];

        [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    }

    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    self.tile.frame = CGRectMake((width - self.iconSize) / 2.0, 0.0, self.iconSize, self.iconSize);
    self.titleLabel.hidden = !self.showsLabel;
    self.titleLabel.frame = CGRectMake(-4.0, self.iconSize + 5.0, width + 8.0, 14.0);
}

- (void)handleTap
{
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.tile.transform = CGAffineTransformMakeScale(0.9, 0.9);
    }
                     completion:^(BOOL finished) {
        [UIView animateWithDuration:0.18 animations:^{
            self.tile.transform = CGAffineTransformIdentity;
        }];
    }];

    [self.delegate iconButtonTapped:self];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.10 animations:^{
        self.alpha = highlighted ? 0.75 : 1.0;
    }];
}

@end

#pragma mark - 单页网格

@interface NXROMPageView : UIView
@property (nonatomic, copy) NSArray<NXROMApplication *> *applications;
@property (nonatomic, weak) id<NXROMIconButtonDelegate> delegate;
- (void)reload;
@end

@implementation NXROMPageView

@synthesize applications = _applications;

{
    NSMutableArray<NXROMIconButton *> *_buttons;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _buttons = [NSMutableArray array];
    }
    return self;
}

- (void)setApplications:(NSArray<NXROMApplication *> *)applications
{
    _applications = [applications copy];
    [self reload];
}

- (void)reload
{
    for (NXROMIconButton *button in _buttons)
    {
        [button removeFromSuperview];
    }
    [_buttons removeAllObjects];

    for (NXROMApplication *application in self.applications)
    {
        NXROMIconButton *button = [[NXROMIconButton alloc] initWithApplication:application size:NXROMIconSize];
        button.delegate = self.delegate;
        [self addSubview:button];
        [_buttons addObject:button];
    }

    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    if (width <= 0.0 || height <= 0.0 || _buttons.count == 0)
    {
        return;
    }

    CGFloat usable = width - kNXROMGridInsetX * 2.0;
    CGFloat cellWidth = usable / (CGFloat)kNXROMColumns;

    CGFloat cellHeight = (height - kNXROMGridTop - 40.0) / (CGFloat)kNXROMRows;
    cellHeight = MAX(cellHeight, NXROMIconSize + 22.0);

    for (NSUInteger index = 0; index < _buttons.count; index++)
    {
        CGFloat column = (CGFloat)(index % kNXROMColumns);
        CGFloat row = (CGFloat)(index / kNXROMColumns);

        NXROMIconButton *button = _buttons[index];
        CGFloat x = kNXROMGridInsetX + column * cellWidth + (cellWidth - NXROMIconSize) / 2.0;
        CGFloat y = kNXROMGridTop + row * cellHeight;
        button.frame = CGRectMake(x, y, NXROMIconSize, NXROMIconSize + 19.0);
    }
}

@end

#pragma mark - 文件夹

@interface NXROMFolderViewController : UIViewController <NXROMIconButtonDelegate>
@property (nonatomic, strong) NXROMApplication *folder;
@property (nonatomic, copy, nullable) void (^openHandler)(NXROMApplication *application);
@end

@implementation NXROMFolderViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.28];

    UIVisualEffectView *panel = [NXROMDesign glassViewWithCornerRadius:34.0 style:0 interactive:NO];
    [self.view addSubview:panel];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = self.folder.displayName;
    title.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    [panel.contentView addSubview:title];

    NSArray<NXROMApplication *> *children = self.folder.children ?: @[];
    NSMutableArray<UIView *> *icons = [NSMutableArray array];

    for (NXROMApplication *application in children)
    {
        NXROMIconButton *button = [[NXROMIconButton alloc] initWithApplication:application size:60.0];
        button.delegate = self;
        [panel.contentView addSubview:button];
        [icons addObject:button];
    }

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [panel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
        [panel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],
        [panel.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
        [panel.heightAnchor constraintEqualToConstant:420.0],

        [title.centerXAnchor constraintEqualToAnchor:panel.contentView.centerXAnchor],
        [title.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:26.0],
    ]];

    [self.view layoutIfNeeded];
    CGFloat panelWidth = CGRectGetWidth(panel.contentView.bounds);
    CGFloat cell = panelWidth / 4.0;

    for (NSUInteger index = 0; index < icons.count; index++)
    {
        CGFloat column = (CGFloat)(index % 4);
        CGFloat row = (CGFloat)(index / 4);
        icons[index].frame = CGRectMake(column * cell + (cell - NXROMIconSize) / 2.0,
                                        70.0 + row * 92.0,
                                        NXROMIconSize,
                                        NXROMIconSize + 19.0);
    }

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
    [self.view addGestureRecognizer:tap];
}

- (void)backgroundTapped:(UITapGestureRecognizer *)tap
{
    CGPoint point = [tap locationInView:self.view];
    UIView *hit = [self.view hitTest:point withEvent:nil];
    if (hit == self.view)
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)iconButtonTapped:(NXROMIconButton *)button
{
    NXROMApplication *application = button.application;
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.openHandler)
        {
            self.openHandler(application);
        }
    }];
}

@end

#pragma mark - 主屏

@interface NXROMHomeViewController () <NXROMIconButtonDelegate, UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *pagingScrollView;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) UIVisualEffectView *dock;
@property (nonatomic, strong) NSMutableArray<NXROMPageView *> *pages;
@property (nonatomic, strong) NSArray<NXROMApplication *> *applications;
@property (nonatomic, assign, getter=isEditing) BOOL editing;

@end

@implementation NXROMHomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;
    [NXROMDesign applyWallpaperToView:self.view];

    self.pages = [NSMutableArray array];

    self.pagingScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.pagingScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pagingScrollView.pagingEnabled = YES;
    self.pagingScrollView.showsHorizontalScrollIndicator = NO;
    self.pagingScrollView.showsVerticalScrollIndicator = NO;
    self.pagingScrollView.delegate = self;
    [self.view addSubview:self.pagingScrollView];

    self.pageControl = [[UIPageControl alloc] initWithFrame:CGRectZero];
    self.pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.pageControl.backgroundStyle = UIPageControlBackgroundStyleProminent;
    self.pageControl.currentPageIndicatorTintColor = UIColor.whiteColor;
    self.pageControl.pageIndicatorTintColor = [UIColor colorWithWhite:1.0 alpha:0.4];
    [self.pageControl addTarget:self action:@selector(pageControlChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.pageControl];

    self.dock = [NXROMDesign glassContainerWithSpacing:10.0];
    [self.view addSubview:self.dock];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.pagingScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.pagingScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.pagingScrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.pagingScrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.dock.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:14.0],
        [self.dock.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-14.0],
        [self.dock.heightAnchor constraintEqualToConstant:NXROMDockHeight],
        [self.dock.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8.0],

        [self.pageControl.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.pageControl.bottomAnchor constraintEqualToAnchor:self.dock.topAnchor constant:-14.0],
    ]];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(handleLongPress:)];
    [self.pagingScrollView addGestureRecognizer:longPress];

    /* 顶部边缘下滑 → 控制中心；底部上滑 → App 切换器（交给 shell 处理） */
    UIScreenEdgePanGestureRecognizer *controlCenter = [[UIScreenEdgePanGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleControlCenterEdge:)];
    controlCenter.edges = UIRectEdgeTop;
    [self.view addGestureRecognizer:controlCenter];

    UIScreenEdgePanGestureRecognizer *switcher = [[UIScreenEdgePanGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleSwitcherEdge:)];
    switcher.edges = UIRectEdgeBottom;
    [self.view addGestureRecognizer:switcher];

    [self reloadApplications];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutPages];
    [self layoutDock];
}

#pragma mark - 数据

- (void)reloadApplications
{
    self.applications = [[NXROMAppRegistry shared] reload];
    [self rebuildPages];
    [self rebuildDock];
}

- (void)rebuildPages
{
    for (NXROMPageView *page in self.pages)
    {
        [page removeFromSuperview];
    }
    [self.pages removeAllObjects];

    NSUInteger perPage = kNXROMColumns * kNXROMRows;
    NSUInteger total = self.applications.count;
    NSUInteger pageCount = MAX(1, (total + perPage - 1) / perPage);

    for (NSUInteger pageIndex = 0; pageIndex < pageCount; pageIndex++)
    {
        NSUInteger location = pageIndex * perPage;
        NSUInteger length = (total > location) ? MIN(perPage, total - location) : 0;

        NXROMPageView *page = [[NXROMPageView alloc] initWithFrame:CGRectZero];
        page.delegate = self;
        page.applications = (length > 0) ? [self.applications subarrayWithRange:NSMakeRange(location, length)] : @[];
        [self.pagingScrollView addSubview:page];
        [self.pages addObject:page];
    }

    self.pageControl.numberOfPages = pageCount;
    self.pageControl.currentPage = 0;
    self.pageControl.hidden = (pageCount <= 1);

    [self layoutPages];
}

- (void)layoutPages
{
    CGRect bounds = self.pagingScrollView.bounds;
    if (CGRectGetWidth(bounds) <= 0.0)
    {
        return;
    }

    CGFloat pageWidth = CGRectGetWidth(bounds);
    CGFloat pageHeight = CGRectGetHeight(bounds) - NXROMDockHeight - 40.0;

    self.pagingScrollView.contentSize = CGSizeMake(pageWidth * self.pages.count, pageHeight);

    for (NSUInteger index = 0; index < self.pages.count; index++)
    {
        self.pages[index].frame = CGRectMake(pageWidth * index, 0.0, pageWidth, pageHeight);
    }
}

- (void)rebuildDock
{
    UIView *host = self.dock.contentView;
    if (host == nil)
    {
        return;
    }

    for (UIView *view in host.subviews.copy)
    {
        [view removeFromSuperview];
    }

    NSUInteger dockCount = MIN(4, self.applications.count);
    for (NSUInteger index = 0; index < dockCount; index++)
    {
        NXROMIconButton *button = [[NXROMIconButton alloc] initWithApplication:self.applications[index] size:58.0];
        button.showsLabel = NO;
        button.delegate = self;
        [host addSubview:button];
    }

    [self layoutDock];
}

- (void)layoutDock
{
    UIView *host = self.dock.contentView;
    if (host == nil)
    {
        return;
    }

    CGFloat hostWidth = CGRectGetWidth(self.dock.bounds);
    if (hostWidth <= 0.0)
    {
        return;
    }

    NSMutableArray<UIView *> *buttons = [NSMutableArray array];
    for (UIView *view in host.subviews)
    {
        if ([view isKindOfClass:NXROMIconButton.class])
        {
            [buttons addObject:view];
        }
    }

    if (buttons.count == 0)
    {
        return;
    }

    CGFloat slot = hostWidth / (CGFloat)buttons.count;
    for (NSUInteger index = 0; index < buttons.count; index++)
    {
        buttons[index].frame = CGRectMake(slot * index + (slot - 58.0) / 2.0,
                                          (NXROMDockHeight - 58.0) / 2.0,
                                          58.0,
                                          58.0);
    }
}

#pragma mark - 交互

- (void)iconButtonTapped:(NXROMIconButton *)button
{
    NXROMApplication *application = button.application;

    if (application.kind == NXROMAppKindFolder)
    {
        NXROMFolderViewController *folder = [[NXROMFolderViewController alloc] init];
        folder.folder = application;
        __weak typeof(self) weakSelf = self;
        folder.openHandler = ^(NXROMApplication *inner) {
            if (weakSelf.openApplicationHandler)
            {
                weakSelf.openApplicationHandler(inner, nil);
            }
        };
        folder.modalPresentationStyle = UIModalPresentationOverFullScreen;
        folder.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [self presentViewController:folder animated:YES completion:nil];
        return;
    }

    if (self.openApplicationHandler)
    {
        self.openApplicationHandler(application, button);
    }
}

- (void)pageControlChanged:(UIPageControl *)control
{
    CGPoint offset = CGPointMake(CGRectGetWidth(self.pagingScrollView.bounds) * control.currentPage, 0.0);
    [self.pagingScrollView setContentOffset:offset animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat width = CGRectGetWidth(scrollView.bounds);
    if (width <= 0.0)
    {
        return;
    }

    NSUInteger page = (NSUInteger)lround(scrollView.contentOffset.x / width);
    if (self.pageControl.numberOfPages > 0)
    {
        self.pageControl.currentPage = MIN(page, self.pageControl.numberOfPages - 1);
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateBegan)
    {
        return;
    }

    [NXROMDesign mediumImpact];
    [self setEditing:!self.isEditing];
}

- (void)setEditing:(BOOL)editing
{
    _editing = editing;

    for (NXROMPageView *page in self.pages)
    {
        for (UIView *view in page.subviews)
        {
            if (![view isKindOfClass:NXROMIconButton.class])
            {
                continue;
            }

            if (editing)
            {
                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
                animation.fromValue = @(-0.019);
                animation.toValue = @(0.019);
                animation.duration = 0.14;
                animation.autoreverses = YES;
                animation.repeatCount = HUGE_VALF;
                animation.beginTime = CACurrentMediaTime() + (arc4random_uniform(120) / 1000.0);
                [view.layer addAnimation:animation forKey:@"nxrom.wiggle"];
            }
            else
            {
                [view.layer removeAnimationForKey:@"nxrom.wiggle"];
                view.transform = CGAffineTransformIdentity;
            }
        }
    }
}

- (void)handleControlCenterEdge:(UIScreenEdgePanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded && self.openControlCenterHandler)
    {
        self.openControlCenterHandler();
    }
}

- (void)handleSwitcherEdge:(UIScreenEdgePanGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateEnded)
    {
        return;
    }
    if ([gesture velocityInView:self.view].y < -300.0 && self.openAppSwitcherHandler)
    {
        self.openAppSwitcherHandler();
    }
}

- (void)exitEditingIfNeeded
{
    if (self.isEditing)
    {
        [self setEditing:NO];
    }
}

@end
