#import "LCOrbitHost.h"
#import <objc/message.h>

@implementation LCOrbitHost
+ (id)callHostSelector:(NSString *)name {
    SEL sel=NSSelectorFromString(name);
    if(![NSUserDefaults respondsToSelector:sel]) return nil;
    return ((id(*)(id,SEL))objc_msgSend)(NSUserDefaults.class,sel);
}
+ (BOOL)isLiveProcess {
    SEL sel=NSSelectorFromString(@"isLiveProcess");
    if(![NSUserDefaults respondsToSelector:sel]) return NO;
    return ((BOOL(*)(id,SEL))objc_msgSend)(NSUserDefaults.class,sel);
}
+ (BOOL)isBuiltinSideStore {
    SEL sel=NSSelectorFromString(@"isSideStore");
    if(![NSUserDefaults respondsToSelector:sel]) return NO;
    return ((BOOL(*)(id,SEL))objc_msgSend)(NSUserDefaults.class,sel);
}
+ (NSUserDefaults *)hostDefaults {
    id defaults=[self callHostSelector:@"lcUserDefaults"];
    return [defaults isKindOfClass:NSUserDefaults.class]?defaults:NSUserDefaults.standardUserDefaults;
}
+ (NSUserDefaults *)sharedDefaults {
    id shared=[self callHostSelector:@"lcSharedDefaults"];
    if([shared isKindOfClass:NSUserDefaults.class]) return shared;
    Class utils=NSClassFromString(@"LCSharedUtils");
    SEL sel=NSSelectorFromString(@"appGroupID");
    if(utils && [utils respondsToSelector:sel]) {
        id group=((id(*)(id,SEL))objc_msgSend)(utils,sel);
        if([group isKindOfClass:NSString.class] && [group length])
            return [[NSUserDefaults alloc] initWithSuiteName:group];
    }
    return nil;
}
+ (NSString *)appGroupPath { return [self callHostSelector:@"lcAppGroupPath"]; }
+ (NSDictionary *)guestInfo { return [self callHostSelector:@"guestAppInfo"]; }
+ (NSString *)guestIdentifier {
    return [self callHostSelector:@"lcGuestAppId"] ?: NSBundle.mainBundle.bundleIdentifier ?: @"unknown";
}
+ (NSBundle *)hostMainBundle {
    id bundle=[self callHostSelector:@"lcMainBundle"];
    return [bundle isKindOfClass:NSBundle.class]?bundle:nil;
}
+ (UIWindowScene *)activeScene {
    if(@available(iOS 13.0,*)) {
        for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)
            if([scene isKindOfClass:UIWindowScene.class] &&
               scene.activationState==UISceneActivationStateForegroundActive)
                return (UIWindowScene *)scene;
    }
    return nil;
}
+ (BOOL)isHostUI {
    // Only opt-in LC's own UI is allowed. A Guest has guestAppInfo even
    // when its bundle lives in the shared App Group.
    if([self guestInfo] || ![[self hostDefaults] boolForKey:@"LCLoadTweaksToSelf"]) return NO;
    NSBundle *hostBundle=[self hostMainBundle];
    if(!hostBundle || ![hostBundle.bundlePath isEqualToString:NSBundle.mainBundle.bundlePath]) return NO;
    return !self.isBuiltinSideStore && !self.isLiveProcess;
}
+ (BOOL)isGuestContext {
    if(self.isBuiltinSideStore) return NO;
    if(self.isHostUI) return NO;
    // Strata 2.0：访客的 guestAppInfo 在部分启动路径（访客扩展、多进程复用）
    // 里读不到，所以这里不能只认 guestAppInfo —— 只要 mainBundle 已经被改写成
    // 别的 App，就说明我们在访客进程里。
    if([self guestInfo]) return YES;
    NSBundle *hostBundle=[self hostMainBundle];
    if(!hostBundle) return NO;
    return ![hostBundle.bundlePath isEqualToString:NSBundle.mainBundle.bundlePath];
}
@end
