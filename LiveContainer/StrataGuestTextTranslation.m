//
//  StrataGuestTextTranslation.m
//  Strata 汉化补充：SideStore 界面里烧在 storyboard nib 中的文案
//
//  SideStore 的运行方式是「把整个 .app 变成 SideStoreApp.framework 注入」，bootstrap 会把
//  NSBundle.mainBundle 整个换成这个 framework。framework 里没有任何 .lproj，因此
//  NSLocalizedString / SwiftUI Text 全部回落到英文原文；而设置页、登录页、标签栏这些
//  静态文字还存在 storyboard 的 nib 里，连本地化表都碰不到。
//
//  这里在 SideStore 访客进程内给几个 UIKit setter 挂钩，命中固定词表时替换成中文。
//  只在 mainBundle 是 SideStoreApp.framework 时生效，宿主进程和其他访客 App 不受影响。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSDictionary<NSString *, NSString *> *LCGuestTextMap(void) {
    static NSDictionary<NSString *, NSString *> *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            // MARK: - 标签栏 / 我的 App
            @"Browse": @"浏览",
            @"My Apps": @"我的 App",
            @"Sources": @"源",
            @"News": @"动态",
            @"Settings": @"设置",
            @"App IDs": @"App ID",
            @"View App IDs": @"查看 App ID",
            @"App IDs Description": @"App ID 说明",
            @"No Updates Available": @"暂无可用更新",
            @"What's New": @"更新内容",
            @"Permissions": @"权限",
            @"FREE": @"免费",

            // MARK: - 设置页：刷新
            @"Background Refresh": @"后台刷新",
            @"Disable Idle Timeout": @"禁用空闲超时",
            @"Allow Siri To Refresh Apps…": @"允许 Siri 刷新 App…",
            @"Allow Siri To Refresh Apps...": @"允许 Siri 刷新 App…",
            @"Allow Siri To Refresh Apps": @"允许 Siri 刷新 App…",
            @"Refresh Attempts": @"刷新记录",
            @"View Refresh Attempts": @"查看刷新记录",
            @"Change App Icon": @"更换 App 图标",
            @"Disable App Limit": @"解除 App 数量限制",
            @"Enable Beta Updates": @"启用测试版更新",
            @"Beta Updates Track": @"测试版更新通道",
            @"How it works": @"工作原理",
            @"Follow SideStore for updates": @"关注 SideStore 获取更新",

            // MARK: - 设置页：进阶
            @"Health Check": @"健康检查",
            @"View Error Log": @"查看错误日志",
            @"Error Log": @"错误日志",
            @"Storage Explorer": @"存储浏览器",
            @"Clear Data Cache…": @"清除数据缓存…",
            @"Clear Data Cache...": @"清除数据缓存…",
            @"Clear Data Cache": @"清除数据缓存…",
            @"Pairing File Management": @"配对文件管理",
            @"Anisette Servers": @"Anisette 服务器",
            @"Connection Config": @"连接配置",
            @"Network Discovery (mDNS)": @"网络发现（mDNS）",
            @"Developer Portal Services": @"开发者门户服务",
            @"Profiles Management": @"描述文件管理",
            @"Certificate Management": @"证书管理",
            @"Backup & Restore": @"备份与恢复",
            @"User Customizations": @"用户自定义",
            @"Prompt AppExtns Customization": @"App 扩展自定义提示",
            @"Developer Options": @"开发者选项",
            @"Experimental Features": @"实验性功能",
            @"Send Feedback": @"发送反馈",

            // MARK: - 设置页：账号与团队
            @"Sign in with Apple ID": @"使用 Apple ID 登录",
            @"Sign in with your Apple ID to get started.": @"使用 Apple ID 登录以开始使用。",
            @"Select a Team": @"选择团队",
            @"Team 1": @"团队 1",
            @"Developers": @"开发者",
            @"Support the team": @"支持团队",
            @"Support us": @"支持我们",
            @"Side Team": @"Side 团队",
            @"SideStore Team": @"SideStore 团队",
            @"UI Designer": @"界面设计",
            @"Asset Designer": @"素材设计",
            @"Licenses": @"许可协议",
            @"Software Licenses": @"开源许可",

            // MARK: - 设置页：错误弹窗
            @"Could not connect to SideStore.": @"无法连接到 SideStore。",
            @"Error Code": @"错误代码",
            @"Error Description": @"错误描述",
            @"Description": @"描述",
            @"Success": @"成功",

            // MARK: - nib 里剩余的表头 / 字段名
            @"Date": @"日期",
            @"Email": @"邮箱",
            @"Name": @"名称",
            @"Source Name": @"源名称",
            @"Type": @"类型",
            @"Developer": @"开发者",
            @"Installed": @"已安装",
            @"YES": @"是",
            @"NO": @"否",
            @"stable": @"稳定版",
            @"Classic games in your pocket": @"口袋里的经典游戏",

            // MARK: - 源
            @"Add Source": @"添加源",
            @"All Apps": @"全部 App",
            @"All News": @"全部动态",

            // MARK: - 登录 / 引导
            @"Welcome to SideStore.": @"欢迎使用 SideStore。",
            @"Sign in": @"登录",
            @"Close": @"关闭",
            @"Got it": @"知道了",
            @"Resign Later": @"稍后重签",
            @"Resign Now": @"立即重签",
            @"Resign SideStore": @"重签 SideStore",
            @"Launch SideStore": @"启动 SideStore",
            @"Download Apps": @"下载 App",
            @"Connect to Wi-Fi and VPN": @"连接 Wi-Fi 与 VPN",
            @"Apps Refresh Automatically": @"App 自动刷新",
            @"Apps are refreshed in the background while you are on SideStore VPN!": @"连接 SideStore VPN 时，App 会在后台自动刷新！",
            @"Browse and download apps directly from SideStore.": @"直接从 SideStore 浏览并下载 App。",
            @"Enable LocalDevVPN and use Sidestore on the go.": @"启用 LocalDevVPN，随时随地使用 SideStore。",
            @"Leave SideStore running in the background on your idevice.": @"让 SideStore 在设备后台保持运行。",
            @"Why do we need this?": @"为什么需要这样做？",
            @"PASSWORD": @"密码",
            @"APPLE ID": @"APPLE ID",
            @"ACCOUNT": @"账户",
            @"SIGN OUT": @"退出登录",
            @"Refresh All": @"全部刷新",
            @"Version Notes": @"版本说明",
            @"Your Apple ID is used to configure apps so they can be installed on this device. Your credentials will be stored securely in this device's Keychain and sent only to Apple for authentication.": @"你的 Apple ID 用于配置 App，使其能安装到本设备。你的凭据会安全保存在本机钥匙串中，仅发送给 Apple 用于验证。",
            @"Thank you for using SideStore!": @"感谢使用 SideStore！",
            @"Subscribing to the patreon supports us and makes sure we can continue developing SideStore for you.": @"订阅 Patreon 可以支持我们，让我们持续为你开发 SideStore。",
            @"Following us on social media allows us to give quick updates and spread the word about sideloading!": @"关注我们的社交媒体，可以第一时间获取更新，也帮我们把侧载介绍给更多人！",
            @"Become a patron!": @"成为赞助者！",
            @"Follow us on Twitter!": @"在 Twitter 上关注我们！",
            @"Follow us on Instagram!": @"在 Instagram 上关注我们！",
        };
    });
    return map;
}

// 注意：这里不能用 dispatch_once 缓存。LCBootstrap 是在 main() 之后才把 mainBundle
// 换成 SideStoreApp.framework 的，如果第一次求值发生在替换之前，dispatch_once 会把
// 「不是访客」这个结果永久锁死，钩子从此再也不生效（v17 就是这么失效的）。
static BOOL LCGuestTextTranslationEnabled(void) {
    static BOOL enabled = NO;
    if (enabled) {
        return YES;
    }
    NSString *path = [NSBundle mainBundle].bundlePath ?: @"";
    if ([path containsString:@"SideStoreApp.framework"]) {
        enabled = YES;
    }
    return enabled;
}

static NSString *LCGuestTranslateText(id text) {
    if (![text isKindOfClass:[NSString class]]) {
        return text;
    }
    if (!LCGuestTextTranslationEnabled()) {
        return text;
    }
    NSString *translated = LCGuestTextMap()[(NSString *)text];
    return translated ?: text;
}

static void LCSwapInstanceMethod(Class cls, SEL original, SEL replacement) {
    Method a = class_getInstanceMethod(cls, original);
    Method b = class_getInstanceMethod(cls, replacement);
    if (a && b) {
        method_exchangeImplementations(a, b);
    }
}

static NSString *LCAttributedReplacement(NSAttributedString *attributed) {
    if (![attributed isKindOfClass:[NSAttributedString class]] || attributed.length == 0) {
        return nil;
    }
    NSString *source = attributed.string;
    NSString *translated = LCGuestTranslateText(source);
    return [translated isEqualToString:source] ? nil : translated;
}

static NSAttributedString *LCAttributedWithText(NSAttributedString *attributed, NSString *text) {
    NSDictionary *attributes = attributed.length > 0 ? [attributed attributesAtIndex:0 effectiveRange:NULL] : nil;
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

static void LCTranslateViewTree(UIView *view, NSUInteger depth);

// nib 解码出来的静态文字（storyboard 里写死的 label/button 标题）不会走 setter 钩子，
// 所以再补一条「视图进窗口 / 控制器将出现时递归扫一遍」的路径。
static void LCTranslateSingleView(UIView *view) {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        NSString *text = label.text;
        if (text.length > 0) {
            NSString *translated = LCGuestTranslateText(text);
            if (![translated isEqualToString:text]) {
                label.text = translated;
            }
        }
        NSAttributedString *attributed = label.attributedText;
        NSString *replacement = LCAttributedReplacement(attributed);
        if (replacement) {
            label.attributedText = LCAttributedWithText(attributed, replacement);
        }
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        const UIControlState states[] = {
            UIControlStateNormal, UIControlStateHighlighted, UIControlStateSelected, UIControlStateDisabled
        };
        for (NSUInteger i = 0; i < sizeof(states) / sizeof(states[0]); i++) {
            NSString *title = [button titleForState:states[i]];
            if (title.length == 0) {
                continue;
            }
            NSString *translated = LCGuestTranslateText(title);
            if (![translated isEqualToString:title]) {
                [button setTitle:translated forState:states[i]];
            }
        }
        NSAttributedString *attributed = [button attributedTitleForState:UIControlStateNormal];
        NSString *replacement = LCAttributedReplacement(attributed);
        if (replacement) {
            [button setAttributedTitle:LCAttributedWithText(attributed, replacement) forState:UIControlStateNormal];
        }
    } else if ([view isKindOfClass:[UITextField class]]) {
        UITextField *field = (UITextField *)view;
        NSString *placeholder = field.placeholder;
        if (placeholder.length > 0) {
            NSString *translated = LCGuestTranslateText(placeholder);
            if (![translated isEqualToString:placeholder]) {
                field.placeholder = translated;
            }
        }
    } else if ([view isKindOfClass:[UISearchBar class]]) {
        UISearchBar *bar = (UISearchBar *)view;
        NSString *placeholder = bar.placeholder;
        if (placeholder.length > 0) {
            NSString *translated = LCGuestTranslateText(placeholder);
            if (![translated isEqualToString:placeholder]) {
                bar.placeholder = translated;
            }
        }
    } else if ([view isKindOfClass:[UISegmentedControl class]]) {
        UISegmentedControl *segmented = (UISegmentedControl *)view;
        for (NSUInteger i = 0; i < segmented.numberOfSegments; i++) {
            NSString *title = [segmented titleForSegmentAtIndex:i];
            if (title.length == 0) {
                continue;
            }
            NSString *translated = LCGuestTranslateText(title);
            if (![translated isEqualToString:title]) {
                [segmented setTitle:translated forSegmentAtIndex:i];
            }
        }
    }
}

static void LCTranslateViewTree(UIView *view, NSUInteger depth) {
    if (!view || depth > 24) {
        return;
    }
    LCTranslateSingleView(view);
    for (UIView *subview in view.subviews) {
        LCTranslateViewTree(subview, depth + 1);
    }
}

#pragma mark - setter 钩子（代码里动态设置的文案）

@interface UILabel (StrataGuestText)
- (void)lc_translate_setText:(NSString *)text;
@end
@implementation UILabel (StrataGuestText)
- (void)lc_translate_setText:(NSString *)text {
    [self lc_translate_setText:LCGuestTranslateText(text)];
}
@end

@interface UIButton (StrataGuestText)
- (void)lc_translate_setTitle:(NSString *)title forState:(UIControlState)state;
@end
@implementation UIButton (StrataGuestText)
- (void)lc_translate_setTitle:(NSString *)title forState:(UIControlState)state {
    [self lc_translate_setTitle:LCGuestTranslateText(title) forState:state];
}
@end

@interface UITabBarItem (StrataGuestText)
- (void)lc_translate_setTitle:(NSString *)title;
@end
@implementation UITabBarItem (StrataGuestText)
- (void)lc_translate_setTitle:(NSString *)title {
    [self lc_translate_setTitle:LCGuestTranslateText(title)];
}
@end

@interface UINavigationItem (StrataGuestText)
- (void)lc_translate_setTitle:(NSString *)title;
@end
@implementation UINavigationItem (StrataGuestText)
- (void)lc_translate_setTitle:(NSString *)title {
    [self lc_translate_setTitle:LCGuestTranslateText(title)];
}
@end

@interface UIBarButtonItem (StrataGuestText)
- (void)lc_translate_setTitle:(NSString *)title;
@end
@implementation UIBarButtonItem (StrataGuestText)
- (void)lc_translate_setTitle:(NSString *)title {
    [self lc_translate_setTitle:LCGuestTranslateText(title)];
}
@end

@interface UIViewController (StrataGuestText)
- (void)lc_translate_setTitle:(NSString *)title;
@end
@implementation UIViewController (StrataGuestText)
- (void)lc_translate_setTitle:(NSString *)title {
    [self lc_translate_setTitle:LCGuestTranslateText(title)];
}
@end

@interface UITextField (StrataGuestText)
- (void)lc_translate_setPlaceholder:(NSString *)placeholder;
@end
@implementation UITextField (StrataGuestText)
- (void)lc_translate_setPlaceholder:(NSString *)placeholder {
    [self lc_translate_setPlaceholder:LCGuestTranslateText(placeholder)];
}
@end

@interface UISearchBar (StrataGuestText)
- (void)lc_translate_setPlaceholder:(NSString *)placeholder;
@end
@implementation UISearchBar (StrataGuestText)
- (void)lc_translate_setPlaceholder:(NSString *)placeholder {
    [self lc_translate_setPlaceholder:LCGuestTranslateText(placeholder)];
}
@end

#pragma mark - 静态文字钩子（nib 解码不走 setter）

@interface UIView (StrataGuestTextTree)
- (void)lc_translate_didMoveToWindow;
@end
@implementation UIView (StrataGuestTextTree)
- (void)lc_translate_didMoveToWindow {
    [self lc_translate_didMoveToWindow];
    if (self.window && LCGuestTextTranslationEnabled()) {
        LCTranslateViewTree(self, 0);
    }
}
@end

@interface UIViewController (StrataGuestTextTree)
- (void)lc_translate_viewWillAppear:(BOOL)animated;
@end
@implementation UIViewController (StrataGuestTextTree)
- (void)lc_translate_viewWillAppear:(BOOL)animated {
    [self lc_translate_viewWillAppear:animated];
    if (!LCGuestTextTranslationEnabled()) {
        return;
    }
    NSString *title = self.title;
    NSString *translatedTitle = LCGuestTranslateText(title);
    if (title.length > 0 && ![translatedTitle isEqualToString:title]) {
        self.title = translatedTitle;
    }
    UINavigationItem *navigationItem = self.navigationItem;
    NSString *navigationTitle = navigationItem.title;
    NSString *translatedNavigationTitle = LCGuestTranslateText(navigationTitle);
    if (navigationTitle.length > 0 && ![translatedNavigationTitle isEqualToString:navigationTitle]) {
        navigationItem.title = translatedNavigationTitle;
    }
    UITabBarItem *tabBarItem = self.tabBarItem;
    NSString *tabTitle = tabBarItem.title;
    NSString *translatedTabTitle = LCGuestTranslateText(tabTitle);
    if (tabTitle.length > 0 && ![translatedTabTitle isEqualToString:tabTitle]) {
        tabBarItem.title = translatedTabTitle;
    }
    LCTranslateViewTree(self.view, 0);
}
@end

__attribute__((constructor))
static void LCInstallGuestTextTranslation(void) {
    LCSwapInstanceMethod([UILabel class], @selector(setText:), @selector(lc_translate_setText:));
    LCSwapInstanceMethod([UIButton class], @selector(setTitle:forState:), @selector(lc_translate_setTitle:forState:));
    LCSwapInstanceMethod([UITabBarItem class], @selector(setTitle:), @selector(lc_translate_setTitle:));
    LCSwapInstanceMethod([UINavigationItem class], @selector(setTitle:), @selector(lc_translate_setTitle:));
    LCSwapInstanceMethod([UIBarButtonItem class], @selector(setTitle:), @selector(lc_translate_setTitle:));
    LCSwapInstanceMethod([UIViewController class], @selector(setTitle:), @selector(lc_translate_setTitle:));
    LCSwapInstanceMethod([UITextField class], @selector(setPlaceholder:), @selector(lc_translate_setPlaceholder:));
    LCSwapInstanceMethod([UISearchBar class], @selector(setPlaceholder:), @selector(lc_translate_setPlaceholder:));
    LCSwapInstanceMethod([UIView class], @selector(didMoveToWindow), @selector(lc_translate_didMoveToWindow));
    LCSwapInstanceMethod([UIViewController class], @selector(viewWillAppear:), @selector(lc_translate_viewWillAppear:));
}
