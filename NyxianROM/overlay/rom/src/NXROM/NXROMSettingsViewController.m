/*
 * NXROMSettingsViewController.m
 */

#import "NXROMSettingsViewController.h"
#import "NXROMSystemInfo.h"
#import "NXROMAppRegistry.h"
#import "NXROMDesign.h"

#import <LindChain/ProcEnvironment/PEUserspaceManager.h>
#import <LindChain/ProcEnvironment/Surface/trust/trust.h>
#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>

static NSString *const kNXROMModeKey = @"nyxian.boot.entitlements.mode";
static NSString *const kNXROMKextKey = @"nyxian.boot.kextLoading";

#pragma mark - 行模型

typedef NS_ENUM(NSInteger, NXROMSettingsRowKind) {
    NXROMSettingsRowKindNavigation = 0,
    NXROMSettingsRowKindSwitch = 1,
    NXROMSettingsRowKindValue = 2,
};

@interface NXROMSettingsRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *value;
@property (nonatomic, copy, nullable) NSString *symbolName;
@property (nonatomic, strong, nullable) UIColor *tintColor;
@property (nonatomic) NXROMSettingsRowKind kind;
@property (nonatomic, copy, nullable) void (^action)(NXROMSettingsViewController *controller);
@property (nonatomic, copy, nullable) NSString *switchKey;
@end

@implementation NXROMSettingsRow
@end

#pragma mark - 列表页

@interface NXROMListViewController : UITableViewController
@property (nonatomic, copy) NSString *header;
@property (nonatomic, copy) NSArray<NSString *> *lines;
@property (nonatomic) BOOL monospaced;
@end

@implementation NXROMListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.lines.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.numberOfLines = 0;
    }

    NSString *line = self.lines[(NSUInteger)indexPath.row];
    cell.textLabel.text = line;
    cell.textLabel.font = self.monospaced
        ? [UIFont monospacedSystemFontOfSize:10.0 weight:UIFontWeightRegular]
        : [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    return cell;
}

@end

#pragma mark - 设置

@interface NXROMSettingsViewController ()
@property (nonatomic, strong) NSArray<NSArray<NXROMSettingsRow *> *> *sections;
@property (nonatomic, copy) NSArray<NSString *> *sectionTitles;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UISwitch *> *switches;

- (void)buildSections;
- (void)showListWithTitle:(NSString *)title lines:(NSArray<NSString *> *)lines monospaced:(BOOL)monospaced;
- (void)chooseEnforcementMode;
- (void)confirmTitle:(NSString *)title message:(nullable NSString *)message action:(NSString *)action handle:(void (^)(void))handle;
- (NSString *)modeTitle;
@end

@implementation NXROMSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"设置";
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.rowHeight = 46.0;
    self.switches = [NSMutableDictionary dictionary];

    [self buildSections];
}

- (void)buildSections
{
    __weak typeof(self) weakSelf = self;

    NXROMSettingsRow *device = [NXROMSettingsRow new];
    device.kind = NXROMSettingsRowKindValue;
    device.title = UIDevice.currentDevice.model;
    device.value = [NSString stringWithFormat:@"iOS %@", UIDevice.currentDevice.systemVersion];
    device.symbolName = @"iphone";
    device.tintColor = [UIColor systemGrayColor];

    NXROMSettingsRow *hostname = [NXROMSettingsRow new];
    hostname.kind = NXROMSettingsRowKindValue;
    hostname.title = @"主机名";
    hostname.value = [NXROMSystemInfo hostname];
    hostname.symbolName = @"network";
    hostname.tintColor = [UIColor systemBlueColor];

    NXROMSettingsRow *processes = [NXROMSettingsRow new];
    processes.kind = NXROMSettingsRowKindNavigation;
    processes.title = @"进程";
    processes.value = [NSString stringWithFormat:@"%lu", (unsigned long)[NXROMSystemInfo processCount]];
    processes.symbolName = @"cpu";
    processes.tintColor = [UIColor systemGreenColor];
    processes.action = ^(NXROMSettingsViewController *controller) {
        NSArray<NSDictionary *> *items = [NXROMSystemInfo processes];
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        for(NSDictionary *item in items)
        {
            [lines addObject:[NSString stringWithFormat:@"%@  pid %@  uid %@",
                              item[@"name"], item[@"pid"], item[@"uid"]]];
        }
        [weakSelf showListWithTitle:@"进程"
                              lines:lines.count ? lines : @[ @"(无)" ]
                        monospaced:NO];
    };

    NXROMSettingsRow *kexts = [NXROMSettingsRow new];
    kexts.kind = NXROMSettingsRowKindNavigation;
    kexts.title = @"内核扩展";
    kexts.value = [NSString stringWithFormat:@"%lu", (unsigned long)[NXROMSystemInfo kextCount]];
    kexts.symbolName = @"shippingbox";
    kexts.tintColor = [UIColor systemPurpleColor];
    kexts.action = ^(NXROMSettingsViewController *controller) {
        NSArray<NSString *> *identifiers = [NXROMSystemInfo kextIdentifiers];
        [weakSelf showListWithTitle:@"内核扩展"
                              lines:identifiers.count ? identifiers : @[ @"(无)" ]
                        monospaced:NO];
    };

    NXROMSettingsRow *ksurface = [NXROMSettingsRow new];
    ksurface.kind = NXROMSettingsRowKindValue;
    ksurface.title = @"ksurface";
    ksurface.value = [NXROMSystemInfo isKernelAvailable] ? @"已启动" : @"未启动";
    ksurface.symbolName = @"memorychip";
    ksurface.tintColor = [UIColor systemIndigoColor];

    NXROMSettingsRow *reboot = [NXROMSettingsRow new];
    reboot.kind = NXROMSettingsRowKindNavigation;
    reboot.title = @"重启用户空间";
    reboot.value = @"保留 ksurface";
    reboot.symbolName = @"arrow.clockwise";
    reboot.tintColor = [UIColor systemOrangeColor];
    reboot.action = ^(NXROMSettingsViewController *controller) {
        [weakSelf confirmTitle:@"重启用户空间"
                        message:@"已启动的 guest 进程会被结束。"
                         action:@"重启"
                         handle:^{ [[PEUserspaceManager shared] rebootUserspace]; }];
    };

    NXROMSettingsRow *daemons = [NXROMSettingsRow new];
    daemons.kind = NXROMSettingsRowKindNavigation;
    daemons.title = @"重载守护进程";
    daemons.value = @"bootstrapd / compilerd";
    daemons.symbolName = @"gearshape.2";
    daemons.tintColor = [UIColor systemTealColor];
    daemons.action = ^(NXROMSettingsViewController *controller) {
        [weakSelf confirmTitle:@"重载守护进程" message:nil action:@"重载" handle:^{
            [[PEUserspaceManager shared] reloadDaemons];
        }];
    };

    NXROMSettingsRow *restore = [NXROMSettingsRow new];
    restore.kind = NXROMSettingsRowKindNavigation;
    restore.title = @"恢复默认状态";
    restore.value = @"清理应用缓存";
    restore.symbolName = @"arrow.counterclockwise";
    restore.tintColor = [UIColor systemRedColor];
    restore.action = ^(NXROMSettingsViewController *controller) {
        [weakSelf confirmTitle:@"恢复默认状态" message:@"会清理应用缓存，不影响已安装的应用。" action:@"恢复" handle:^{
            [[PEUserspaceManager shared] restore];
        }];
    };

    NXROMSettingsRow *mode = [NXROMSettingsRow new];
    mode.kind = NXROMSettingsRowKindNavigation;
    mode.title = @"权限执行模式";
    mode.value = [self modeTitle];
    mode.symbolName = @"lock.shield";
    mode.tintColor = [UIColor systemPinkColor];
    mode.action = ^(NXROMSettingsViewController *controller) {
        [weakSelf chooseEnforcementMode];
    };

    NXROMSettingsRow *kextToggle = [NXROMSettingsRow new];
    kextToggle.kind = NXROMSettingsRowKindSwitch;
    kextToggle.title = @"开机加载 kext";
    kextToggle.symbolName = @"bolt";
    kextToggle.tintColor = [UIColor systemYellowColor];
    kextToggle.switchKey = kNXROMKextKey;

    NXROMSettingsRow *romKexts = [NXROMSettingsRow new];
    romKexts.kind = NXROMSettingsRowKindNavigation;
    romKexts.title = @"ROM 自带 kext";
    romKexts.symbolName = @"shippingbox.fill";
    romKexts.tintColor = [UIColor systemBrownColor];

    NSArray<NSDictionary *> *bundledKexts = [NXROMSystemInfo romKexts];
    NSUInteger loadedCount = 0;
    for(NSDictionary *kext in bundledKexts)
    {
        if([kext[@"loaded"] boolValue])
        {
            loadedCount++;
        }
    }
    romKexts.value = bundledKexts.count > 0
        ? [NSString stringWithFormat:@"%lu/%lu", (unsigned long)loadedCount, (unsigned long)bundledKexts.count]
        : @"无";
    romKexts.action = ^(NXROMSettingsViewController *controller) {
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        for(NSDictionary *kext in bundledKexts)
        {
            [lines addObject:[NSString stringWithFormat:@"%@  %@\n%@",
                              [kext[@"loaded"] boolValue] ? @"已加载" : @"未加载",
                              kext[@"bundle"], kext[@"identifier"]]];
        }
        [weakSelf showListWithTitle:@"ROM kext" lines:lines.count ? lines : @[ @"(无)" ] monospaced:NO];
    };

    NXROMSettingsRow *log = [NXROMSettingsRow new];
    log.kind = NXROMSettingsRowKindNavigation;
    log.title = @"内核日志";
    log.symbolName = @"text.alignleft";
    log.tintColor = [UIColor systemGrayColor];
    log.action = ^(NXROMSettingsViewController *controller) {
        NSString *dump = klog_dump() ?: @"";
        NSArray<NSString *> *lines = [dump componentsSeparatedByString:@"\n"];
        NSMutableArray<NSString *> *trimmed = [NSMutableArray array];
        for(NSString *line in lines)
        {
            if(line.length > 0)
            {
                [trimmed addObject:line];
            }
        }
        [weakSelf showListWithTitle:@"内核日志"
                              lines:trimmed.count ? trimmed : @[ @"(空)" ]
                        monospaced:YES];
    };

    NXROMSettingsRow *apps = [NXROMSettingsRow new];
    apps.kind = NXROMSettingsRowKindNavigation;
    apps.title = @"应用";
    apps.value = [NSString stringWithFormat:@"%lu", (unsigned long)[[NXROMAppRegistry shared] reload].count];
    apps.symbolName = @"square.grid.2x2";
    apps.tintColor = [UIColor systemBlueColor];
    apps.action = ^(NXROMSettingsViewController *controller) {
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        for(NXROMApplication *application in [NXROMAppRegistry shared].applications)
        {
            [lines addObject:[NSString stringWithFormat:@"%@\n%@  (%@)",
                              application.displayName,
                              application.bundleIdentifier,
                              application.kind == NXROMAppKindBuiltin ? @"系统" : @"guest"]];
        }
        [weakSelf showListWithTitle:@"应用" lines:lines.count ? lines : @[ @"(无)" ] monospaced:NO];
    };

    NXROMSettingsRow *version = [NXROMSettingsRow new];
    version.kind = NXROMSettingsRowKindValue;
    version.title = @"ROM 版本";
    version.value = @"0.2.0";
    version.symbolName = @"info.circle";
    version.tintColor = [UIColor systemGrayColor];

    self.sectionTitles = @[ @"设备", @"系统", @"用户空间", @"安全", @"启动", @"诊断", @"关于" ];
    self.sections = @[
        @[ device ],
        @[ hostname, processes, kexts, ksurface ],
        @[ reboot, daemons, restore ],
        @[ mode ],
        @[ kextToggle, romKexts ],
        @[ log, apps ],
        @[ version ],
    ];
}

#pragma mark - 展示

- (void)showListWithTitle:(NSString *)title lines:(NSArray<NSString *> *)lines monospaced:(BOOL)monospaced
{
    NXROMListViewController *list = [[NXROMListViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    list.title = title;
    list.header = title;
    list.lines = lines;
    list.monospaced = monospaced;
    [self.navigationController pushViewController:list animated:YES];
}

- (void)confirmTitle:(NSString *)title
             message:(nullable NSString *)message
              action:(NSString *)action
              handle:(void (^)(void))handle
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:action style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        handle();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)modeTitle
{
    NSString *mode = [NSUserDefaults.standardUserDefaults stringForKey:kNXROMModeKey];
    if([mode isEqualToString:@"permissive"])
    {
        return @"Permissive";
    }
    if([mode isEqualToString:@"disabled"])
    {
        return @"Disabled";
    }
    return @"Enforcing";
}

- (void)chooseEnforcementMode
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"权限执行模式"
                                                                  message:@"下次启动生效"
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray<NSString *> *modes = @[ @"enforcing", @"permissive", @"disabled" ];
    NSArray<NSString *> *titles = @[ @"Enforcing（默认）", @"Permissive（放行并记录）", @"Disabled（不检查）" ];

    for(NSUInteger index = 0; index < modes.count; index++)
    {
        NSString *mode = modes[index];
        [sheet addAction:[UIAlertAction actionWithTitle:titles[index]
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            [NSUserDefaults.standardUserDefaults setObject:mode forKey:kNXROMModeKey];

            PEEnforcementMode enforcement = kPEEnforcementModeEnforcing;
            if([mode isEqualToString:@"permissive"])
            {
                enforcement = kPEEnforcementModePermissive;
            }
            else if([mode isEqualToString:@"disabled"])
            {
                enforcement = kPEEnforcementModeDisabled;
            }
            trust_enforcement_set_mode(enforcement);
            [self.tableView reloadData];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                               CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - 表格

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)self.sections.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return self.sectionTitles[(NSUInteger)section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.sections[(NSUInteger)section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NXROMSettingsRow *row = self.sections[(NSUInteger)indexPath.section][(NSUInteger)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"row"];
        cell.textLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    }

    cell.textLabel.text = row.title;
    cell.detailTextLabel.text = row.value;

    if(row.symbolName.length > 0)
    {
        cell.imageView.image = [self tileImageForRow:row];
        cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    else
    {
        cell.imageView.image = nil;
    }

    if(row.kind == NXROMSettingsRowKindSwitch)
    {
        UISwitch *toggle = self.switches[row.switchKey];
        if(toggle == nil)
        {
            toggle = [[UISwitch alloc] init];
            toggle.onTintColor = [UIColor systemGreenColor];
            [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            self.switches[row.switchKey] = toggle;
        }
        toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:row.switchKey];
        cell.accessoryView = toggle;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    else
    {
        cell.accessoryView = nil;
        cell.accessoryType = row.kind == NXROMSettingsRowKindNavigation
            ? UITableViewCellAccessoryDisclosureIndicator
            : UITableViewCellAccessoryNone;
        cell.selectionStyle = row.kind == NXROMSettingsRowKindNavigation
            ? UITableViewCellSelectionStyleDefault
            : UITableViewCellSelectionStyleNone;
    }

    return cell;
}

- (UIImage *)tileImageForRow:(NXROMSettingsRow *)row
{
    CGFloat size = NXROMSymbolTileSize;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGRect rect = CGRectMake(0, 0, size, size);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:NXROMSymbolTileCornerRadius];
        [(row.tintColor ?: UIColor.systemGrayColor) setFill];
        [path fill];

        UIImage *symbol = [UIImage systemImageNamed:row.symbolName];
        symbol = [symbol imageByApplyingSymbolConfiguration:
                  [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold]];
        CGSize symbolSize = symbol.size;
        [symbol drawInRect:CGRectMake((size - symbolSize.width) / 2.0, (size - symbolSize.height) / 2.0,
                                      symbolSize.width, symbolSize.height)];
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NXROMSettingsRow *row = self.sections[(NSUInteger)indexPath.section][(NSUInteger)indexPath.row];
    if(row.action != nil)
    {
        row.action(self);
    }
}

- (void)switchChanged:(UISwitch *)sender
{
    [NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:kNXROMKextKey];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"需要重启用户空间"
                                                                  message:@"kext 加载开关在下次启动生效。"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"现在重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[PEUserspaceManager shared] rebootUserspace];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"稍后" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
