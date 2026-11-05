/*
 * NXROMDesign.h — 界面常量与通用构件
 *
 * 目的：把"像不像 iOS"收敛到一处（圆角比例、网格间距、材质、字号），
 * 其余模块只引用这里的宏与工厂方法，避免各页面各写一套。
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/* 图标圆角：Apple 的 squircle 比例约 0.2237，配合 continuous 曲线 */
extern CGFloat const NXROMIconCornerRatio;
extern CGFloat const NXROMIconSize;          /* 主屏图标边长 */
extern CGFloat const NXROMGridColumnSpacing;
extern CGFloat const NXROMGridRowSpacing;
extern CGFloat const NXROMGridHorizontalInset;
extern CGFloat const NXROMDockHeight;
extern CGFloat const NXROMDockCornerRadius;
extern CGFloat const NXROMPageDotSize;
extern CGFloat const NXROMPageDotSpacing;

/* 系统 App 图标砖块（设置里那种 29pt 圆角方块） */
extern CGFloat const NXROMSymbolTileSize;
extern CGFloat const NXROMSymbolTileCornerRadius;

@interface NXROMDesign : NSObject

/* 主屏壁纸（渐变，不使用 Apple 素材） */
+ (CAGradientLayer *)wallpaperLayerForBounds:(CGRect)bounds;
+ (void)applyWallpaperToView:(UIView *)view;

/* 毛玻璃容器 */
+ (UIVisualEffectView *)blurViewWithStyle:(UIBlurEffectStyle)style cornerRadius:(CGFloat)radius;

/*
 * 液态玻璃（iOS 26 起 UIKit 提供 UIGlassEffect）。
 * style: 0 = regular（标准），1 = clear（更透明，适合叠在图标/按钮上）
 * 老系统自动退回 UIBlurEffect，不会崩。
 */
+ (UIVisualEffect *)glassEffectWithStyle:(NSInteger)style interactive:(BOOL)interactive;
+ (UIVisualEffectView *)glassViewWithCornerRadius:(CGFloat)radius
                                            style:(NSInteger)style
                                      interactive:(BOOL)interactive;

/* 用 SF Symbol 画一个系统 App 图标砖块 */
+ (UIView *)symbolTileWithName:(NSString *)symbolName tint:(UIColor *)tint;

/* 图标占位（无图标时用名称首字） */
+ (UIImage *)placeholderIconWithTitle:(NSString *)title size:(CGFloat)size;

/* 圆角图标 */
+ (UIImageView *)iconViewWithImage:(nullable UIImage *)image
                             title:(NSString *)title
                              size:(CGFloat)size;

/* 主屏网格布局参数（按屏宽自适应列间距） */
+ (UICollectionViewFlowLayout *)homeGridLayoutForWidth:(CGFloat)width;

/* 触感 */
+ (void)lightImpact;
+ (void)mediumImpact;

@end

NS_ASSUME_NONNULL_END
