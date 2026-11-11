//
//  LCCornerFanMenu.h
//  Strata / Orbit
//
//  魅族风格的角落扇形菜单：从屏幕右下角（可选左下角）斜向内上滑，扇形展开固定应用，
//  过程中可连续滑动选择，松手即启动选中的应用。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LCCornerFanMenu : NSObject
+ (instancetype)shared;
/// 是否启用（读取 LCCornerFanEnabled，缺省关闭；仅在 LC 宿主界面生效）。
+ (BOOL)isEnabled;
/// 是否保留原来的悬浮球（默认保留，扇形只是多一个入口）。
+ (BOOL)keepsOrb;
+ (BOOL)leftCornerEnabled;
+ (BOOL)rightCornerEnabled;
/// 安装/刷新覆盖层，可重复调用。
+ (void)installIfNeeded;
/// 设置变化后调用，立即按新配置重建。
+ (void)reload;
/// 后台清单/图标就绪后，给正在显示的扇形补图（主线程调用）。
- (void)refreshVisibleIcons;
@end

NS_ASSUME_NONNULL_END
