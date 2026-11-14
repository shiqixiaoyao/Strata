#import "LCOrbitCore.h"
#import "LCOrbitHost.h"
#import "LCOrbitOverlayManager.h"
#import "LCOrbitEventBus.h"
#import "LCOrbitStorage.h"

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

// Strata: Orbit / 悬浮菜单随 TweakLoader 注入每一个访客。
//
// 原插件的启动条件在 Strata 2.0 上一条都不成立：
//   1) 它要求 [LCOrbitHost guestInfo] 非空 —— 但 guestAppInfo 是 LCBootstrap.m
//      里的宿主静态变量，访客扩展进程 / 多任务复用进程的启动早期经常还是 nil；
//   2) 它要求 !isLiveProcess —— Strata 的多任务访客本身就运行在
//      LiveProcess.appex 里，这条会把访客全部排除。
// v7 因为这两条导致开关打开也没有任何反应，这里改为「只要确实是访客进程就启动」，
// 只排除 LC 自身界面与内置 SideStore，并把每次判定结果写进 App Group，方便在
// 设置页看到「为什么没起来」。

static NSString *const LCOrbitSwitchKey=@"StrataFloatingMenuEnabled";
static NSString *const LCOrbitStatusKey=@"StrataOrbitStatus";

static void LCOrbitReportStatus(NSString *phase, NSString *detail) {
    NSUserDefaults *store=[LCOrbitHost sharedDefaults];
    if(!store) return;
    [store setObject:@{@"phase":phase?:@"",
                       @"detail":detail?:@"",
                       @"date":[NSDate date],
                       @"guest":[LCOrbitHost guestIdentifier]?:@""}
               forKey:LCOrbitStatusKey];
    [store synchronize];
}

// 开关可能落在这几处：宿主 setenv 的环境变量（普通访客进程会继承）、App Group
// defaults（设置页 @AppStorage 写的地方）、宿主自己的 defaults。都读不到时按
// 「开启」处理并回写 App Group —— 用户明确要求这个功能默认可用，而原来的实现
// 一旦开关写串 suite 就永远读不到，表现为「打开开关也没有用」。
static BOOL LCOrbitSwitchValue(NSString **source) {
    const char *flag=getenv("LC_ORBIT_ENABLED");
    if(flag && flag[0]=='1') { if(source) *source=@"env"; return YES; }
    if(flag && flag[0]=='0') { if(source) *source=@"env-off"; return NO; }
    NSUserDefaults *shared=[LCOrbitHost sharedDefaults];
    NSUserDefaults *host=[LCOrbitHost hostDefaults];
    NSUserDefaults *stores[2]={shared,host};
    for(NSUInteger i=0;i<2;i++) {
        id value=[stores[i] objectForKey:LCOrbitSwitchKey];
        if(!value) continue;
        if(source) *source=@"defaults";
        return [value boolValue];
    }
    [shared setBool:YES forKey:LCOrbitSwitchKey];
    [shared synchronize];
    if(source) *source=@"default-on";
    return YES;
}

static BOOL LCOrbitBootstrapped=NO;
static NSInteger LCOrbitAttempts=0;
static id LCOrbitActivationObserver=nil;
static id LCOrbitSceneObserver=nil;

static void LCOrbitStopWaiting(void) {
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    if(LCOrbitActivationObserver) {
        [center removeObserver:LCOrbitActivationObserver];
        LCOrbitActivationObserver=nil;
    }
    if(LCOrbitSceneObserver) {
        [center removeObserver:LCOrbitSceneObserver];
        LCOrbitSceneObserver=nil;
    }
}

static void LCOrbitBootstrapIfNeeded(void) {
    if(LCOrbitBootstrapped) return;
    LCOrbitAttempts++;
    NSString *source=nil;
    if(!LCOrbitSwitchValue(&source)) {
        if(LCOrbitAttempts==1) LCOrbitReportStatus(@"switch-off",source);
        return;
    }
    if(![LCOrbitHost isGuestContext]) {
        if(LCOrbitAttempts==1)
            LCOrbitReportStatus(@"not-guest",[NSString stringWithFormat:@"hostUI=%d bundle=%@",
                [LCOrbitHost isHostUI],NSBundle.mainBundle.bundleIdentifier?:@"?"]);
        return;
    }
    LCOrbitBootstrapped=YES;
    LCOrbitStopWaiting();
    NSLog(@"[Strata][Orbit] bootstrap enabled, guest=%@ source=%@ attempt=%ld",
          [LCOrbitHost guestIdentifier],source,(long)LCOrbitAttempts);
    LCOrbitCore *core=[LCOrbitCore sharedCore];
    LCFloatingMenuRegisterWithOrbit(core);
    [core start];
    LCOrbitReportStatus(@"started",source);
}

__attribute__((constructor)) static void LCOrbitEntry(void) {
    // 构造期跑在 dyld 初始化里，此时还没有 UIApplication/scene，一律推迟到主队列；
    // 访客的 scene、defaults、guestAppInfo 就绪时间差别很大，所以多档重试。
    dispatch_async(dispatch_get_main_queue(), ^{ LCOrbitBootstrapIfNeeded(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.6*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{ LCOrbitBootstrapIfNeeded(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.0*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{ LCOrbitBootstrapIfNeeded(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(5.0*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{ LCOrbitBootstrapIfNeeded(); });
    // 访客进程可能早在开关打开之前就已运行（Strata 2.0 会复用进程）。回到前台
    // 或场景激活时再确认一次；启动成功后观察者立即移除，之后不再有任何开销。
    LCOrbitActivationObserver=[NSNotificationCenter.defaultCenter
        addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
            LCOrbitBootstrapIfNeeded();
        }];
    LCOrbitSceneObserver=[NSNotificationCenter.defaultCenter
        addObserverForName:UISceneDidActivateNotification object:nil
        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
            LCOrbitBootstrapIfNeeded();
        }];
}
