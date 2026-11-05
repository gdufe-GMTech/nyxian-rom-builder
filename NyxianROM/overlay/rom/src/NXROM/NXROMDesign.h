/*
 * NXROMDesign.h — 设计层
 *
 * 只做三件事：
 *   1. 壁纸（颜色层）
 *   2. 官方液态玻璃封装：UIGlassEffect / UIGlassContainerEffect（iOS 26+），
 *      老系统自动退回 UIBlurEffect
 *   3. 常用字号 / SF Symbol / 触感
 *
 * 刻意不提供任何自绘图像的接口：图标一律用 SF Symbol，形状用系统圆角与
 * systemFill / systemBackground 颜色。
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern CGFloat const NXROMIconSize;      /* 主屏图标边长 */
extern CGFloat const NXROMIconCorner;    /* 对应圆角 */
extern CGFloat const NXROMDockHeight;

@interface NXROMDesign : NSObject

/* 壁纸：深色渐变（Apple 的壁纸是照片，这里用色层替代） */
+ (void)applyWallpaperToView:(UIView *)view;

/*
 * 液态玻璃。
 *  style: 0 = regular（面板），1 = clear（按钮/胶囊）
 */
+ (UIVisualEffectView *)glassViewWithCornerRadius:(CGFloat)radius
                                            style:(NSInteger)style
                                      interactive:(BOOL)interactive;

/*
 * 玻璃容器：把多个玻璃元素合并成一组（iOS 26 的 UIGlassContainerEffect）。
 * 用法：把若干个 glassView 加进它的 contentView，相邻元素会互相“融合”。
 */
+ (UIVisualEffectView *)glassContainerWithSpacing:(CGFloat)spacing;

/* SF Symbol → UIImage，统一配置点号与字重 */
+ (nullable UIImage *)symbolNamed:(NSString *)name pointSize:(CGFloat)pointSize weight:(UIFontWeight)weight;

/* 系统圆体（iOS 的时间/数字用它更有原生感） */
+ (UIFont *)roundedFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;

/* 内置 App 的主题色（systemBlue / systemOrange …） */
+ (UIColor *)tintForBuiltinIdentifier:(NSString *)identifier;

+ (void)lightImpact;
+ (void)mediumImpact;

@end

NS_ASSUME_NONNULL_END
