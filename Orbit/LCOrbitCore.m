#import "LCOrbitCore.h"
#import "LCOrbitHost.h"
#import "LCOrbitOverlayManager.h"
#import "LCOrbitEventBus.h"
#import "LCOrbitStorage.h"
#import <objc/message.h>

@implementation LCOrbitContext
- (instancetype)init {
    if((self=[super init])) {
        _overlays=[LCOrbitOverlayManager new];
        _events=[LCOrbitEventBus new];
    }
    return self;
}
@end

@implementation LCOrbitCore {
    NSMutableDictionary<NSString *,id<LCOrbitModule>> *_modules;
    NSMutableArray<id> *_observers;
    NSMutableArray<NSString *> *_moduleOrder;
    NSMutableSet<NSString *> *_runningModules;
    BOOL _started;
}
+ (instancetype)sharedCore {
    static LCOrbitCore *instance;
    static dispatch_once_t once;
    dispatch_once(&once,^{ instance=[LCOrbitCore new]; });
    return instance;
}
- (instancetype)init {
    if((self=[super init])) {
        _context=[LCOrbitContext new];
        _modules=[NSMutableDictionary dictionary];
        _moduleOrder=[NSMutableArray array];
        _runningModules=[NSMutableSet set];
        _observers=[NSMutableArray array];
    }
    return self;
}
- (BOOL)registerModule:(id<LCOrbitModule>)module {
    NSAssert(NSThread.isMainThread,@"Module registration must run on main thread");
    NSString *identifier=module.moduleIdentifier;
    if(!identifier.length || _modules[identifier]) return NO;
    _modules[identifier]=module;
    [_moduleOrder addObject:identifier];
    if(_started) [self synchronizeModuleStates];
    return YES;
}
- (NSArray<NSString *> *)registeredModuleIdentifiers { return [_moduleOrder copy]; }
- (BOOL)isModuleEnabled:(NSString *)identifier {
    id value=[LCOrbitStorage objectForKey:@"enabled" module:[@"LCOrbit.module" stringByAppendingFormat:@".%@",identifier]];
    return value?[value boolValue]:YES;
}
- (void)setModule:(NSString *)identifier enabled:(BOOL)enabled {
    NSAssert(NSThread.isMainThread,@"Module changes must run on main thread");
    id<LCOrbitModule> module=_modules[identifier];
    if(!module) return;
    [LCOrbitStorage setObject:@(enabled) forKey:@"enabled"
                         module:[@"LCOrbit.module" stringByAppendingFormat:@".%@",identifier]];
    if(!_started) return;
    [self synchronizeModuleStates];
}
- (void)synchronizeModuleStates {
    for(NSString *identifier in [_moduleOrder copy]) {
        BOOL enabled=[self isModuleEnabled:identifier];
        if(enabled==[_runningModules containsObject:identifier]) continue;
        id<LCOrbitModule> module=_modules[identifier];
        // Record the transition before callbacks, which can post UI lifecycle events.
        if(enabled) {
            [_runningModules addObject:identifier];
            [module orbitDidStartWithContext:self.context];
        } else {
            [_runningModules removeObject:identifier];
            if([module respondsToSelector:@selector(orbitWillStop)]) [module orbitWillStop];
        }
        [self.context.events publish:@"orbit.module.enabledChanged"
            payload:@{@"module":identifier,@"enabled":@(enabled)}];
    }
}
- (void)notifyModules:(NSString *)event scene:(UIWindowScene *)scene {
    [self synchronizeModuleStates];
    for(NSString *identifier in [_moduleOrder copy]) {
        if(![_runningModules containsObject:identifier]) continue;
        id<LCOrbitModule> module=_modules[identifier];
        if([module respondsToSelector:@selector(orbitDidReceiveLifecycleEvent:scene:)])
            [module orbitDidReceiveLifecycleEvent:event scene:scene];
        else if([module respondsToSelector:@selector(orbitDidReceiveLifecycleEvent:)])
            [module orbitDidReceiveLifecycleEvent:event];
    }
    if([LCOrbitHost guestInfo])
        [self.context.events publish:@"orbit.guest.lifecycle"
                            payload:@{@"event":event,@"guestID":[LCOrbitHost guestIdentifier]}];
}
- (void)start {
    NSAssert(NSThread.isMainThread,@"Orbit must start on main thread");
    if(_started) return;
    _started=YES;
    [self synchronizeModuleStates];
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    for(NSString *name in @[UIApplicationDidBecomeActiveNotification,
                           UIApplicationWillEnterForegroundNotification,
                           UIApplicationWillResignActiveNotification,
                           UIApplicationDidEnterBackgroundNotification,
                           UIApplicationDidReceiveMemoryWarningNotification,
                           UISceneDidActivateNotification,
                           UISceneWillDeactivateNotification,
                           UISceneDidDisconnectNotification,
                           UISceneWillEnterForegroundNotification,
                           UIWindowDidBecomeVisibleNotification,
                           @"UIApplicationDidChangeStatusBarOrientationNotification"]) {
        __weak typeof(self) weakSelf=self;
        id token=[center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                                usingBlock:^(NSNotification *note) {
            LCOrbitCore *core=weakSelf;
            if(!core) return;
            // Our own overlay becoming visible must not recursively bootstrap modules.
            if([name isEqualToString:UIWindowDidBecomeVisibleNotification] &&
               note.object==core.context.overlays.window) return;
            UIWindowScene *scene=[note.object isKindOfClass:UIWindowScene.class] ?
                (UIWindowScene *)note.object :
                ([note.object isKindOfClass:UIWindow.class] ? ((UIWindow *)note.object).windowScene : nil);
            [core notifyModules:name scene:scene];
        }];
        if(token) [_observers addObject:token];
    }
    [self notifyModules:@"orbit.bootstrap" scene:nil];
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.7*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{ [weakSelf notifyModules:@"orbit.retry" scene:nil]; });
}
@end

extern void LCFloatingMenuRegisterWithOrbit(LCOrbitCore *core);

// Strata: Orbit / 悬浮菜单已随 TweakLoader 注入每一个访客。
// 开关保存在 App Group defaults（设置页的 @AppStorage），宿主启动访客时还会
// 额外 setenv("LC_ORBIT_ENABLED","1")。两者任一为开即启用，避免跨进程
// (LiveProcess.appex) 或 dyld 初始化顺序导致环境变量读不到。
// 判定放在主队列里做，此时 guestAppInfo / defaults 都已就绪。
static NSUserDefaults *LCOrbitSharedDefaults(void) {
    SEL shared=NSSelectorFromString(@"lcSharedDefaults");
    if([NSUserDefaults respondsToSelector:shared]) {
        id d=((id(*)(id,SEL))objc_msgSend)(NSUserDefaults.class,shared);
        if([d isKindOfClass:NSUserDefaults.class]) return d;
    }
    Class utils=NSClassFromString(@"LCSharedUtils");
    SEL gid=NSSelectorFromString(@"appGroupID");
    if(utils && [utils respondsToSelector:gid]) {
        id group=((id(*)(id,SEL))objc_msgSend)(utils,gid);
        if([group isKindOfClass:NSString.class] && [group length])
            return [[NSUserDefaults alloc] initWithSuiteName:group];
    }
    return nil;
}
static BOOL LCOrbitLaunchEnabled(void) {
    const char *flag=getenv("LC_ORBIT_ENABLED");
    if(flag && flag[0]=='1') return YES;
    return [LCOrbitSharedDefaults() boolForKey:@"StrataFloatingMenuEnabled"];
}

// 只在访客上下文启动；宿主主界面（LCLoadTweaksToSelf）与内置 SideStore 不显示悬浮球。
static BOOL LCOrbitGuestContextReady(void) {
    if(![LCOrbitHost guestInfo]) return NO;
    SEL side=NSSelectorFromString(@"isSideStore");
    if([NSUserDefaults respondsToSelector:side] &&
       ((BOOL(*)(id,SEL))objc_msgSend)(NSUserDefaults.class,side)) return NO;
    return YES;
}

static BOOL LCOrbitBootstrapped=NO;
static void LCOrbitBootstrapIfNeeded(void) {
    if(LCOrbitBootstrapped) return;
    if(!LCOrbitLaunchEnabled()) return;
    if(!LCOrbitGuestContextReady()) return;
    LCOrbitBootstrapped=YES;
    NSLog(@"[Strata][Orbit] bootstrap enabled, guest=%@",[LCOrbitHost guestIdentifier]);
    LCOrbitCore *core=[LCOrbitCore sharedCore];
    LCFloatingMenuRegisterWithOrbit(core);
    [core start];
}

__attribute__((constructor)) static void LCOrbitEntry(void) {
    // Strata: 绝不能按 isLiveProcess 跳过 —— Strata 2.0 的多任务访客就运行在
    // LiveProcess.appex 里，原插件的这条拦截会让悬浮菜单完全不出现。
    dispatch_async(dispatch_get_main_queue(), ^{ LCOrbitBootstrapIfNeeded(); });
    // 兜底：部分访客的 scene / defaults 就绪较晚，1 秒后再检查一次。
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{ LCOrbitBootstrapIfNeeded(); });
}
