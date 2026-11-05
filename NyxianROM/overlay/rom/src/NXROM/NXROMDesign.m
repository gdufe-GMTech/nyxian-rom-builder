/*
 * NXROMDesign.m
 */

#import "NXROMDesign.h"

CGFloat const NXROMIconCornerRatio = 0.2237;
CGFloat const NXROMIconSize = 60.0;
CGFloat const NXROMGridColumnSpacing = 28.0;
CGFloat const NXROMGridRowSpacing = 26.0;
CGFloat const NXROMGridHorizontalInset = 26.0;
CGFloat const NXROMDockHeight = 92.0;
CGFloat const NXROMDockCornerRadius = 34.0;
CGFloat const NXROMPageDotSize = 7.0;
CGFloat const NXROMPageDotSpacing = 9.0;

CGFloat const NXROMSymbolTileSize = 29.0;
CGFloat const NXROMSymbolTileCornerRadius = 7.0;

@implementation NXROMDesign

+ (CAGradientLayer *)wallpaperLayerForBounds:(CGRect)bounds
{
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.frame = bounds;
    layer.colors = @[
        (id)[UIColor colorWithRed:0.04 green:0.05 blue:0.10 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.09 green:0.12 blue:0.24 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.19 green:0.13 blue:0.32 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.32 green:0.17 blue:0.34 alpha:1.0].CGColor,
    ];
    layer.locations = @[ @0.0, @0.38, @0.72, @1.0 ];
    layer.startPoint = CGPointMake(0.15, 0.0);
    layer.endPoint = CGPointMake(0.85, 1.0);
    return layer;
}

+ (void)applyWallpaperToView:(UIView *)view
{
    static const NSInteger tag = 0x4E585741; /* 'NXWA' */
    for (CALayer *layer in view.layer.sublayers.copy)
    {
        if (layer.name.integerValue == tag)
        {
            [layer removeFromSuperlayer];
        }
    }

    CAGradientLayer *wallpaper = [self wallpaperLayerForBounds:view.bounds];
    wallpaper.name = [@(tag) stringValue];
    [view.layer insertSublayer:wallpaper atIndex:0];
}

+ (UIVisualEffectView *)blurViewWithStyle:(UIBlurEffectStyle)style cornerRadius:(CGFloat)radius
{
    UIVisualEffectView *view = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.layer.cornerRadius = radius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.clipsToBounds = YES;
    return view;
}

+ (UIVisualEffect *)glassEffectWithStyle:(NSInteger)style interactive:(BOOL)interactive
{
    if (@available(iOS 26.0, *))
    {
        UIGlassEffect *effect = [[UIGlassEffect alloc] initWithStyle:(style == 1
                                                                     ? UIGlassEffectStyleClear
                                                                     : UIGlassEffectStyleRegular)];
        effect.isInteractive = interactive;
        return effect;
    }

    /* iOS 26 之前没有液态玻璃，退回系统材质 */
    return [UIBlurEffect effectWithStyle:(style == 1
                                         ? UIBlurEffectStyleSystemUltraThinMaterialDark
                                         : UIBlurEffectStyleSystemThickMaterialDark)];
}

+ (UIVisualEffectView *)glassViewWithCornerRadius:(CGFloat)radius
                                            style:(NSInteger)style
                                      interactive:(BOOL)interactive
{
    UIVisualEffectView *view = [[UIVisualEffectView alloc] initWithEffect:[self glassEffectWithStyle:style
                                                                                         interactive:interactive]];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.layer.cornerRadius = radius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.clipsToBounds = YES;
    return view;
}

+ (UIView *)symbolTileWithName:(NSString *)symbolName tint:(UIColor *)tint
{
    UIView *tile = [[UIView alloc] initWithFrame:CGRectMake(0, 0, NXROMSymbolTileSize, NXROMSymbolTileSize)];
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    tile.backgroundColor = tint;
    tile.layer.cornerRadius = NXROMSymbolTileCornerRadius;
    tile.layer.cornerCurve = kCACornerCurveContinuous;
    tile.clipsToBounds = YES;

    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbolName]];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.tintColor = UIColor.whiteColor;
    imageView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                                                            weight:UIImageSymbolWeightSemibold];
    [tile addSubview:imageView];

    [NSLayoutConstraint activateConstraints:@[
        [tile.widthAnchor constraintEqualToConstant:NXROMSymbolTileSize],
        [tile.heightAnchor constraintEqualToConstant:NXROMSymbolTileSize],
        [imageView.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [imageView.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor],
    ]];

    return tile;
}

+ (UIImage *)placeholderIconWithTitle:(NSString *)title size:(CGFloat)size
{
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextRef cg = context.CGContext;
        CGRect rect = CGRectMake(0, 0, size, size);

        UIColor *top = [UIColor colorWithRed:0.42 green:0.46 blue:0.62 alpha:1.0];
        UIColor *bottom = [UIColor colorWithRed:0.26 green:0.29 blue:0.44 alpha:1.0];
        CGGradientRef gradient = CGGradientCreateWithColors(NULL, (__bridge CFArrayRef)@[ (id)top.CGColor, (id)bottom.CGColor ], NULL);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect
                                                        cornerRadius:size * NXROMIconCornerRatio];
        [path addClip];
        CGContextDrawLinearGradient(cg, gradient, CGPointMake(0, 0), CGPointMake(0, size), 0);
        CGGradientRelease(gradient);

        NSString *letter = title.length > 0 ? [[title substringToIndex:1] uppercaseString] : @"?";
        NSDictionary *attributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:size * 0.46 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName: UIColor.whiteColor,
        };
        CGSize textSize = [letter sizeWithAttributes:attributes];
        [letter drawAtPoint:CGPointMake((size - textSize.width) / 2.0, (size - textSize.height) / 2.0)
             withAttributes:attributes];
    }];
}

+ (UIImageView *)iconViewWithImage:(nullable UIImage *)image
                             title:(NSString *)title
                              size:(CGFloat)size
{
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.layer.cornerRadius = size * NXROMIconCornerRatio;
    imageView.layer.cornerCurve = kCACornerCurveContinuous;

    if (image != nil)
    {
        imageView.image = image;
    }
    else
    {
        imageView.image = [self placeholderIconWithTitle:title size:size];
    }
    return imageView;
}

+ (UICollectionViewFlowLayout *)homeGridLayoutForWidth:(CGFloat)width
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(NXROMIconSize + 18.0, NXROMIconSize + 30.0);
    layout.minimumInteritemSpacing = 8.0;
    layout.minimumLineSpacing = 22.0;

    /* 4 列居中：左右留白由 sectionInset 均摊 */
    CGFloat itemWidth = layout.itemSize.width;
    CGFloat available = width - 2.0 * 12.0;
    CGFloat gap = MAX(12.0, (available - itemWidth * 4.0) / 4.0);
    layout.minimumInteritemSpacing = gap;
    layout.sectionInset = UIEdgeInsetsMake(16.0, 12.0, 24.0, 12.0);
    return layout;
}

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
