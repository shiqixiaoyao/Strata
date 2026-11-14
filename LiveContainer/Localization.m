//
//  Localization.m
//  LiveContainer
//
//  Created by s s on 2024/9/21.
//
#import "Localization.h"

// 由 LCBootstrap 在启动主 App / 访客进程时赋值；扩展进程不会走 bootstrap，
// 所以这里保留为 nil，由下面的 +lcMainBundle 自行推导。
extern NSBundle *lcMainBundle;

@implementation NSUserDefaults (Localization)

/// 所有本地化查表都从这里取 bundle，全工程只保留这一份实现。
///
/// - 主 App / 访客进程：LCBootstrap 已经把 lcMainBundle 指向宿主 App；
/// - 扩展进程（.appex）：没走 bootstrap，lcMainBundle 为 nil，
///   此时按 `…/Host.app/PlugIns/Host.appex` 的结构上溯两级拿回宿主 App。
///   早期是在 ShareExtension/main.m 里用同名 category 覆盖掉的，
///   那样每个扩展都要复制一遍，且谁生效取决于镜像加载顺序。
+ (NSBundle *)lcMainBundle {
    if (lcMainBundle) {
        return lcMainBundle;
    }
    NSBundle *main = [NSBundle mainBundle];
    if ([main.bundleURL.pathExtension isEqualToString:@"appex"]) {
        return [NSBundle bundleWithURL:main.bundleURL.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent];
    }
    return main;
}

@end

@implementation NSString (Localization)

// Class method for the English language bundle
+ (NSBundle *)enBundle {
    static NSBundle *enBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *language = @"en";
        NSString *path = [[NSUserDefaults lcMainBundle] pathForResource:language ofType:@"lproj"];
        enBundle = path ? [NSBundle bundleWithPath:path] : nil;
    });
    return enBundle;
}

// Instance method to return a localized string
- (NSString *)localized {
    NSString *message = [[NSUserDefaults lcMainBundle] localizedStringForKey:self value:@"" table:nil];

    // 查不到时 localizedStringForKey: 会原样返回 key（value 为 @"" 兜底），
    // 这里再退到 en 表，最后才把 key 本身交出去。
    if (message.length && ![message isEqualToString:self]) {
        return message;
    }

    NSString *forcedString = [[NSString enBundle] localizedStringForKey:self value:nil table:nil];

    if (forcedString) {
        return forcedString;
    } else {
        return self;
    }
}

// Instance method for localization with format
- (NSString *)localizeWithFormat:(NSString*)arg1, ... {
    va_list args;
    va_start(args, arg1);
    NSString *formattedString = [NSString localizedStringWithFormat:[self localized], arg1, args];
//    NSString *formattedString = [[NSString alloc] localized:[self localized] arguments:arg1, args];
    va_end(args);
    return formattedString;
}

@end
