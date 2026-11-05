/*
 * NXROMBuiltinApps.m
 *
 * ROM 内置 App：时钟 / 计算器 / 文件。
 * 全部使用系统控件（UILabel、UISegmentedControl、UIButton + UIButtonConfiguration、
 * UITableView + UIListContentConfiguration），不画自定义图形。
 */

#import "NXROMBuiltinApps.h"
#import "NXROMDesign.h"

#pragma mark - 时钟

@interface NXROMClockViewController ()

@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDate *startDate;

@end

@implementation NXROMClockViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;
    self.startDate = NSDate.date;

    self.timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.textAlignment = NSTextAlignmentCenter;
    self.timeLabel.font = [NXROMDesign roundedFontOfSize:78.0 weight:UIFontWeightLight];
    self.timeLabel.textColor = UIColor.whiteColor;
    self.timeLabel.adjustsFontSizeToFitWidth = YES;
    self.timeLabel.minimumScaleFactor = 0.5;
    [self.view addSubview:self.timeLabel];

    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[ @"世界时钟", @"闹钟", @"秒表", @"计时器" ]];
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.segmentedControl.selectedSegmentIndex = 0;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.segmentedControl];

    self.detailLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailLabel.textAlignment = NSTextAlignmentCenter;
    self.detailLabel.numberOfLines = 0;
    self.detailLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
    self.detailLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
    [self.view addSubview:self.detailLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.timeLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.timeLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:80.0],
        [self.timeLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
        [self.timeLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],

        [self.segmentedControl.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.timeLabel.bottomAnchor constant:24.0],

        [self.detailLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:32.0],
        [self.detailLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-32.0],
        [self.detailLabel.topAnchor constraintEqualToAnchor:self.segmentedControl.bottomAnchor constant:28.0],
    ]];

    [self refresh];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
}

- (void)dealloc
{
    [self.timer invalidate];
}

- (void)segmentChanged:(UISegmentedControl *)control
{
    [self refresh];
}

- (void)refresh
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"HH:mm:ss";
    self.timeLabel.text = [formatter stringFromDate:NSDate.date];

    switch (self.segmentedControl.selectedSegmentIndex)
    {
        case 0:
        {
            NSTimeZone *zone = NSTimeZone.localTimeZone;
            self.detailLabel.text = [NSString stringWithFormat:@"%@\n%@",
                                     zone.name,
                                     [NSString stringWithFormat:@"%+ld 小时", (long)(zone.secondsFromGMT / 3600)]];
            break;
        }
        case 1:
            self.detailLabel.text = @"还没有闹钟。\n（ROM 内置版本只做展示）";
            break;
        case 2:
        {
            NSTimeInterval elapsed = -[self.startDate timeIntervalSinceNow];
            self.detailLabel.text = [NSString stringWithFormat:@"%02d:%02d.%02d",
                                     (int)(elapsed / 60.0),
                                     (int)fmod(elapsed, 60.0),
                                     (int)(fmod(elapsed, 1.0) * 100)];
            break;
        }
        default:
        {
            NSTimeInterval remaining = 300.0;
            self.detailLabel.text = @"05:00\n（ROM 内置版本只做展示）";
            break;
        }
    }
}

@end

#pragma mark - 计算器

@interface NXROMCalculatorViewController ()

@property (nonatomic, strong) UILabel *displayLabel;
@property (nonatomic, assign) double accumulator;
@property (nonatomic, assign) BOOL pendingOperation;
@property (nonatomic, copy) NSString *pendingOperator;

@end

@implementation NXROMCalculatorViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;

    self.displayLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.displayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.displayLabel.textAlignment = NSTextAlignmentRight;
    self.displayLabel.font = [NXROMDesign roundedFontOfSize:64.0 weight:UIFontWeightLight];
    self.displayLabel.textColor = UIColor.whiteColor;
    self.displayLabel.adjustsFontSizeToFitWidth = YES;
    self.displayLabel.minimumScaleFactor = 0.4;
    self.displayLabel.text = @"0";
    [self.view addSubview:self.displayLabel];

    NSArray<NSArray<NSString *> *> *rows = @[
        @[ @"AC", @"±", @"%", @"÷" ],
        @[ @"7", @"8", @"9", @"×" ],
        @[ @"4", @"5", @"6", @"−" ],
        @[ @"1", @"2", @"3", @"+" ],
        @[ @"0", @".", @"=" ],
    ];

    UIStackView *column = [[UIStackView alloc] initWithFrame:CGRectZero];
    column.translatesAutoresizingMaskIntoConstraints = NO;
    column.axis = UILayoutConstraintAxisVertical;
    column.spacing = 12.0;
    column.distribution = UIStackViewDistributionFillEqually;
    [self.view addSubview:column];

    for (NSArray<NSString *> *row in rows)
    {
        UIStackView *line = [[UIStackView alloc] initWithFrame:CGRectZero];
        line.axis = UILayoutConstraintAxisHorizontal;
        line.spacing = 12.0;
        line.distribution = UIStackViewDistributionFillEqually;

        for (NSString *title in row)
        {
            [line addArrangedSubview:[self buttonWithTitle:title]];
        }

        [column addArrangedSubview:line];
    }

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.displayLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24.0],
        [self.displayLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24.0],
        [self.displayLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:40.0],
        [self.displayLabel.heightAnchor constraintEqualToConstant:96.0],

        [column.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16.0],
        [column.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16.0],
        [column.topAnchor constraintEqualToAnchor:self.displayLabel.bottomAnchor constant:20.0],
        [column.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12.0],
    ]];
}

- (UIButton *)buttonWithTitle:(NSString *)title
{
    BOOL isOperator = [@[ @"÷", @"×", @"−", @"+", @"=" ] containsObject:title];
    BOOL isFunction = [@[ @"AC", @"±", @"%" ] containsObject:title];

    UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.baseBackgroundColor = isOperator ? UIColor.systemOrangeColor
        : (isFunction ? UIColor.systemGrayColor : [UIColor colorWithWhite:0.22 alpha:1.0]);
    configuration.baseForegroundColor = UIColor.whiteColor;
    configuration.attributedTitle = [[NSAttributedString alloc]
        initWithString:title
            attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:30.0 weight:UIFontWeightMedium] }];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.configuration = configuration;
    [button addTarget:self action:@selector(keyTapped:) forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:64.0].active = YES;

    return button;
}

- (void)keyTapped:(UIButton *)sender
{
    NSString *title = sender.configuration.attributedTitle.string;
    [NXROMDesign lightImpact];

    if ([title isEqualToString:@"AC"])
    {
        self.accumulator = 0.0;
        self.pendingOperation = NO;
        self.pendingOperator = nil;
        self.displayLabel.text = @"0";
        return;
    }

    if ([title isEqualToString:@"±"] || [title isEqualToString:@"%"])
    {
        double value = self.displayLabel.text.doubleValue;
        value = [title isEqualToString:@"±"] ? -value : value / 100.0;
        self.displayLabel.text = [self format:value];
        return;
    }

    if ([title isEqualToString:@"÷"] || [title isEqualToString:@"×"] ||
        [title isEqualToString:@"−"] || [title isEqualToString:@"+"])
    {
        self.accumulator = self.displayLabel.text.doubleValue;
        self.pendingOperation = YES;
        self.pendingOperator = title;
        self.displayLabel.text = @"0";
        return;
    }

    if ([title isEqualToString:@"="])
    {
        if (!self.pendingOperation || self.pendingOperator == nil)
        {
            return;
        }

        double value = self.displayLabel.text.doubleValue;
        double result = self.accumulator;

        if ([self.pendingOperator isEqualToString:@"+"]) result += value;
        else if ([self.pendingOperator isEqualToString:@"−"]) result -= value;
        else if ([self.pendingOperator isEqualToString:@"×"]) result *= value;
        else if ([self.pendingOperator isEqualToString:@"÷"]) result = (value == 0.0) ? 0.0 : result / value;

        self.pendingOperation = NO;
        self.pendingOperator = nil;
        self.displayLabel.text = [self format:result];
        return;
    }

    NSString *current = self.displayLabel.text;
    if ([current isEqualToString:@"0"] && ![title isEqualToString:@"."])
    {
        current = @"";
    }
    self.displayLabel.text = [current stringByAppendingString:title];
}

- (NSString *)format:(double)value
{
    if (fabs(value - round(value)) < 0.000001)
    {
        return [NSString stringWithFormat:@"%.0f", value];
    }
    return [NSString stringWithFormat:@"%.6g", value];
}

@end

#pragma mark - 文件

@interface NXROMFilesViewController ()
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSArray<NSString *> *entries;
@end

@implementation NXROMFilesViewController

- (instancetype)initWithPath:(nullable NSString *)path
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self)
    {
        _path = [path copy];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if (self.path.length == 0)
    {
        self.path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    }

    self.title = self.path.lastPathComponent.length > 0 ? self.path.lastPathComponent : @"文件";
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];

    self.entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:nil]
        ?: @[];
    self.entries = [self.entries sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)MAX(1, self.entries.count);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];

    if (self.entries.count == 0)
    {
        content.text = @"空文件夹";
        content.secondaryText = @"把文件放进 App 的 Documents 目录后刷新";
        content.image = [NXROMDesign symbolNamed:@"folder" pointSize:16.0 weight:UIFontWeightRegular];
    }
    else
    {
        NSString *name = self.entries[(NSUInteger)indexPath.row];
        NSString *full = [self.path stringByAppendingPathComponent:name];

        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDirectory];

        NSDictionary<NSFileAttributeKey, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:full error:nil];
        NSNumber *size = attributes[NSFileSize] ?: @0;

        content.text = name;
        content.secondaryText = isDirectory ? @"文件夹"
                                            : [NSByteCountFormatter stringFromByteCount:size.longLongValue
                                                                            countStyle:NSByteCountFormatterCountStyleFile];
        content.image = [NXROMDesign symbolNamed:(isDirectory ? @"folder.fill" : @"doc.fill")
                                       pointSize:16.0
                                          weight:UIFontWeightRegular];
        content.imageProperties.tintColor = isDirectory ? UIColor.systemBlueColor : UIColor.systemGrayColor;
    }

    cell.contentConfiguration = content;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row >= (NSInteger)self.entries.count)
    {
        return;
    }

    NSString *name = self.entries[(NSUInteger)indexPath.row];
    NSString *full = [self.path stringByAppendingPathComponent:name];

    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDirectory] && isDirectory)
    {
        NXROMFilesViewController *next = [[NXROMFilesViewController alloc] initWithPath:full];
        [self.navigationController pushViewController:next animated:YES];
    }
}

@end
