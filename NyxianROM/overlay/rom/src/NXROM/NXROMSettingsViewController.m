/*
 * NXROMSettingsViewController.m
 *
 * 这里尽量只用公开 API + 我们手里有头文件的 ksurface 接口：
 *   trust_enforcement_set_mode() / PEUserspaceManager / klog_dump()
 * 拿不准的（NXBootstrap 之类）一律走 NSClassFromString + respondsToSelector。
 */

#import "NXROMSettingsViewController.h"
#import "NXROMSystemInfo.h"
#import "NXROMAppRegistry.h"

#import <LindChain/ProcEnvironment/PEUserspaceManager.h>
#import <LindChain/ProcEnvironment/Surface/trust/trust.h>
#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>

static NSString *const kNXROMModeKey = @"nyxian.boot.entitlements.mode";
static NSString *const kNXROMKextKey = @"nyxian.boot.kextLoading";

@interface NXROMRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *detail;
@property (nonatomic, copy, nullable) void (^action)(UIViewController *presenter);
@property (nonatomic, assign) BOOL isSwitch;
@property (nonatomic, copy, nullable) NSString *switchKey;
@end

@implementation NXROMRow
@end

@interface NXROMLogViewController : UIViewController
@property (nonatomic, strong) UITextView *textView;
@end

@implementation NXROMLogViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"内核日志";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.editable = NO;
    self.textView.alwaysBounceVertical = YES;
    self.textView.font = [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightRegular];
    self.textView.textContainerInset = UIEdgeInsetsMake(12.0, 10.0, 24.0, 10.0);
    self.textView.text = klog_dump() ?: @"(empty)";
    [self.view addSubview:self.textView];

    [NSLayoutConstraint activateConstraints:@[
        [self.textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.textView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"刷新"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(refresh)];
}

- (void)refresh
{
    self.textView.text = klog_dump() ?: @"(empty)";
}

@end

@interface NXROMSettingsViewController ()
@property (nonatomic, strong) NSArray<NSArray<NXROMRow *> *> *sections;
@property (nonatomic, copy) NSArray<NSString *> *sectionTitles;

- (void)buildSections;
- (NSString *)currentModeTitle;
- (void)chooseEnforcementMode;
- (void)confirm:(NSString *)title
        message:(nullable NSString *)message
         action:(NSString *)action
         handle:(void (^)(void))handle;
- (void)showText:(NSString *)text title:(NSString *)title;
- (void)showList:(NSArray<NSDictionary *> *)items
           title:(NSString *)title
            keys:(NSArray<NSString *> *)keys
         formats:(NSArray<NSString *> *)formats;
@end

@implementation NXROMSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"设置";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(dismissSelf)];

    [self buildSections];
}

- (void)dismissSelf
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 数据

- (void)buildSections
{
    __weak typeof(self) weakSelf = self;

    /* 系统 */
    NXROMRow *hostname = [NXROMRow new];
    hostname.title = @"主机名";
    hostname.detail = [NXROMSystemInfo hostname];

    NXROMRow *processes = [NXROMRow new];
    processes.title = @"进程";
    processes.detail = [NSString stringWithFormat:@"%lu", (unsigned long)[NXROMSystemInfo processCount]];
    processes.action = ^(UIViewController *presenter) {
        [weakSelf showList:[NXROMSystemInfo processes]
                     title:@"进程"
                      keys:@[ @"pid", @"name", @"uid" ]
                   formats:@[ @"pid %@", @"%@", @"uid %@" ]];
    };

    NXROMRow *kexts = [NXROMRow new];
    kexts.title = @"内核扩展 (kext)";
    kexts.detail = [NSString stringWithFormat:@"%lu", (unsigned long)[NXROMSystemInfo kextCount]];
    kexts.action = ^(UIViewController *presenter) {
        NSArray<NSString *> *identifiers = [NXROMSystemInfo kextIdentifiers];
        [weakSelf showText:[identifiers count] ? [identifiers componentsJoinedByString:@"\n"] : @"(none)"
                     title:@"已加载的 kext"];
    };

    NXROMRow *ksurfaceRow = [NXROMRow new];
    ksurfaceRow.title = @"ksurface";
    ksurfaceRow.detail = [NXROMSystemInfo isKernelAvailable] ? @"已启动" : @"未启动";

    /* 用户空间 */
    NXROMRow *reboot = [NXROMRow new];
    reboot.title = @"重启用户空间";
    reboot.detail = @"保留 ksurface";
    reboot.action = ^(UIViewController *presenter) {
        [weakSelf confirm:@"重启用户空间？"
                  message:@"已启动的 guest 进程会被结束。"
                   action:@"重启"
                   handle:^{
            [[PEUserspaceManager shared] rebootUserspace];
        }];
    };

    NXROMRow *daemons = [NXROMRow new];
    daemons.title = @"重载守护进程";
    daemons.detail = @"bootstrapd / compilerd";
    daemons.action = ^(UIViewController *presenter) {
        [weakSelf confirm:@"重载守护进程？" message:nil action:@"重载" handle:^{
            [[PEUserspaceManager shared] reloadDaemons];
        }];
    };

    NXROMRow *restore = [NXROMRow new];
    restore.title = @"恢复默认状态";
    restore.detail = @"清理应用缓存";
    restore.action = ^(UIViewController *presenter) {
        [weakSelf confirm:@"恢复默认状态？" message:@"会清理应用缓存，不影响已安装的应用。" action:@"恢复" handle:^{
            [[PEUserspaceManager shared] restore];
        }];
    };

    /* 安全 */
    NXROMRow *mode = [NXROMRow new];
    mode.title = @"权限执行模式";
    mode.detail = [self currentModeTitle];
    mode.action = ^(UIViewController *presenter) {
        [weakSelf chooseEnforcementMode];
    };

    /* kext 开关 */
    NXROMRow *kextToggle = [NXROMRow new];
    kextToggle.title = @"开机加载 kext";
    kextToggle.isSwitch = YES;
    kextToggle.switchKey = kNXROMKextKey;

    /* ROM 自带的 kext */
    NSArray<NSDictionary *> *romKexts = [NXROMSystemInfo romKexts];
    NSUInteger loadedCount = 0;
    for(NSDictionary *kext in romKexts)
    {
        if([kext[@"loaded"] boolValue])
        {
            loadedCount++;
        }
    }

    NXROMRow *romKextRow = [NXROMRow new];
    romKextRow.title = @"ROM 自带 kext";
    romKextRow.detail = romKexts.count > 0
        ? [NSString stringWithFormat:@"%lu/%lu 已加载", (unsigned long)loadedCount, (unsigned long)romKexts.count]
        : @"没有打包";
    romKextRow.action = ^(UIViewController *presenter) {
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        for(NSDictionary *kext in romKexts)
        {
            [lines addObject:[NSString stringWithFormat:@"%@  %@\n%@",
                              [kext[@"loaded"] boolValue] ? @"✓" : @"·",
                              kext[@"bundle"],
                              kext[@"identifier"]]];
        }
        [weakSelf showText:lines.count ? [lines componentsJoinedByString:@"\n\n"] : @"ROM 里没有 kexts/ 目录"
                     title:@"ROM kext"];
    };

    /* 诊断 */
    NXROMRow *log = [NXROMRow new];
    log.title = @"内核日志";
    log.action = ^(UIViewController *presenter) {
        NXROMLogViewController *controller = [[NXROMLogViewController alloc] init];
        [presenter.navigationController pushViewController:controller animated:YES];
    };

    NXROMRow *apps = [NXROMRow new];
    apps.title = @"已安装应用";
    apps.detail = [NSString stringWithFormat:@"%lu", (unsigned long)[[NXROMAppRegistry shared] reload].count];
    apps.action = ^(UIViewController *presenter) {
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        for(NXROMApplication *application in [NXROMAppRegistry shared].applications)
        {
            [lines addObject:[NSString stringWithFormat:@"%@  (%@)\n%@",
                              application.displayName,
                              application.bundleIdentifier,
                              application.executablePath]];
        }
        [weakSelf showText:[lines count] ? [lines componentsJoinedByString:@"\n\n"] : @"(none)" title:@"应用"];
    };

    /* 关于 */
    NXROMRow *version = [NXROMRow new];
    version.title = @"ROM";
    version.detail = @"0.1.0 (custom)";

    NXROMRow *device = [NXROMRow new];
    device.title = @"设备";
    device.detail = [NSString stringWithFormat:@"%@ · iOS %@",
                     UIDevice.currentDevice.model,
                     UIDevice.currentDevice.systemVersion];

    self.sectionTitles = @[ @"系统", @"用户空间", @"安全", @"内核扩展", @"诊断", @"关于" ];
    self.sections = @[
        @[ hostname, processes, kexts, ksurfaceRow ],
        @[ reboot, daemons, restore ],
        @[ mode ],
        @[ kextToggle, romKextRow ],
        @[ log, apps ],
        @[ version, device ],
    ];
}

- (NSString *)currentModeTitle
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

    for(NSUInteger i = 0; i < modes.count; i++)
    {
        NSString *mode = modes[i];
        [sheet addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
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
                                                               CGRectGetMidY(self.view.bounds),
                                                               1.0, 1.0);
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - 展示辅助

- (void)confirm:(NSString *)title
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

- (void)showText:(NSString *)text title:(NSString *)title
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:text
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showList:(NSArray<NSDictionary *> *)items
           title:(NSString *)title
            keys:(NSArray<NSString *> *)keys
         formats:(NSArray<NSString *> *)formats
{
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for(NSDictionary *item in items)
    {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        for(NSUInteger i = 0; i < keys.count && i < formats.count; i++)
        {
            id value = item[keys[i]] ?: @"?";
            [parts addObject:[NSString stringWithFormat:formats[i], value]];
        }
        [lines addObject:[parts componentsJoinedByString:@"  "]];
    }

    [self showText:[lines count] ? [lines componentsJoinedByString:@"\n"] : @"(none)" title:title];
}

#pragma mark - Table

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
    NXROMRow *row = self.sections[(NSUInteger)indexPath.section][(NSUInteger)indexPath.row];

    if(row.isSwitch)
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"switch"];
        if(cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"switch"];
            UISwitch *toggle = [[UISwitch alloc] init];
            [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }

        UISwitch *toggle = (UISwitch *)cell.accessoryView;
        toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:row.switchKey];
        cell.textLabel.text = row.title;
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"row"];
    }

    cell.textLabel.text = row.title;
    cell.detailTextLabel.text = row.detail;
    cell.accessoryType = row.action != nil ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = row.action != nil ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NXROMRow *row = self.sections[(NSUInteger)indexPath.section][(NSUInteger)indexPath.row];
    if(row.action != nil)
    {
        row.action(self);
    }
}

- (void)toggleChanged:(UISwitch *)sender
{
    /* 只有一个 switch，key 固定 */
    [NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:kNXROMKextKey];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"需要重启用户空间"
                                                                  message:@"kext 加载开关在下次 boot 生效。"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"现在重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[PEUserspaceManager shared] rebootUserspace];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"稍后" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
