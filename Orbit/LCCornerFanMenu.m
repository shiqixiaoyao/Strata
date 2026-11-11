//
//  LCCornerFanMenu.m
//  Strata / Orbit
//
//  交互来自魅族 Flyme 的角落扇形菜单（参考 Mangi-11/FlymeFreeform 的
//  CornerTriggerRegion / RadialGeometry / RadialEntryMotion 思路）：
//    1. 只有从底部角落区域按下的手势才被接管，其余触摸原样穿透；
//    2. 斜向内上滑超过阈值即展开扇形，图标沿四分之一圆弧排布；
//    3. 手指在图标之间连续滑动即可改选，松手启动当前选中项；
//    4. 中途反向收回或松手在空白处则关闭，不启动任何应用。
//

#import "LCCornerFanMenu.h"
#import "LCOrbitGuestService.h"
#import "LCOrbitHost.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <math.h>

static NSString *const LCFanEnabledKey = @"LCCornerFanEnabled";
static NSString *const LCFanKeepOrbKey = @"LCCornerFanKeepOrb";
static NSString *const LCFanLeftKey = @"LCCornerFanLeft";
static NSString *const LCFanRightKey = @"LCCornerFanRight";
static NSString *const LCFanTriggerKey = @"LCCornerFanTrigger";
static NSString *const LCFanAppsKey = @"LCCornerFanApps";

static const NSInteger LCFanMaxItems = 8;
static const CGFloat LCFanIconSize = 58.0;
static const CGFloat LCFanMaxRadius = 152.0;

#pragma mark - 偏好

static NSUserDefaults *LCFanDefaults(void) {
    SEL selector = NSSelectorFromString(@"lcSharedDefaults");
    if ([NSUserDefaults respondsToSelector:selector]) {
        return ((id (*)(id, SEL))objc_msgSend)([NSUserDefaults class], selector);
    }
    return [NSUserDefaults standardUserDefaults];
}

static id LCFanObject(NSString *key) {
    id value = [LCFanDefaults() objectForKey:key];
    return value;
}

static BOOL LCFanFlag(NSString *key, BOOL fallback) {
    id value = LCFanObject(key);
    return value ? [value boolValue] : fallback;
}

// 探针：供调试时快速确认覆盖层是否处于启用状态。
static BOOL LCFanActive(void) {
    return [LCCornerFanMenu isEnabled];
}

static CGFloat LCFanTriggerSize(void) {
    id value = LCFanObject(LCFanTriggerKey);
    CGFloat size = value ? [value doubleValue] : 74.0;
    return MIN(MAX(size, 40.0), 120.0);
}

#pragma mark - 图标

static UIImage *LCFanIconImage(NSDictionary *app) {
    NSString *folder = app[@"folder"];
    if (![folder isKindOfClass:[NSString class]] || folder.length == 0) {
        return nil;
    }
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
        cache.countLimit = 64;
    });
    UIImage *saved = [cache objectForKey:folder];
    if (saved) {
        return saved;
    }
    UIImage *image = [UIImage imageWithContentsOfFile:[folder stringByAppendingPathComponent:@"LCAppIconLight.png"]];
    if (!image) {
        image = [UIImage imageWithContentsOfFile:[folder stringByAppendingPathComponent:@"LCAppIconDark.png"]];
    }
    if (!image) {
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
            [folder stringByAppendingPathComponent:@"Info.plist"]];
        NSDictionary *icons = info[@"CFBundleIcons"];
        if (![icons isKindOfClass:[NSDictionary class]]) {
            icons = info[@"CFBundleIcons~ipad"];
        }
        NSDictionary *primary = [icons isKindOfClass:[NSDictionary class]] ? icons[@"CFBundlePrimaryIcon"] : nil;
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        if ([primary[@"CFBundleIconName"] isKindOfClass:[NSString class]]) {
            [names addObject:primary[@"CFBundleIconName"]];
        }
        for (id name in [primary[@"CFBundleIconFiles"] reverseObjectEnumerator]) {
            if ([name isKindOfClass:[NSString class]]) {
                [names addObject:name];
            }
        }
        NSBundle *bundle = [NSBundle bundleWithPath:folder];
        for (NSString *name in names) {
            @try {
                image = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
            } @catch (NSException *exception) {
                image = nil;
            }
            if (image) {
                break;
            }
        }
    }
    if (image) {
        [cache setObject:image forKey:folder];
    }
    return image;
}

#pragma mark - 应用清单

static NSArray<NSDictionary *> *LCFanCandidateApps(void) {
    NSArray<NSDictionary *> *all = [LCOrbitGuestService installedApps];
    if (![all isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    id pinned = LCFanObject(LCFanAppsKey);
    if ([pinned isKindOfClass:[NSArray class]]) {
        for (id identity in (NSArray *)pinned) {
            if (![identity isKindOfClass:[NSString class]]) {
                continue;
            }
            for (NSDictionary *app in all) {
                if (![app[@"identity"] isEqual:identity]) {
                    continue;
                }
                if ([app[@"launchable"] boolValue] && ![app[@"hidden"] boolValue]) {
                    [result addObject:app];
                }
                break;
            }
            if (result.count >= LCFanMaxItems) {
                break;
            }
        }
    }
    if (result.count == 0) {
        for (NSDictionary *app in all) {
            if (![app[@"launchable"] boolValue] || [app[@"hidden"] boolValue] || [app[@"builtin"] boolValue]) {
                continue;
            }
            [result addObject:app];
            if (result.count >= LCFanMaxItems - 1) {
                break;
            }
        }
    }
    if (result.count < LCFanMaxItems) {
        [result addObject:@{@"path": @"ui", @"uuid": @"", @"title": @"LiveContainer"}];
    }
    if (result.count < LCFanMaxItems) {
        [result addObject:@{@"menu": @YES, @"title": @"菜单"}];
    }
    return result;
}

#pragma mark - 图标视图

@interface LCCornerFanIcon : UIView
@property(nonatomic, strong) NSDictionary *app;
@property(nonatomic, strong) UIImageView *iconView;
@property(nonatomic, strong) UILabel *nameLabel;
@property(nonatomic, assign) BOOL highlighted;
@property(nonatomic, assign) CGPoint home;
@end

@implementation LCCornerFanIcon

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.bounds = CGRectMake(0, 0, LCFanIconSize, LCFanIconSize + 18);
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, LCFanIconSize, LCFanIconSize)];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.layer.cornerRadius = LCFanIconSize * 0.235;
        _iconView.layer.cornerCurve = kCACornerCurveContinuous;
        _iconView.clipsToBounds = YES;
        _iconView.layer.borderWidth = 0;
        _iconView.layer.borderColor = UIColor.whiteColor.CGColor;
        [self addSubview:_iconView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(-24, LCFanIconSize + 3,
                                                              LCFanIconSize + 48, 14)];
        _nameLabel.textAlignment = NSTextAlignmentCenter;
        _nameLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _nameLabel.textColor = [UIColor colorWithWhite:1 alpha:0.92];
        _nameLabel.alpha = 0;
        _nameLabel.layer.shadowColor = UIColor.blackColor.CGColor;
        _nameLabel.layer.shadowOpacity = 0.45;
        _nameLabel.layer.shadowRadius = 2;
        _nameLabel.layer.shadowOffset = CGSizeMake(0, 1);
        [self addSubview:_nameLabel];
    }
    return self;
}

- (void)setApp:(NSDictionary *)app {
    _app = app;
    UIImage *image = LCFanIconImage(app);
    if (!image) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:LCFanIconSize * 0.46
                                                            weight:UIImageSymbolWeightSemibold];
        image = [UIImage systemImageNamed:@"square.grid.2x2.fill" withConfiguration:configuration];
        self.iconView.tintColor = [UIColor colorWithWhite:1 alpha:0.85];
        self.iconView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
        self.iconView.contentMode = UIViewContentModeCenter;
    }
    self.iconView.image = image;
    id rawTitle = app[@"title"];
    NSString *title = [rawTitle isKindOfClass:[NSString class]] ? (NSString *)rawTitle : app[@"path"];
    self.nameLabel.text = title;
    self.accessibilityLabel = title;
}

- (void)setHighlighted:(BOOL)highlighted {
    if (_highlighted == highlighted) {
        return;
    }
    _highlighted = highlighted;
    CGFloat scale = highlighted ? 1.16 : 1.0;
    [UIView animateWithDuration:0.18 delay:0 usingSpringWithDamping:0.62 initialSpringVelocity:0.9
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform = CGAffineTransformMakeScale(scale, scale);
        self.nameLabel.alpha = highlighted ? 1 : 0;
        self.iconView.layer.borderWidth = highlighted ? 2.0 : 0.0;
    } completion:nil];
}

@end

#pragma mark - 扇形面板

@interface LCCornerFanPanel : UIView
@property(nonatomic, assign) NSInteger corner;   // 0 = 左下, 1 = 右下
@property(nonatomic, strong) NSArray<LCCornerFanIcon *> *icons;
@property(nonatomic, assign) NSInteger selection;
@property(nonatomic, strong) UIVisualEffectView *backdrop;
@property(nonatomic, strong) UIView *hintView;
@property(nonatomic, strong) UILabel *hintLabel;
@property(nonatomic, strong) CAShapeLayer *ringLayer;
@property(nonatomic, strong) UISelectionFeedbackGenerator *feedback;
- (instancetype)initWithFrame:(CGRect)frame corner:(NSInteger)corner apps:(NSArray<NSDictionary *> *)apps;
- (void)reveal;
- (void)dismiss:(void (^)(void))completion;
- (void)updateSelectionWithPoint:(CGPoint)point inView:(UIView *)view;
- (NSDictionary *)selectedApp;
@end

@implementation LCCornerFanPanel

- (instancetype)initWithFrame:(CGRect)frame corner:(NSInteger)corner apps:(NSArray<NSDictionary *> *)apps {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    self.backgroundColor = UIColor.clearColor;
    self.corner = corner;
    self.selection = -1;
    self.feedback = [UISelectionFeedbackGenerator new];

    _backdrop = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    _backdrop.frame = self.bounds;
    _backdrop.userInteractionEnabled = NO;
    _backdrop.alpha = 0;
    [self addSubview:_backdrop];

    NSMutableArray<LCCornerFanIcon *> *icons = [NSMutableArray array];
    for (NSDictionary *app in apps) {
        LCCornerFanIcon *icon = [[LCCornerFanIcon alloc] initWithFrame:CGRectZero];
        icon.app = app;
        icon.alpha = 0;
        icon.userInteractionEnabled = NO;
        [self addSubview:icon];
        [icons addObject:icon];
    }
    _icons = icons;

    _hintView = [[UIView alloc] initWithFrame:CGRectZero];
    _hintView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    _hintView.layer.cornerRadius = 13;
    _hintView.layer.cornerCurve = kCACornerCurveContinuous;
    _hintView.alpha = 0;
    _hintView.userInteractionEnabled = NO;
    [self addSubview:_hintView];

    _hintLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _hintLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    _hintLabel.textColor = UIColor.whiteColor;
    _hintLabel.textAlignment = NSTextAlignmentCenter;
    [_hintView addSubview:_hintLabel];
    return self;
}

- (CGPoint)cornerPoint {
    CGFloat inset = 2.0;
    if (self.corner == 1) {
        return CGPointMake(CGRectGetMaxX(self.bounds) - inset, CGRectGetMaxY(self.bounds) - inset);
    }
    return CGPointMake(CGRectGetMinX(self.bounds) + inset, CGRectGetMaxY(self.bounds) - inset);
}

- (CGFloat)startAngle {
    return self.corner == 1 ? M_PI : -M_PI_2;
}

- (CGFloat)endAngle {
    return self.corner == 1 ? M_PI * 1.5 : 0;
}

- (CGFloat)radius {
    CGSize size = self.bounds.size;
    CGFloat limit = MIN(size.width, size.height);
    return MIN(LCFanMaxRadius, limit * 0.36);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.backdrop.frame = self.bounds;
    [self applyBackdropMask];

    CGPoint center = [self cornerPoint];
    CGFloat radius = [self radius];
    NSUInteger count = self.icons.count;
    if (count == 0) {
        return;
    }
    CGFloat start = [self startAngle];
    CGFloat end = [self endAngle];
    for (NSUInteger index = 0; index < count; index++) {
        CGFloat progress = count == 1 ? 0.5 : (CGFloat)index / (CGFloat)(count - 1);
        CGFloat angle = start + (end - start) * progress;
        CGPoint point = CGPointMake(center.x + radius * cos(angle), center.y + radius * sin(angle));
        LCCornerFanIcon *icon = self.icons[index];
        icon.home = point;
        icon.bounds = CGRectMake(0, 0, LCFanIconSize, LCFanIconSize + 18);
        icon.center = point;
        icon.iconView.frame = CGRectMake(0, 0, LCFanIconSize, LCFanIconSize);
        icon.nameLabel.frame = CGRectMake(-24, LCFanIconSize + 3, LCFanIconSize + 48, 14);
    }

    CGSize hintSize = CGSizeMake(120, 26);
    CGFloat hintRadius = radius * 0.52;
    CGFloat middle = (start + end) / 2.0;
    CGPoint hintCenter = CGPointMake(center.x + hintRadius * cos(middle), center.y + hintRadius * sin(middle));
    self.hintView.bounds = CGRectMake(0, 0, hintSize.width, hintSize.height);
    self.hintView.center = hintCenter;
    self.hintLabel.frame = self.hintView.bounds;
}

- (void)applyBackdropMask {
    CGPoint center = [self cornerPoint];
    CGFloat radius = [self radius] + LCFanIconSize * 0.85;
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:center];
    [path addArcWithCenter:center radius:radius startAngle:[self startAngle] endAngle:[self endAngle] clockwise:YES];
    [path closePath];

    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = path.CGPath;
    mask.fillColor = UIColor.blackColor.CGColor;
    self.backdrop.layer.mask = mask;

    UIBezierPath *stroke = [UIBezierPath bezierPath];
    [stroke addArcWithCenter:center radius:radius startAngle:[self startAngle] endAngle:[self endAngle] clockwise:YES];
    if (!self.ringLayer) {
        self.ringLayer = [CAShapeLayer layer];
        self.ringLayer.fillColor = UIColor.clearColor.CGColor;
        self.ringLayer.strokeColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
        self.ringLayer.lineWidth = 0.7;
        [self.backdrop.layer addSublayer:self.ringLayer];
    }
    self.ringLayer.path = stroke.CGPath;
}

- (void)reveal {
    if (self.icons.count == 0) {
        return;
    }
    [self.feedback prepare];
    [UIView animateWithDuration:0.2 animations:^{
        self.backdrop.alpha = 1;
    }];
    CGPoint center = [self cornerPoint];
    [self.icons enumerateObjectsUsingBlock:^(LCCornerFanIcon *icon, NSUInteger index, BOOL *stop) {
        icon.center = center;
        icon.transform = CGAffineTransformMakeScale(0.3, 0.3);
        [UIView animateWithDuration:0.46 delay:0.02 * index
             usingSpringWithDamping:0.68 initialSpringVelocity:0.9
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            icon.alpha = 1;
            icon.center = icon.home;
            icon.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)dismiss:(void (^)(void))completion {
    [UIView animateWithDuration:0.16 animations:^{
        self.alpha = 0;
        self.backdrop.alpha = 0;
        for (LCCornerFanIcon *icon in self.icons) {
            icon.transform = CGAffineTransformMakeScale(0.75, 0.75);
        }
    } completion:^(BOOL finished) {
        if (completion) {
            completion();
        }
    }];
}

- (void)updateSelectionWithPoint:(CGPoint)point inView:(UIView *)view {
    CGPoint local = [self convertPoint:point fromView:view];
    CGPoint center = [self cornerPoint];
    CGFloat distance = hypot(local.x - center.x, local.y - center.y);
    NSInteger nearest = -1;
    CGFloat best = CGFLOAT_MAX;
    for (NSUInteger index = 0; index < self.icons.count; index++) {
        LCCornerFanIcon *icon = self.icons[index];
        CGFloat delta = hypot(local.x - icon.home.x, local.y - icon.home.y);
        if (delta < best) {
            best = delta;
            nearest = (NSInteger)index;
        }
    }
    CGFloat threshold = LCFanIconSize * 0.92;
    if (distance < LCFanIconSize * 0.45 || best > threshold) {
        nearest = -1;
    }
    [self applySelection:nearest];
}

- (void)applySelection:(NSInteger)selection {
    if (self.selection == selection) {
        return;
    }
    self.selection = selection;
    for (NSUInteger index = 0; index < self.icons.count; index++) {
        self.icons[index].highlighted = ((NSInteger)index == selection);
    }
    if (selection >= 0 && selection < (NSInteger)self.icons.count) {
        [self.feedback selectionChanged];
        NSDictionary *app = self.icons[(NSUInteger)selection].app;
        id rawTitle = app[@"title"];
        self.hintLabel.text = [rawTitle isKindOfClass:[NSString class]]
            ? [(NSString *)rawTitle stringByAppendingString:@" · 松手启动"] : @"松手启动";
        [UIView animateWithDuration:0.15 animations:^{
            self.hintView.alpha = 1;
        }];
    } else {
        [UIView animateWithDuration:0.12 animations:^{
            self.hintView.alpha = 0;
        }];
    }
}

- (NSDictionary *)selectedApp {
    if (self.selection < 0 || self.selection >= (NSInteger)self.icons.count) {
        return nil;
    }
    return self.icons[(NSUInteger)self.selection].app;
}

@end

#pragma mark - 根视图与窗口

@interface LCCornerFanRootView : UIView
@property(nonatomic, assign) BOOL presenting;
@property(nonatomic, weak) LCCornerFanPanel *panel;
@property(nonatomic, strong) UIPanGestureRecognizer *pan;
@property(nonatomic, assign) NSInteger activeCorner;
@end

@implementation LCCornerFanRootView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // 只有「扇形真的摊在屏幕上」时才接管整块面板区域。v19 这里只判断 presenting，
    // 一旦动画被打断没把 presenting 复位，整块屏幕就被这层挡住，谁都点不动。
    if (self.presenting && self.panel && self.panel.superview == self) {
        return [super hitTest:point withEvent:event];
    }
    if (!event || event.type != UIEventTypeTouches) {
        return nil;
    }
    CGFloat size = LCFanTriggerSize();
    BOOL inRight = [LCCornerFanMenu rightCornerEnabled] &&
        point.x >= CGRectGetMaxX(self.bounds) - size &&
        point.y >= CGRectGetMaxY(self.bounds) - size * 0.85;
    BOOL inLeft = [LCCornerFanMenu leftCornerEnabled] &&
        point.x <= CGRectGetMinX(self.bounds) + size &&
        point.y >= CGRectGetMaxY(self.bounds) - size * 0.85;
    if (inRight || inLeft) {
        return self;
    }
    return nil;
}

@end

@interface LCCornerFanController : UIViewController
@end

@implementation LCCornerFanController
- (BOOL)prefersStatusBarHidden {
    return NO;
}
- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}
@end

@interface LCCornerFanWindow : UIWindow
@end

@implementation LCCornerFanWindow
// 只做触摸拦截，不当 key window，避免打断宿主或访客的输入法焦点。
- (BOOL)canBecomeKeyWindow {
    return NO;
}
@end

#pragma mark - 全局管理器

@interface LCCornerFanMenu () <UIGestureRecognizerDelegate>
@property(nonatomic, strong) LCCornerFanWindow *window;
@property(nonatomic, strong) LCCornerFanRootView *rootView;
@property(nonatomic, strong) LCCornerFanPanel *panel;
@property(nonatomic, weak) UIWindowScene *scene;
@end

@implementation LCCornerFanMenu

+ (instancetype)shared {
    static LCCornerFanMenu *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [LCCornerFanMenu new];
    });
    return instance;
}

+ (BOOL)isEnabled {
    // 内置 SideStore 会把 mainBundle 整个换成 SideStoreApp.framework，此时
    // isHostUI 会变 NO。覆盖层一旦建立就按偏好决定去留，避免在访客运行期间被拆掉。
    if ([LCCornerFanMenu shared].window) {
        return LCFanFlag(LCFanEnabledKey, YES);
    }
    if (![LCOrbitHost isHostUI]) {
        return NO;
    }
    return LCFanFlag(LCFanEnabledKey, YES);
}

+ (BOOL)keepsOrb {
    // v20 起默认保留悬浮球：扇形菜单是「多一个入口」，不是「换掉唯一入口」。
    // 万一角落手势在某个机型上失灵，至少还有原来的球可以点。
    return LCFanFlag(LCFanKeepOrbKey, YES);
}

+ (BOOL)leftCornerEnabled {
    return LCFanFlag(LCFanLeftKey, NO);
}

+ (BOOL)rightCornerEnabled {
    return LCFanFlag(LCFanRightKey, YES);
}

+ (void)installIfNeeded {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self installIfNeeded];
        });
        return;
    }
    LCCornerFanMenu *menu = [self shared];
    if (![self isEnabled]) {
        [menu tearDown];
        return;
    }
    UIWindowScene *scene = [menu foregroundScene];
    if (!scene) {
        return;
    }
    if (menu.window && menu.scene == scene) {
        menu.window.frame = scene.coordinateSpace.bounds;
        menu.rootView.frame = menu.window.bounds;
        // 复用窗口时顺手清掉可能残留的拦截状态，避免覆盖层一直吃掉全屏触摸。
        if (!menu.panel || menu.panel.superview != menu.rootView) {
            menu.rootView.presenting = NO;
            menu.rootView.panel = nil;
        }
        return;
    }
    [menu buildWindowForScene:scene];
}

+ (void)reload {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reload];
        });
        return;
    }
    LCCornerFanMenu *menu = [self shared];
    [menu tearDown];
    [self installIfNeeded];
}

- (UIWindowScene *)foregroundScene {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState == UISceneActivationStateForegroundActive ||
            windowScene.activationState == UISceneActivationStateForegroundInactive) {
            return windowScene;
        }
    }
    return nil;
}

- (void)buildWindowForScene:(UIWindowScene *)scene {
    [self tearDown];
    self.scene = scene;
    self.window = [[LCCornerFanWindow alloc] initWithWindowScene:scene];
    self.window.windowLevel = UIWindowLevelStatusBar + 60;
    self.window.backgroundColor = UIColor.clearColor;
    self.window.rootViewController = [LCCornerFanController new];
    self.window.frame = scene.coordinateSpace.bounds;

    self.rootView = [[LCCornerFanRootView alloc] initWithFrame:self.window.bounds];
    self.rootView.backgroundColor = UIColor.clearColor;
    self.rootView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.window.rootViewController.view addSubview:self.rootView];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.delegate = self;
    pan.maximumNumberOfTouches = 1;
    pan.cancelsTouchesInView = NO;
    [self.rootView addGestureRecognizer:pan];
    self.rootView.pan = pan;

    self.window.hidden = NO;
}

- (void)tearDown {
    [self.panel removeFromSuperview];
    self.panel = nil;
    self.rootView.panel = nil;
    self.rootView.presenting = NO;
    self.window.hidden = YES;
    self.window = nil;
    self.rootView = nil;
    self.scene = nil;
}

- (NSInteger)cornerForPoint:(CGPoint)point {
    if ([LCCornerFanMenu rightCornerEnabled] && point.x > CGRectGetMidX(self.rootView.bounds)) {
        return 1;
    }
    if ([LCCornerFanMenu leftCornerEnabled] && point.x < CGRectGetMidX(self.rootView.bounds)) {
        return 0;
    }
    return [LCCornerFanMenu rightCornerEnabled] ? 1 : 0;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint point = [pan locationInView:self.rootView];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            NSInteger corner = [self cornerForPoint:point];
            self.rootView.activeCorner = corner;
            [self presentFanAtCorner:corner];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            [self.panel updateSelectionWithPoint:point inView:self.rootView];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            NSDictionary *target = [self.panel selectedApp];
            [self dismissFan:^{
                if (target) {
                    [self launchApp:target];
                }
            }];
            break;
        }
        default:
            break;
    }
}

- (void)presentFanAtCorner:(NSInteger)corner {
    [self.panel removeFromSuperview];
    NSArray<NSDictionary *> *apps = LCFanCandidateApps();
    LCCornerFanPanel *panel = [[LCCornerFanPanel alloc] initWithFrame:self.rootView.bounds
                                                              corner:corner
                                                                apps:apps];
    panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.rootView addSubview:panel];
    self.panel = panel;
    self.rootView.panel = panel;
    self.rootView.presenting = YES;
    [panel layoutIfNeeded];
    [panel reveal];
    // 兜底：展开动画被打断（来电、切后台、面板被摘掉）时，presenting 若一直为 YES，
    // 这一层就会把整屏触摸都吞掉。1.2 秒后自查一次，没东西在屏幕上就复位。
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        LCCornerFanMenu *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.rootView) { return; }
        if (strongSelf.panel && strongSelf.panel.superview == strongSelf.rootView) { return; }
        strongSelf.rootView.presenting = NO;
        strongSelf.rootView.panel = nil;
    });
}

- (void)dismissFan:(void (^)(void))completion {
    if (!self.panel) {
        self.rootView.presenting = NO;
        self.rootView.panel = nil;
        if (completion) {
            completion();
        }
        return;
    }
    LCCornerFanPanel *panel = self.panel;
    self.panel = nil;
    [panel dismiss:^{
        [panel removeFromSuperview];
        self.rootView.presenting = NO;
        self.rootView.panel = nil;
        if (completion) {
            completion();
        }
    }];
    // dismiss: 的 completion 依赖动画收尾，动画被系统打断时不会回调。
    // 这里再补一次复位，保证覆盖层不会永远停在「拦截全屏」的状态。
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        LCCornerFanMenu *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.rootView) { return; }
        [panel removeFromSuperview];
        strongSelf.rootView.presenting = NO;
        strongSelf.rootView.panel = nil;
    });
}

- (void)launchApp:(NSDictionary *)app {
    if ([app[@"menu"] boolValue]) {
        [NSNotificationCenter.defaultCenter postNotificationName:@"LCOrbitMultitaskMenuRequested"
                                                          object:nil
                                                        userInfo:@{@"expanded": @YES}];
        return;
    }
    NSString *path = app[@"path"];
    NSString *uuid = app[@"uuid"];
    if (![path isKindOfClass:[NSString class]] || path.length == 0) {
        return;
    }
    NSError *error = nil;
    BOOL ok = [LCOrbitGuestService launchGuestPath:path uuid:uuid error:&error];
    if (!ok) {
        UIWindow *keyWindow = nil;
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        UIViewController *presenter = keyWindow.rootViewController ?: self.window.rootViewController;
        while (presenter.presentedViewController) {
            presenter = presenter.presentedViewController;
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法启动"
                                                                       message:error.localizedDescription
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - 生命周期

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification
                                                        object:nil
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *note) {
            [LCCornerFanMenu installIfNeeded];
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:UISceneDidActivateNotification
                                                        object:nil
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *note) {
            [LCCornerFanMenu installIfNeeded];
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:UIDeviceOrientationDidChangeNotification
                                                        object:nil
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *note) {
            [LCCornerFanMenu installIfNeeded];
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification
                                                        object:nil
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *note) {
            [LCCornerFanMenu installIfNeeded];
        }];
        [LCCornerFanMenu installIfNeeded];
    });
}

@end
