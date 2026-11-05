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

+ (UIVisualEffectView *)glassViewWithCornerRadius:(CGFloat)radius
                                            style:(NSInteger)style
                                      interactive:(BOOL)interactive
{
    UIVisualEffect *effect = nil;

    if (@available(iOS 26.0, *))
    {
        UIGlassEffect *glass = [[UIGlassEffect alloc] initWithStyle:(style == 1
                                                                    ? UIGlassEffectStyleClear
                                                                    : UIGlassEffectStyleRegular)];
        glass.isInteractive = interactive;
        effect = glass;
    }
    else
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
    if (@available(iOS 26.0, *))
    {
        UIGlassContainerEffect *effect = [[UIGlassContainerEffect alloc] init];
        effect.spacing = spacing;

        UIVisualEffectView *view = [[UIVisualEffectView alloc] initWithEffect:effect];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        return view;
    }

    /* 老系统：容器退化成一块普通玻璃，子元素各自叠在上面 */
    return [self glassViewWithCornerRadius:0.0 style:0 interactive:NO];
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
