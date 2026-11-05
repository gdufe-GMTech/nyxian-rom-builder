/*
 * NXROMSettingsViewController.m
 *
 * 设置：UITableViewController(insetGrouped) + UIListContentConfiguration + UISwitch。
 * 不画任何自定义图形，全部系统单元格。
 */

#import "NXROMSettingsViewController.h"
#import "NXROMSystemInfo.h"
#import "NXROMAppRegistry.h"
#import "NXROMDesign.h"

static NSString *const kNXROMKextToggle = @"nyxian.boot.kextLoading";
static NSString *const kNXROMLogToggle = @"nyxian.boot.log.obfuscated";

@interface NXROMListViewController : UITableViewController
@property (nonatomic, copy) NSString *listTitle;
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *rows;   /* [主标题, 副标题] */
@end

@implementation NXROMListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = self.listTitle;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSArray<NSString *> *row = self.rows[(NSUInteger)indexPath.row];

    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = row.firstObject;
    content.secondaryText = (row.count > 1) ? row[1] : nil;
    content.secondaryTextProperties.color = UIColor.secondaryLabelColor;
    cell.contentConfiguration = content;

    return cell;
}

@end

@interface NXROMSettingsViewController ()

@property (nonatomic, strong) NSArray<NSArray<NSDictionary<NSString *, NSString *> *> *> *sections;

@end

@implementation NXROMSettingsViewController

@synthesize sections = _sections;

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"设置";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"switch"];
}

- (NSArray<NSArray<NSDictionary<NSString *, NSString *> *> *> *)sections
{
    if (_sections != nil)
    {
        return _sections;
    }

    NXROMAppRegistry *registry = [NXROMAppRegistry shared];
    NSUInteger appCount = registry.applications.count;

    _sections = @[
        @[
            @{ @"title": @"机型",
               @"value": UIDevice.currentDevice.model ?: @"iPhone",
               @"symbol": @"iphone" },
            @{ @"title": @"系统版本",
               @"value": [NSString stringWithFormat:@"iOS %@", UIDevice.currentDevice.systemVersion ?: @"?"],
               @"symbol": @"gearshape" },
            @{ @"title": @"主机名",
               @"value": [NXROMSystemInfo hostname] ?: @"localhost",
               @"symbol": @"network" },
            @{ @"title": @"ROM 槽位",
               @"value": [NXROMSystemInfo romSlotDirectory].lastPathComponent ?: @"未挂载",
               @"symbol": @"internaldrive" },
        ],
        @[
            @{ @"title": @"应用数量",
               @"value": [NSString stringWithFormat:@"%lu", (unsigned long)appCount],
               @"symbol": @"square.grid.2x2" },
            @{ @"title": @"内核扩展",
               @"value": [NSString stringWithFormat:@"%lu", (unsigned long)[NXROMSystemInfo kextCount]],
               @"symbol": @"shippingbox" },
            @{ @"title": @"进程",
               @"value": [NSString stringWithFormat:@"%lu", (unsigned long)[NXROMSystemInfo processCount]],
               @"symbol": @"cpu" },
        ],
        @[
            @{ @"title": @"启动时加载 ROM kext", @"switch": kNXROMKextToggle },
            @{ @"title": @"日志混淆", @"switch": kNXROMLogToggle },
        ],
    ];

    return _sections;
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.sections[(NSUInteger)section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section)
    {
        case 0: return @"设备";
        case 1: return @"系统";
        case 2: return @"启动";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary<NSString *, NSString *> *row = self.sections[(NSUInteger)indexPath.section][(NSUInteger)indexPath.row];

    NSString *toggleKey = row[@"switch"];
    if (toggleKey != nil)
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"switch" forIndexPath:indexPath];

        UIListContentConfiguration *content = [UIListContentConfiguration cellConfiguration];
        content.text = row[@"title"];
        cell.contentConfiguration = content;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:toggleKey];
        toggle.tag = (NSInteger)indexPath.section * 1000 + (NSInteger)indexPath.row;
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;

        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];

    UIListContentConfiguration *content = [UIListContentConfiguration valueCellConfiguration];
    content.text = row[@"title"];
    content.secondaryText = row[@"value"];
    content.image = [NXROMDesign symbolNamed:(row[@"symbol"] ?: @"circle") pointSize:15.0 weight:UIFontWeightSemibold];
    content.imageProperties.tintColor = UIColor.systemBlueColor;
    cell.contentConfiguration = content;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section != 1 || indexPath.row == 0)
    {
        return;
    }

    NXROMListViewController *list = [[NXROMListViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];

    if (indexPath.row == 1)
    {
        list.listTitle = @"内核扩展";
        NSMutableArray<NSArray<NSString *> *> *rows = [NSMutableArray array];
        for (NSDictionary *kext in [NXROMSystemInfo romKexts])
        {
            NSString *identifier = kext[@"identifier"] ?: (kext[@"bundle"] ?: @"?");
            NSString *loaded = [kext[@"loaded"] boolValue] ? @"已加载" : @"未加载";
            [rows addObject:@[ identifier, loaded ]];
        }
        list.rows = (rows.count > 0) ? rows : @[ @[ @"没有 ROM kext", @"把 .kext 放进 <slot>/kexts" ] ];
    }
    else
    {
        list.listTitle = @"进程";
        NSMutableArray<NSArray<NSString *> *> *rows = [NSMutableArray array];
        for (NSDictionary *process in [NXROMSystemInfo processes])
        {
            NSString *name = process[@"name"] ?: @"?";
            NSString *detail = [NSString stringWithFormat:@"pid %@  uid %@",
                                process[@"pid"] ?: @"?", process[@"uid"] ?: @"?"];
            [rows addObject:@[ name, detail ]];
        }
        list.rows = (rows.count > 0) ? rows : @[ @[ @"没有进程", @"" ] ];
    }

    [self.navigationController pushViewController:list animated:YES];
}

- (void)toggleChanged:(UISwitch *)sender
{
    NSInteger index = sender.tag;
    NSInteger section = index / 1000;
    NSInteger row = index % 1000;

    NSDictionary<NSString *, NSString *> *item = self.sections[(NSUInteger)section][(NSUInteger)row];
    NSString *key = item[@"switch"];
    if (key != nil)
    {
        [NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:key];
        [NSUserDefaults.standardUserDefaults synchronize];
    }
}

@end
