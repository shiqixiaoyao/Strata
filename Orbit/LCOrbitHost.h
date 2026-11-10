#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface LCOrbitHost : NSObject
/// 宿主（LC 主 App）自己的 defaults。
+ (NSUserDefaults *)hostDefaults;
/// LC 的 App Group defaults，宿主与访客共用；设置页的开关就写在这里。
+ (nullable NSUserDefaults *)sharedDefaults;
+ (nullable NSString *)appGroupPath;
+ (nullable NSDictionary *)guestInfo;
+ (NSString *)guestIdentifier;
+ (nullable UIWindowScene *)activeScene;
/// LC 主包。访客进程里 mainBundle 已被改写成访客自己的包，两者 bundlePath 不同。
+ (nullable NSBundle *)hostMainBundle;
/// 内置 SideStore 访客：悬浮菜单在它里面没有意义。
+ (BOOL)isBuiltinSideStore;
+ (BOOL)isHostUI;
/// 当前进程是否是普通访客。LC 自身界面与内置 SideStore 都返回 NO。
+ (BOOL)isGuestContext;
@end
NS_ASSUME_NONNULL_END
