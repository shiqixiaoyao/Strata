//
//  main.m
//  LiveContainer
//
//  Created by s s on 2026/2/17.
//
#import "LCShareExtensionLauncher.h"
#import "../LiveContainer/utils.h"
#import "../LiveContainer/UIKitPrivate.h"

static Class LSApplicationWorkspaceClass;
static Class _LSOpenConfigurationClass;

@implementation LCShareExtensionLauncher

+ (BOOL)openURLFromShareExtension:(NSURL *)url {
    return [self openURLFromShareExtensionWithOptions:@{ @"url": url }];
}

+ (BOOL)openURLFromShareExtensionWithOptions:(NSDictionary *)options {
    // unfortunately SpringBoard blocks openURL for iOS 10+ new extension types, so we need to chain through this old extension type to open the URL
    NSURL *url = options[@"url"];
    if (![url isKindOfClass:NSURL.class]) {
        return NO;
    }

    LSApplicationWorkspace* workspace = [LSApplicationWorkspaceClass defaultWorkspace];

    NSString* bundleIdToLaunch = nil;
    NSString* scheme = url.scheme;
    if([scheme isEqualToString:@"livecontainer"] || [scheme isEqualToString:@"sidestore"]) {
        bundleIdToLaunch = NSBundle.mainBundle.bundleIdentifier.stringByDeletingPathExtension;
    } else {
        bundleIdToLaunch = [NSUserDefaults.lcSharedDefaults stringForKey:[NSString stringWithFormat:@"LCBundleID.%@", scheme]];
    }

    __block BOOL success = NO;
    if(scheme) {
        NSNumber *classicMode = options[@"classicMode"];
        if ([classicMode isKindOfClass:NSNumber.class] && classicMode.unsignedIntegerValue != 0) {
            _LSOpenConfiguration *classicConfig = [[_LSOpenConfigurationClass alloc] init];
            classicConfig.frontBoardOptions = @{
                FBSOpenApplicationOptionKeyActivateAsClassic: classicMode
            };
            [workspace openApplicationWithBundleIdentifier:bundleIdToLaunch configuration:classicConfig completionHandler:nil];
        }

        _LSOpenConfiguration *config = [[_LSOpenConfigurationClass alloc] init];
        config.frontBoardOptions = @{
            FBSOpenApplicationOptionKeyPayloadURL: url
        };
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);

        [workspace openApplicationWithBundleIdentifier:bundleIdToLaunch usingConfiguration:config completionHandler:^(BOOL success1, NSError * err) {
            success = success1;
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    }
    if(!success) {
        [workspace openURL:url];
    }

    return true;
}

+ (BOOL)canOpenURLFromShareExtension:(NSURL *)url {
    id error = nil;
    return [[PrivClass(LSApplicationWorkspace) defaultWorkspace] isApplicationAvailableToOpenURL:url error:&error];
}

+ (void)load {
    _LSOpenConfigurationClass = PrivClass(_LSOpenConfiguration);
    LSApplicationWorkspaceClass = PrivClass(LSApplicationWorkspace);
}

@end

// 这里原来复制了 `lcMainBundle` 全局 + 一个同名 category 覆盖，
// 只为了在扩展进程里把「宿主 App bundle」塞给 +lcMainBundle。
// 现在统一由 Localization.m 的 +lcMainBundle 处理（lcMainBundle 为 nil 时按
// .appex 结构上溯两级），扩展里不必再各自维护一份。
