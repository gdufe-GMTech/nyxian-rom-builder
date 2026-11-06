/*
 * NXROMDesign.m
 */

#import "NXROMDesign.h"

CGFloat const NXROMIconSize = 62.0;
CGFloat const NXROMIconCorner = 15.0;
CGFloat const NXROMDockHeight = 96.0;

@implementation NXROMDesign

#pragma mark - 壁纸

+ (void)applyWallpaperToView:(UIView *)view
{
    static NSString *const key = @"nxrom.wallpaper";

    for (CALayer *layer in view.layer.sublayers.copy)
    {
        if ([layer.name isEqualToString:key])
        {
            [layer removeFromSuperlayer];
        }
    }

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.name = key;
    gradient.frame = view.bounds;
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.05 green:0.07 blue:0.16 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.10 green:0.12 blue:0.28 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.22 green:0.14 blue:0.36 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.36 green:0.20 blue:0.34 alpha:1.0].CGColor,
    ];
    gradient.locations = @[ @0.0, @0.42, @0.76, @1.0 ];
    gradient.startPoint = CGPointMake(0.1, 0.0);
    gradient.endPoint = CGPointMake(0.9, 1.0);
    [view.layer insertSublayer:gradient atIndex:0];
}

#pragma mark - 液态玻璃

/*
 * UIGlassEffect 在 iOS 27 SDK 里的 ObjC 接口与 Swift 文档并不完全对应：
 * -initWithStyle: 与 isInteractive 都没有导出。为了不依赖具体方法名，
 * 这里用运行时按候选选择器查找；任何一个都不匹配时退回 UIBlurEffect。
 */
static id NXROMCallWithIntegerArg(id target, SEL selector, NSInteger value)
{
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (signature == nil)
    {
        return nil;
    }

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = selector;
    [invocation setArgument:&value atIndex:2];
    [invocation invoke];

    void *result = NULL;
    [invocation getReturnValue:&result];
    return (__bridge id)result;
}

static UIVisualEffect *NXROMCreateGlassEffect(NSInteger style, BOOL interactive)
{
    Class glassClass = NSClassFromString(@"UIGlassEffect");
    if (glassClass == Nil)
    {
        return nil;
    }

    NSInteger rawStyle = (style == 1) ? 1 : 0;   /* clear / regular */
    id effect = nil;

    /* 类工厂：+glassEffectWithStyle: / +effectWithStyle: */
    for (NSString *name in @[ @"glassEffectWithStyle:", @"effectWithStyle:", @"glassWithStyle:" ])
    {
        SEL selector = NSSelectorFromString(name);
        if ([glassClass respondsToSelector:selector])
        {
            effect = NXROMCallWithIntegerArg(glassClass, selector, rawStyle);
            if (effect != nil)
            {
                break;
            }
        }
    }

    /* 实例初始化：-initWithStyle: / -initWithGlassStyle: / -initWithEffectStyle: */
    if (effect == nil)
    {
        for (NSString *name in @[ @"initWithStyle:", @"initWithGlassStyle:", @"initWithEffectStyle:" ])
        {
            SEL selector = NSSelectorFromString(name);
            if ([glassClass instancesRespondToSelector:selector])
            {
                effect = NXROMCallWithIntegerArg([glassClass alloc], selector, rawStyle);
                if (effect != nil)
                {
                    break;
                }
            }
        }
    }

    if (effect == nil)
    {
        return nil;
    }

    if (interactive)
    {
        /* setInteractive: 与 setValue:forKey:@"interactive" 都试一遍 */
        SEL setter = NSSelectorFromString(@"setInteractive:");
        if ([effect respondsToSelector:setter])
        {
            NSMethodSignature *signature = [effect methodSignatureForSelector:setter];
            if (signature != nil)
            {
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                invocation.target = effect;
                invocation.selector = setter;
                BOOL flag = YES;
                [invocation setArgument:&flag atIndex:2];
                [invocation invoke];
            }
        }
        else
        {
            @try
            {
                [effect setValue:@(YES) forKey:@"interactive"];
            }
            @catch (__unused NSException *exception)
            {
            }
        }
    }

    return effect;
}

+ (UIVisualEffectView *)glassViewWithCornerRadius:(CGFloat)radius
                                            style:(NSInteger)style
                                      interactive:(BOOL)interactive
{
    UIVisualEffect *effect = nil;

    if (@available(iOS 26.0, *))
    {
        effect = NXROMCreateGlassEffect(style, interactive);
    }

    if (effect == nil)
    {
        effect = [UIBlurEffect effectWithStyle:(style == 1
                                               ? UIBlurEffectStyleSystemUltraThinMaterialDark
                                               : UIBlurEffectStyleSystemThickMaterialDark)];
    }

    UIVisualEffectView *view = [[UIVisualEffectView alloc] initWithEffect:effect];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.layer.cornerRadius = radius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.clipsToBounds = YES;
    return view;
}

+ (UIVisualEffectView *)glassContainerWithSpacing:(CGFloat)spacing
{
    UIVisualEffect *effect = nil;

    if (@available(iOS 26.0, *))
    {
        /* 同样走运行时：容器类的 ObjC 属性名与 Swift 文档未必一致 */
        Class containerClass = NSClassFromString(@"UIGlassContainerEffect");
        if (containerClass != Nil)
        {
            id container = [containerClass new];
            if (container != nil)
            {
                @try
                {
                    [container setValue:@(spacing) forKey:@"spacing"];
                }
                @catch (__unused NSException *exception)
                {
                }
                effect = (UIVisualEffect *)container;
            }
        }
    }

    if (effect == nil)
    {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark];
    }

    UIVisualEffectView *view = [[UIVisualEffectView alloc] initWithEffect:effect];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    return view;
}

#pragma mark - 资源

+ (UIImage *)symbolNamed:(NSString *)name pointSize:(CGFloat)pointSize weight:(UIFontWeight)weight
{
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
    return [UIImage systemImageNamed:name withConfiguration:configuration];
}

+ (UIFont *)roundedFontOfSize:(CGFloat)size weight:(UIFontWeight)weight
{
    UIFont *base = [UIFont systemFontOfSize:size weight:weight];
    if (@available(iOS 13.0, *))
    {
        UIFontDescriptor *descriptor = [base.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
        if (descriptor != nil)
        {
            return [UIFont fontWithDescriptor:descriptor size:size];
        }
    }
    return base;
}

+ (UIColor *)tintForBuiltinIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:@"settings"])
    {
        return [UIColor systemGrayColor];
    }
    if ([identifier isEqualToString:@"clock"])
    {
        return [UIColor systemOrangeColor];
    }
    if ([identifier isEqualToString:@"calculator"])
    {
        return [UIColor systemTealColor];
    }
    if ([identifier isEqualToString:@"files"])
    {
        return [UIColor systemBlueColor];
    }
    return [UIColor systemIndigoColor];
}

#pragma mark - 触感

+ (void)lightImpact
{
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [generator impactOccurred];
}

+ (void)mediumImpact
{
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [generator impactOccurred];
}

@end
