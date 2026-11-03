/*
 * Files.app — ROM 自带的极简文件浏览器
 *
 * guest 进程看到的是 ksurface 的虚拟根（vroot）：`/` 就是 ROM 的 rootfs，
 * 所以这里直接按绝对路径浏览就行。
 */

#import <UIKit/UIKit.h>

@interface NXFilesListViewController : UITableViewController
@property (nonatomic, copy) NSString *path;
- (instancetype)initWithPath:(NSString *)path;
@end

@implementation NXFilesListViewController

- (instancetype)initWithPath:(NSString *)path
{
    self = [super initWithStyle:UITableViewStylePlain];
    if(self)
    {
        _path = [path copy];
        self.title = [path lastPathComponent].length > 0 ? [path lastPathComponent] : @"/";
    }
    return self;
}

- (NSArray<NSString *> *)entries
{
    NSArray<NSString *> *items = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.path error:nil];
    return [items sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (BOOL)isDirectory:(NSString *)name
{
    NSString *full = [self.path stringByAppendingPathComponent:name];
    BOOL directory = NO;
    [NSFileManager.defaultManager fileExistsAtPath:full isDirectory:&directory];
    return directory;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)[self entries].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *name = [self entries][(NSUInteger)indexPath.row];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }

    BOOL directory = [self isDirectory:name];
    cell.textLabel.text = name;
    cell.textLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
    cell.imageView.image = [UIImage systemImageNamed:directory ? @"folder" : @"doc"];
    cell.imageView.tintColor = directory ? UIColor.systemBlueColor : UIColor.secondaryLabelColor;

    NSString *full = [self.path stringByAppendingPathComponent:name];
    NSDictionary<NSFileAttributeKey, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:full error:nil];
    if(directory)
    {
        cell.detailTextLabel.text = @"目录";
    }
    else
    {
        unsigned long long size = [attributes[NSFileSize] unsignedLongLongValue];
        cell.detailTextLabel.text = [NSByteCountFormatter stringFromByteCount:(long long)size
                                                                  countStyle:NSByteCountFormatterCountStyleFile];
    }
    cell.accessoryType = directory ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSString *name = [self entries][(NSUInteger)indexPath.row];
    NSString *full = [self.path stringByAppendingPathComponent:name];

    if([self isDirectory:name])
    {
        [self.navigationController pushViewController:[[NXFilesListViewController alloc] initWithPath:full] animated:YES];
        return;
    }

    NSData *data = [NSData dataWithContentsOfFile:full options:0 error:nil];
    NSString *preview = nil;
    if(data.length > 0 && data.length < 64 * 1024)
    {
        preview = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:name
                                                                  message:preview.length > 0 ? preview : [NSString stringWithFormat:@"%@\n%llu bytes", full, data.length]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

@interface NXFilesAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation NXFilesAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    UINavigationController *root = [[UINavigationController alloc] initWithRootViewController:[[NXFilesListViewController alloc] initWithPath:@"/"]];
    root.navigationBar.prefersLargeTitles = NO;

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool
    {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(NXFilesAppDelegate.class));
    }
}
