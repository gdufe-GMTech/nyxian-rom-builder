/*
 * NXROMBuiltinApps.m
 */

#import "NXROMBuiltinApps.h"
#import "NXROMDesign.h"

#include <math.h>

#pragma mark - 表盘

@interface NXROMClockFaceView : UIView
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation NXROMClockFaceView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                  target:self
                                                selector:@selector(tick)
                                                userInfo:nil
                                                 repeats:YES];
    }
    return self;
}

- (void)dealloc
{
    [_timer invalidate];
}

- (void)tick
{
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if(context == NULL)
    {
        return;
    }

    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGFloat radius = MIN(CGRectGetWidth(rect), CGRectGetHeight(rect)) / 2.0 - 8.0;

    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:1.0 alpha:0.18].CGColor);
    CGContextSetLineWidth(context, 2.0);
    CGContextStrokeEllipseInRect(context, CGRectMake(center.x - radius, center.y - radius, radius * 2, radius * 2));

    /* 刻度 */
    for(NSInteger index = 0; index < 60; index++)
    {
        CGFloat angle = (CGFloat)index / 60.0 * (CGFloat)M_PI * 2.0 - (CGFloat)M_PI_2;
        BOOL major = (index % 5 == 0);
        CGFloat inner = radius - (major ? 12.0 : 6.0);

        CGContextSetStrokeColorWithColor(context,
            [UIColor colorWithWhite:1.0 alpha:major ? 0.75 : 0.28].CGColor);
        CGContextSetLineWidth(context, major ? 2.0 : 1.0);
        CGContextMoveToPoint(context, center.x + cos(angle) * inner, center.y + sin(angle) * inner);
        CGContextAddLineToPoint(context, center.x + cos(angle) * radius, center.y + sin(angle) * radius);
        CGContextStrokePath(context);
    }

    NSDateComponents *components = [NSCalendar.currentCalendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
                                                                 fromDate:NSDate.date];
    CGFloat seconds = (CGFloat)components.second;
    CGFloat minutes = (CGFloat)components.minute + seconds / 60.0;
    CGFloat hours = ((CGFloat)components.hour + minutes / 60.0);

    void (^drawHand)(CGFloat, CGFloat, CGFloat, UIColor *) = ^(CGFloat value, CGFloat lengthRatio, CGFloat width, UIColor *color) {
        CGFloat angle = value * (CGFloat)M_PI * 2.0 - (CGFloat)M_PI_2;
        CGContextSetStrokeColorWithColor(context, color.CGColor);
        CGContextSetLineWidth(context, width);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextMoveToPoint(context, center.x - cos(angle) * 10.0, center.y - sin(angle) * 10.0);
        CGContextAddLineToPoint(context, center.x + cos(angle) * radius * lengthRatio,
                                        center.y + sin(angle) * radius * lengthRatio);
        CGContextStrokePath(context);
    };

    drawHand(hours / 12.0, 0.52, 5.0, UIColor.whiteColor);
    drawHand(minutes / 60.0, 0.76, 3.5, UIColor.whiteColor);
    drawHand(seconds / 60.0, 0.84, 1.5, [UIColor colorWithRed:0.98 green:0.55 blue:0.28 alpha:1.0]);

    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.98 green:0.55 blue:0.28 alpha:1.0].CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(center.x - 5.0, center.y - 5.0, 10.0, 10.0));
}

@end

#pragma mark - 时钟

@interface NXROMClockViewController ()
@property (nonatomic, strong) NXROMClockFaceView *face;
@property (nonatomic, strong) UILabel *digitalLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation NXROMClockViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;
    self.title = @"时钟";

    self.face = [[NXROMClockFaceView alloc] initWithFrame:CGRectZero];
    self.face.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.face];

    self.digitalLabel = [UILabel new];
    self.digitalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.digitalLabel.font = [UIFont monospacedDigitSystemFontOfSize:54.0 weight:UIFontWeightLight];
    self.digitalLabel.textColor = UIColor.whiteColor;
    self.digitalLabel.textAlignment = NSTextAlignmentCenter;

    self.dateLabel = [UILabel new];
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dateLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    self.dateLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    self.dateLabel.textAlignment = NSTextAlignmentCenter;

    [self.view addSubview:self.digitalLabel];
    [self.view addSubview:self.dateLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.face.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.face.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12.0],
        [self.face.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.78],
        [self.face.heightAnchor constraintEqualToAnchor:self.face.widthAnchor],

        [self.digitalLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.digitalLabel.topAnchor constraintEqualToAnchor:self.face.bottomAnchor constant:18.0],

        [self.dateLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.dateLabel.topAnchor constraintEqualToAnchor:self.digitalLabel.bottomAnchor constant:2.0],
    ]];

    [self updateLabels];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                  target:self
                                                selector:@selector(updateLabels)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)dealloc
{
    [self.timer invalidate];
}

- (void)updateLabels
{
    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    timeFormatter.dateFormat = @"HH:mm:ss";
    self.digitalLabel.text = [timeFormatter stringFromDate:NSDate.date];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_Hans_CN"];
    dateFormatter.dateFormat = @"M月d日 EEEE";
    self.dateLabel.text = [dateFormatter stringFromDate:NSDate.date];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end

#pragma mark - 计算器

@interface NXROMCalculatorViewController ()
@property (nonatomic, strong) UILabel *displayLabel;
@property (nonatomic, strong) NSMutableString *input;
@property (nonatomic, assign) double accumulator;
@property (nonatomic, copy) NSString *pendingOperator;
@property (nonatomic, assign) BOOL typing;
@end

@implementation NXROMCalculatorViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;
    self.title = @"计算器";
    self.input = [NSMutableString stringWithString:@"0"];

    self.displayLabel = [UILabel new];
    self.displayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.displayLabel.font = [UIFont monospacedDigitSystemFontOfSize:64.0 weight:UIFontWeightLight];
    self.displayLabel.textColor = UIColor.whiteColor;
    self.displayLabel.textAlignment = NSTextAlignmentRight;
    self.displayLabel.adjustsFontSizeToFitWidth = YES;
    self.displayLabel.minimumScaleFactor = 0.35;
    self.displayLabel.text = @"0";
    [self.view addSubview:self.displayLabel];

    NSArray<NSArray<NSString *> *> *rows = @[
        @[ @"AC", @"±", @"%", @"÷" ],
        @[ @"7", @"8", @"9", @"×" ],
        @[ @"4", @"5", @"6", @"−" ],
        @[ @"1", @"2", @"3", @"+" ],
        @[ @"0", @".", @"=" ],
    ];

    UIStackView *column = [UIStackView new];
    column.translatesAutoresizingMaskIntoConstraints = NO;
    column.axis = UILayoutConstraintAxisVertical;
    column.spacing = 10.0;
    column.distribution = UIStackViewDistributionFillEqually;

    for(NSArray<NSString *> *row in rows)
    {
        UIStackView *rowStack = [UIStackView new];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.spacing = 10.0;
        rowStack.distribution = UIStackViewDistributionFillEqually;

        for(NSString *title in row)
        {
            UIButton *button = [self buttonWithTitle:title];
            [rowStack addArrangedSubview:button];

            if([title isEqualToString:@"0"])
            {
                [button.widthAnchor constraintEqualToAnchor:rowStack.widthAnchor multiplier:0.52].active = YES;
            }
        }
        [column addArrangedSubview:rowStack];
    }

    [self.view addSubview:column];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.displayLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24.0],
        [self.displayLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24.0],
        [self.displayLabel.bottomAnchor constraintEqualToAnchor:column.topAnchor constant:-18.0],

        [column.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16.0],
        [column.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16.0],
        [column.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16.0],
        [column.heightAnchor constraintEqualToConstant:420.0],
    ]];
}

- (UIButton *)buttonWithTitle:(NSString *)title
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:28.0 weight:UIFontWeightMedium];
    button.layer.cornerRadius = 36.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;

    BOOL isOperator = [@[ @"÷", @"×", @"−", @"+", @"=" ] containsObject:title];
    BOOL isUtility = [@[ @"AC", @"±", @"%" ] containsObject:title];

    if(isOperator)
    {
        button.backgroundColor = [UIColor colorWithRed:0.98 green:0.55 blue:0.28 alpha:1.0];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    }
    else if(isUtility)
    {
        button.backgroundColor = [UIColor colorWithWhite:0.65 alpha:1.0];
        [button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    }
    else
    {
        button.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1.0];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    }

    button.accessibilityIdentifier = title;
    [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)buttonTapped:(UIButton *)sender
{
    NSString *title = sender.accessibilityIdentifier ?: sender.titleLabel.text ?: @"";

    if([title isEqualToString:@"AC"])
    {
        self.accumulator = 0;
        self.pendingOperator = nil;
        self.typing = NO;
        [self.input setString:@"0"];
    }
    else if([title isEqualToString:@"±"])
    {
        if([self.input hasPrefix:@"-"])
        {
            [self.input deleteCharactersInRange:NSMakeRange(0, 1)];
        }
        else if(![self.input isEqualToString:@"0"])
        {
            [self.input insertString:@"-" atIndex:0];
        }
    }
    else if([title isEqualToString:@"%"])
    {
        double value = self.input.doubleValue / 100.0;
        [self.input setString:[self format:value]];
    }
    else if([title isEqualToString:@"="])
    {
        [self applyPendingOperatorWithValue:self.input.doubleValue];
        [self.input setString:[self format:self.accumulator]];
        self.pendingOperator = nil;
        self.typing = NO;
    }
    else if([@[ @"÷", @"×", @"−", @"+" ] containsObject:title])
    {
        [self applyPendingOperatorWithValue:self.input.doubleValue];
        self.pendingOperator = title;
        self.typing = NO;
        [self.input setString:[self format:self.accumulator]];
    }
    else if([title isEqualToString:@"."])
    {
        if(!self.typing)
        {
            [self.input setString:@"0"];
            self.typing = YES;
        }
        if(![self.input containsString:@"."])
        {
            [self.input appendString:@"."];
        }
    }
    else
    {
        if(!self.typing)
        {
            [self.input setString:@""];
            self.typing = YES;
        }
        if([self.input isEqualToString:@"0"])
        {
            [self.input setString:title];
        }
        else if(self.input.length < 9)
        {
            [self.input appendString:title];
        }
    }

    self.displayLabel.text = self.input.length > 0 ? self.input : @"0";
}

- (void)applyPendingOperatorWithValue:(double)value
{
    if(self.pendingOperator == nil)
    {
        self.accumulator = value;
        return;
    }

    if([self.pendingOperator isEqualToString:@"+"])
    {
        self.accumulator += value;
    }
    else if([self.pendingOperator isEqualToString:@"−"])
    {
        self.accumulator -= value;
    }
    else if([self.pendingOperator isEqualToString:@"×"])
    {
        self.accumulator *= value;
    }
    else if([self.pendingOperator isEqualToString:@"÷"])
    {
        self.accumulator = (value == 0.0) ? 0.0 : self.accumulator / value;
    }
}

- (NSString *)format:(double)value
{
    if(fabs(value - round(value)) < 1e-9)
    {
        return [NSString stringWithFormat:@"%.0f", value];
    }
    return [NSString stringWithFormat:@"%.8g", value];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end

#pragma mark - 文件

@interface NXROMFilesViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<NSString *> *entries;
@end

@implementation NXROMFilesViewController

- (instancetype)initWithPath:(nullable NSString *)path
{
    self = [super initWithNibName:nil bundle:nil];
    if(self)
    {
        _path = [path copy] ?: [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/rootfs"];
        self.title = _path.lastPathComponent.length > 0 ? _path.lastPathComponent : @"文件";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 48.0;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self reload];
}

- (void)reload
{
    NSArray<NSString *> *items = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.path error:nil];
    self.entries = [items sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        BOOL aDir = [self isDirectory:a];
        BOOL bDir = [self isDirectory:b];
        if(aDir != bDir)
        {
            return aDir ? NSOrderedAscending : NSOrderedDescending;
        }
        return [a localizedCaseInsensitiveCompare:b];
    }];
    [self.tableView reloadData];
}

- (BOOL)isDirectory:(NSString *)name
{
    BOOL directory = NO;
    [NSFileManager.defaultManager fileExistsAtPath:[self.path stringByAppendingPathComponent:name]
                                       isDirectory:&directory];
    return directory;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }

    NSString *name = self.entries[(NSUInteger)indexPath.row];
    BOOL directory = [self isDirectory:name];

    cell.textLabel.text = name;
    cell.textLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    cell.imageView.image = [UIImage systemImageNamed:directory ? @"folder.fill" : @"doc.fill"];
    cell.imageView.tintColor = directory ? UIColor.systemBlueColor : UIColor.secondaryLabelColor;
    cell.accessoryType = directory ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

    if(!directory)
    {
        NSDictionary<NSFileAttributeKey, id> *attributes =
            [NSFileManager.defaultManager attributesOfItemAtPath:[self.path stringByAppendingPathComponent:name] error:nil];
        cell.detailTextLabel.text = [NSByteCountFormatter stringFromByteCount:[attributes[NSFileSize] longLongValue]
                                                                  countStyle:NSByteCountFormatterCountStyleFile];
    }
    else
    {
        cell.detailTextLabel.text = nil;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSString *name = self.entries[(NSUInteger)indexPath.row];
    NSString *full = [self.path stringByAppendingPathComponent:name];

    if([self isDirectory:name])
    {
        [self.navigationController pushViewController:[[NXROMFilesViewController alloc] initWithPath:full] animated:YES];
    }
}

@end
