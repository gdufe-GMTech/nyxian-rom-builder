/*
 * NXROMHomeViewController.m
 *
 * 结构：壁纸 + 横向分页容器（每页 4x6 图标）+ 胶囊页点 + 毛玻璃 Dock。
 * 不使用 UICollectionView：流式布局在横向分页下会按列铺满，与行优先顺序不符。
 */


#import "NXROMHomeViewController.h"
#import "NXROMDesign.h"

#include <math.h>
#include <stdlib.h>

#pragma mark - 图标

@class NXROMIconView;

@protocol NXROMIconViewDelegate <NSObject>
- (void)iconViewWasTapped:(NXROMIconView *)iconView;
@end

#pragma mark - 文件夹

/*
 * 文件夹内容以半透明面板呈现：标题 + 4 列图标网格，点外部或标题关闭。
 * 只做展示与启动，不实现拖拽排序。
 *
 * 声明必须放在使用它的 -presentFolder:fromView: 之前，实现留在文件末尾。
 */
@interface NXROMFolderViewController : UIViewController <NXROMIconViewDelegate>
@property (nonatomic, copy) NSArray<NXROMApplication *> *children;
@property (nonatomic, copy) void (^openHandler)(NXROMApplication *application, UIView *sourceView);
@end


@interface NXROMIconView : UIControl

@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NXROMApplication *application;
@property (nonatomic, weak) id<NXROMIconViewDelegate> delegate;
@property (nonatomic, assign, getter=isEditing) BOOL editing;

- (instancetype)initWithApplication:(NXROMApplication *)application iconSize:(CGFloat)iconSize;

@end

@implementation NXROMIconView

- (instancetype)initWithApplication:(NXROMApplication *)application iconSize:(CGFloat)iconSize
{
    self = [super initWithFrame:CGRectZero];
    if(self)
    {
        _application = application;

        _iconView = [NXROMDesign iconViewWithImage:application.icon title:application.displayName size:iconSize];
        _iconView.userInteractionEnabled = NO;
        [self addSubview:_iconView];

        _titleLabel = [UILabel new];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.text = application.displayName;
        _titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _titleLabel.layer.shadowColor = UIColor.blackColor.CGColor;
        _titleLabel.layer.shadowOpacity = 0.35;
        _titleLabel.layer.shadowRadius = 2.0;
        _titleLabel.layer.shadowOffset = CGSizeMake(0, 1);
        [self addSubview:_titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:iconSize],
            [_iconView.heightAnchor constraintEqualToConstant:iconSize],

            [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:6.0],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:-4.0],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:4.0],
        ]];

        [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)handleTap
{
    [UIView animateWithDuration:0.12
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.iconView.transform = CGAffineTransformMakeScale(0.88, 0.88);
    }
                     completion:^(BOOL finished) {
        [UIView animateWithDuration:0.18 animations:^{
            self.iconView.transform = CGAffineTransformIdentity;
        }];
    }];

    [self.delegate iconViewWasTapped:self];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    if(self.isEditing)
    {
        return;
    }
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.94, 0.94) : CGAffineTransformIdentity;
    }];
}


- (void)setEditing:(BOOL)editing
{
    _editing = editing;

    if(editing)
    {
        static NSString *const key = @"nxrom.wiggle";
        if([self.layer animationForKey:key] == nil)
        {
            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
            animation.fromValue = @(-0.022);
            animation.toValue = @(0.022);
            animation.duration = 0.13;
            animation.autoreverses = YES;
            animation.repeatCount = HUGE_VALF;
            animation.beginTime = CACurrentMediaTime() + (arc4random_uniform(100) / 1000.0);
            [self.layer addAnimation:animation forKey:key];
        }
    }
    else
    {
        [self.layer removeAllAnimations];
        self.transform = CGAffineTransformIdentity;
    }
}

@end

#pragma mark - 页
@interface NXROMPageView : UIView
@property (nonatomic, copy) NSArray<NXROMApplication *> *applications;
@property (nonatomic, weak) id<NXROMIconViewDelegate> delegate;
@property (nonatomic, assign, getter=isEditing) BOOL editing;
- (void)setApplications:(NSArray<NXROMApplication *> *)applications;
@end

@implementation NXROMPageView
{
    NSMutableArray<NXROMIconView *> *_icons;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        _icons = [NSMutableArray array];
        _applications = @[];
    }
    return self;
}

- (void)setApplications:(NSArray<NXROMApplication *> *)applications
{
    _applications = [applications copy];

    for(NXROMIconView *icon in _icons)
    {
        [icon removeFromSuperview];
    }
    [_icons removeAllObjects];

    for(NXROMApplication *application in applications)
    {
        NXROMIconView *icon = [[NXROMIconView alloc] initWithApplication:application iconSize:NXROMIconSize];
        icon.delegate = self.delegate;
        icon.editing = self.isEditing;
        [self addSubview:icon];
        [_icons addObject:icon];
    }

    [self setNeedsLayout];
}

- (void)setEditing:(BOOL)editing
{
    _editing = editing;
    for(NXROMIconView *icon in _icons)
    {
        icon.editing = editing;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    const NSUInteger columns = 4;
    const NSUInteger rows = 6;
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);

    CGFloat horizontalInset = 18.0;
    CGFloat verticalInset = 8.0;
    CGFloat columnWidth = (width - horizontalInset * 2.0) / (CGFloat)columns;
    CGFloat rowHeight = (height - verticalInset * 2.0) / (CGFloat)rows;

    for(NSUInteger index = 0; index < _icons.count; index++)
    {
        NSUInteger column = index % columns;
        NSUInteger row = index / columns;

        CGFloat x = horizontalInset + columnWidth * (CGFloat)column;
        CGFloat y = verticalInset + rowHeight * (CGFloat)row;

        NXROMIconView *icon = _icons[index];
        CGRect frame = CGRectMake(x, y, columnWidth, rowHeight);
        icon.frame = frame;
        [icon setNeedsLayout];
        [icon layoutIfNeeded];
    }
}

@end

#pragma mark - 主屏

@interface NXROMHomeViewController () <UIScrollViewDelegate, NXROMIconViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIScrollView *pagingScrollView;
@property (nonatomic, strong) UIView *pagesContainer;
@property (nonatomic, strong) NSMutableArray<NXROMPageView *> *pages;
@property (nonatomic, strong) UIView *pagePill;
@property (nonatomic, strong) NSMutableArray<UIView *> *pageDots;
@property (nonatomic, strong) UIView *dock;
@property (nonatomic, strong) NSArray<NXROMApplication *> *applications;
@property (nonatomic, assign, getter=isEditing) BOOL editing;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPress;

@end

@implementation NXROMHomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [NXROMDesign applyWallpaperToView:self.view];

    [self buildDock];
    [self buildPagePill];

    self.pagingScrollView = [UIScrollView new];
    self.pagingScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pagingScrollView.pagingEnabled = YES;
    self.pagingScrollView.showsHorizontalScrollIndicator = NO;
    self.pagingScrollView.showsVerticalScrollIndicator = NO;
    self.pagingScrollView.alwaysBounceHorizontal = NO;
    self.pagingScrollView.alwaysBounceVertical = NO;
    self.pagingScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.pagingScrollView.delegate = self;
    [self.view addSubview:self.pagingScrollView];

    self.pagesContainer = [UIView new];
    self.pagesContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.pagingScrollView addSubview:self.pagesContainer];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.pagingScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.pagingScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.pagingScrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.pagingScrollView.bottomAnchor constraintEqualToAnchor:self.pagePill.topAnchor constant:-4.0],

        [self.pagesContainer.leadingAnchor constraintEqualToAnchor:self.pagingScrollView.leadingAnchor],
        [self.pagesContainer.trailingAnchor constraintEqualToAnchor:self.pagingScrollView.trailingAnchor],
        [self.pagesContainer.topAnchor constraintEqualToAnchor:self.pagingScrollView.topAnchor],
        [self.pagesContainer.heightAnchor constraintEqualToAnchor:self.pagingScrollView.heightAnchor],
    ]];

    self.longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    self.longPress.minimumPressDuration = 0.6;
    self.longPress.delegate = self;
    [self.view addGestureRecognizer:self.longPress];

    [self reloadApplications];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutPages];
}

#pragma mark - 构件

- (void)buildDock
{
    UIVisualEffectView *dock = [NXROMDesign blurViewWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark
                                                 cornerRadius:NXROMDockCornerRadius];
    dock.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionEqualSpacing;
    stack.alignment = UIStackViewAlignmentCenter;
    [dock.contentView addSubview:stack];

    [self.view addSubview:dock];
    self.dock = dock;
    self.dock.accessibilityLabel = @"dock";

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [dock.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:14.0],
        [dock.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-14.0],
        [dock.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10.0],
        [dock.heightAnchor constraintEqualToConstant:96.0],

        [stack.leadingAnchor constraintEqualToAnchor:dock.contentView.leadingAnchor constant:18.0],
        [stack.trailingAnchor constraintEqualToAnchor:dock.contentView.trailingAnchor constant:-18.0],
        [stack.centerYAnchor constraintEqualToAnchor:dock.contentView.centerYAnchor],
        [stack.heightAnchor constraintEqualToConstant:NXROMIconSize],
    ]];
}

- (void)buildPagePill
{
    self.pagePill = [UIView new];
    self.pagePill.translatesAutoresizingMaskIntoConstraints = NO;
    self.pagePill.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.32];
    self.pagePill.layer.cornerRadius = 12.0;
    self.pagePill.layer.cornerCurve = kCACornerCurveContinuous;
    self.pagePill.userInteractionEnabled = NO;
    [self.view addSubview:self.pagePill];

    self.pageDots = [NSMutableArray array];

    [NSLayoutConstraint activateConstraints:@[
        [self.pagePill.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.pagePill.bottomAnchor constraintEqualToAnchor:self.dock.topAnchor constant:-10.0],
        [self.pagePill.heightAnchor constraintEqualToConstant:24.0],
        [self.pagePill.widthAnchor constraintGreaterThanOrEqualToConstant:36.0],
    ]];
}

/* 页点为胶囊内的圆点，数量随页数重建 */
- (void)rebuildPageDots:(NSUInteger)pageCount
{
    for(UIView *dot in self.pageDots)
    {
        [dot removeFromSuperview];
    }
    [self.pageDots removeAllObjects];

    const CGFloat dotSize = 7.0;
    const CGFloat spacing = 10.0;

    for(NSUInteger index = 0; index < pageCount; index++)
    {
        UIView *dot = [UIView new];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.layer.cornerRadius = dotSize / 2.0;
        dot.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.35];
        [self.pagePill addSubview:dot];
        [self.pageDots addObject:dot];

        [NSLayoutConstraint activateConstraints:@[
            [dot.widthAnchor constraintEqualToConstant:dotSize],
            [dot.heightAnchor constraintEqualToConstant:dotSize],
            [dot.centerYAnchor constraintEqualToAnchor:self.pagePill.centerYAnchor],
        ]];
    }

    /* 姘村钩灞呬腑鎺掑竷 */
    CGFloat totalWidth = dotSize * (CGFloat)pageCount + spacing * (CGFloat)(pageCount - 1);
    if(pageCount == 0)
    {
        return;
    }

    for(NSUInteger index = 0; index < self.pageDots.count; index++)
    {
        UIView *dot = self.pageDots[index];
        CGFloat centerX = -totalWidth / 2.0 + dotSize / 2.0 + (dotSize + spacing) * (CGFloat)index;
        [dot.centerXAnchor constraintEqualToAnchor:self.pagePill.centerXAnchor constant:centerX].active = YES;
    }

    [self.pagePill.widthAnchor constraintEqualToConstant:MAX(36.0, totalWidth + 22.0)].active = YES;
    [self updatePageDots:0];
}

- (void)updatePageDots:(NSInteger)page
{
    for(NSUInteger index = 0; index < self.pageDots.count; index++)
    {
        self.pageDots[index].backgroundColor = ((NSInteger)index == page)
            ? [UIColor colorWithWhite:1.0 alpha:0.95]
            : [UIColor colorWithWhite:1.0 alpha:0.35];
    }
}

#pragma mark - 数据

- (void)reloadApplications
{
    self.applications = [[NXROMAppRegistry shared] reload];

    NSMutableArray<NXROMApplication *> *dockApps = [NSMutableArray array];
    NSMutableArray<NXROMApplication *> *gridApps = [NSMutableArray array];

    for(NXROMApplication *application in self.applications)
    {
        if(application.kind == NXROMAppKindBuiltin && dockApps.count < 4)
        {
            [dockApps addObject:application];
        }
        else
        {
            [gridApps addObject:application];
        }
    }

    [self rebuildDockWithApplications:dockApps];
    [self rebuildPagesWithApplications:gridApps];
}

- (void)rebuildDockWithApplications:(NSArray<NXROMApplication *> *)applications
{
    UIVisualEffectView *dock = (UIVisualEffectView *)self.dock;
    UIStackView *stack = nil;
    for(UIView *subview in dock.contentView.subviews)
    {
        if([subview isKindOfClass:UIStackView.class])
        {
            stack = (UIStackView *)subview;
            break;
        }
    }
    if(stack == nil)
    {
        return;
    }

    for(UIView *view in stack.arrangedSubviews.copy)
    {
        [stack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    for(NXROMApplication *application in applications)
    {
        NXROMIconView *icon = [[NXROMIconView alloc] initWithApplication:application iconSize:64.0];
        icon.delegate = self;
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        [icon.widthAnchor constraintEqualToConstant:72.0].active = YES;
        [icon.heightAnchor constraintEqualToConstant:84.0].active = YES;
        [stack addArrangedSubview:icon];
    }
}

- (void)rebuildPagesWithApplications:(NSArray<NXROMApplication *> *)applications
{
    for(NXROMPageView *page in self.pages)
    {
        [page removeFromSuperview];
    }
    self.pages = [NSMutableArray array];

    const NSUInteger perPage = 24;
    NSUInteger pageCount = MAX(1, (applications.count + perPage - 1) / perPage);

    for(NSUInteger index = 0; index < pageCount; index++)
    {
        NSUInteger start = index * perPage;
        NSUInteger length = MIN(perPage, applications.count - MIN(start, applications.count));
        NSArray<NXROMApplication *> *slice = length > 0
            ? [applications subarrayWithRange:NSMakeRange(start, length)]
            : @[];

        NXROMPageView *page = [NXROMPageView new];
        page.delegate = self;
        page.editing = self.isEditing;
        page.applications = slice;
        [self.pagesContainer addSubview:page];
        [self.pages addObject:page];
    }

    [self rebuildPageDots:pageCount];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (void)layoutPages
{
    CGFloat width = CGRectGetWidth(self.pagingScrollView.bounds);
    CGFloat height = CGRectGetHeight(self.pagingScrollView.bounds);
    if(width <= 0.0 || height <= 0.0)
    {
        return;
    }

    for(NSUInteger index = 0; index < self.pages.count; index++)
    {
        NXROMPageView *page = self.pages[index];
        page.frame = CGRectMake(width * (CGFloat)index, 0, width, height);
        [page setNeedsLayout];
    }

    self.pagesContainer.frame = CGRectMake(0, 0, width * (CGFloat)self.pages.count, height);
    self.pagingScrollView.contentSize = CGSizeMake(width * (CGFloat)self.pages.count, height);
}

#pragma mark - 交互

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat width = CGRectGetWidth(scrollView.bounds);
    if(width <= 0.0)
    {
        return;
    }
    NSInteger page = (NSInteger)lround(scrollView.contentOffset.x / width);
    [self updatePageDots:MAX(0, MIN(page, (NSInteger)self.pages.count - 1))];
}

- (void)iconViewWasTapped:(NXROMIconView *)iconView
{
    if(self.isEditing)
    {
        [self exitEditingIfNeeded];
        return;
    }

    NXROMApplication *application = iconView.application;
    if(application.kind == NXROMAppKindFolder)
    {
        [self presentFolder:application fromView:iconView.iconView];
        return;
    }

    if(self.openApplicationHandler && application != nil)
    {
        self.openApplicationHandler(application, iconView.iconView);
    }
}

- (void)presentFolder:(NXROMApplication *)folder fromView:(UIView *)sourceView
{
    NXROMFolderViewController *controller = [[NXROMFolderViewController alloc] init];
    controller.title = folder.displayName;
    controller.children = folder.children ?: @[];
    controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
    controller.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

    __weak typeof(self) weakSelf = self;
    controller.openHandler = ^(NXROMApplication *application, UIView *iconView) {
        [weakSelf dismissViewControllerAnimated:YES completion:^{
            if(weakSelf.openApplicationHandler)
            {
                weakSelf.openApplicationHandler(application, nil);
            }
        }];
    };

    [self presentViewController:controller animated:YES completion:nil];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
    if(recognizer.state != UIGestureRecognizerStateBegan)
    {
        return;
    }
    if(self.applications.count == 0)
    {
        return;
    }

    [NXROMDesign mediumImpact];
    [self setEditing:YES];
}

- (void)setEditing:(BOOL)editing
{
    _editing = editing;
    for(NXROMPageView *page in self.pages)
    {
        page.editing = editing;
    }

    UIVisualEffectView *dock = (UIVisualEffectView *)self.dock;
    for(UIView *subview in dock.contentView.subviews)
    {
        if(![subview isKindOfClass:UIStackView.class])
        {
            continue;
        }
        for(UIView *arranged in ((UIStackView *)subview).arrangedSubviews)
        {
            if([arranged isKindOfClass:NXROMIconView.class])
            {
                ((NXROMIconView *)arranged).editing = editing;
            }
        }
    }
}

- (void)exitEditingIfNeeded
{
    if(self.isEditing)
    {
        [self setEditing:NO];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    if(self.isEditing)
    {
        [self exitEditingIfNeeded];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - 控制中心手势

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return gestureRecognizer == self.longPress;
}
@end

#pragma mark - 文件夹

@implementation NXROMFolderViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    UIVisualEffectView *panel = [NXROMDesign blurViewWithStyle:UIBlurEffectStyleSystemThickMaterialDark
                                                  cornerRadius:34.0];
    [self.view addSubview:panel];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = self.title;
    title.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    [panel.contentView addSubview:title];

    UIView *grid = [UIView new];
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    [panel.contentView addSubview:grid];

    NSMutableArray<NXROMIconView *> *icons = [NSMutableArray array];
    for(NXROMApplication *application in self.children)
    {
        NXROMIconView *icon = [[NXROMIconView alloc] initWithApplication:application iconSize:60.0];
        icon.delegate = self;
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        [grid addSubview:icon];
        [icons addObject:icon];
    }

    [NSLayoutConstraint activateConstraints:@[
        [panel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [panel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [panel.heightAnchor constraintEqualToConstant:440.0],

        [title.centerXAnchor constraintEqualToAnchor:panel.contentView.centerXAnchor],
        [title.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:28.0],

        [grid.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:16.0],
        [grid.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-16.0],
        [grid.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:22.0],
        [grid.bottomAnchor constraintEqualToAnchor:panel.contentView.bottomAnchor constant:-24.0],
    ]];

    [self.view layoutIfNeeded];

    /* 4 列网格 */
    CGFloat gridWidth = CGRectGetWidth(grid.bounds);
    CGFloat cellWidth = gridWidth / 4.0;
    CGFloat cellHeight = 96.0;

    for(NSUInteger index = 0; index < icons.count; index++)
    {
        CGFloat x = cellWidth * (CGFloat)(index % 4);
        CGFloat y = cellHeight * (CGFloat)(index / 4);
        icons[index].frame = CGRectMake(x, y, cellWidth, cellHeight);
        [icons[index] setNeedsLayout];
        [icons[index] layoutIfNeeded];
    }

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)];
    [panel addGestureRecognizer:tap];
}

- (void)iconViewWasTapped:(NXROMIconView *)iconView
{
    if(self.openHandler && iconView.application != nil)
    {
        self.openHandler(iconView.application, iconView.iconView);
    }
}

- (void)close
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
