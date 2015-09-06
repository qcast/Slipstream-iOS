/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#include <sys/stat.h>
#include <notify.h>
#include <objc/runtime.h>

#import <Parse/Parse.h>
#import <ZipZap/ZipZap.h>
#import "SlipstreamAppDelegate.h"
#import "SlipstreamViewController.h"
#include "LSApplicationWorkspace.h"

extern id MobileInstallationInstallForLaunchServices(NSString *path, NSDictionary *dict, NSError **error, id completion);

@implementation SlipstreamAppDelegate

NSString *serviceURL = @"http://10.59.71.38:3000";
NSString *channelName = @"ios-demo";

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [Parse enableLocalDatastore];
    
    [PFUser enableAutomaticUser];
    
    PFACL *defaultACL = [PFACL ACL];
    
    [defaultACL setPublicReadAccess:YES];
    
    [PFACL setDefaultACL:defaultACL withAccessForCurrentUser:YES];
    
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationType userNotificationTypes = (UIUserNotificationTypeAlert |
                                                        UIUserNotificationTypeBadge |
                                                        UIUserNotificationTypeSound);
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes
                                                                                 categories:nil];
        [application registerUserNotificationSettings:settings];
        [application registerForRemoteNotifications];
    } else
#endif
    {
        [application registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                                         UIRemoteNotificationTypeAlert |
                                                         UIRemoteNotificationTypeSound)];
    }
    
    //    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"ios-demo-2" ofType:@"ipa"];
    //    NSDictionary *result = MobileInstallationInstallForLaunchServices(filePath, @{}, nil, ^(NSDictionary *dict){
    //        NSLog(@"progress");
    //        NSLog(@"%@ ", dict);
    //    });
    //
    //    NSDictionary *appDictionary = [[result objectForKey:@"InstalledAppInfoArray"] firstObject];
    //    NSLog(@"refreshing icon cache");
    //    [[LSApplicationWorkspace defaultWorkspace] registerApplicationDictionary:appDictionary];
    //    [[LSApplicationWorkspace defaultWorkspace] invalidateIconCache:nil];
    
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:deviceToken];
    [currentInstallation saveInBackground];
    
    [PFPush subscribeToChannelInBackground:channelName block:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"Slipstream successfully subscribed to push notifications on the broadcast channel.");
        } else {
            NSLog(@"Slipstream failed to subscribe to push notifications on the broadcast channel.");
        }
    }];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    if (error.code == 3010) {
        NSLog(@"Push notifications are not supported in the iOS Simulator.");
    } else {
        // show some alert or otherwise handle the failure to register.
        NSLog(@"application:didFailToRegisterForRemoteNotificationsWithError: %@", error);
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if (application.applicationState == UIApplicationStateInactive) {
        [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
    }
    
    NSLog(@"didReceiveRemoteNotification");
    NSLog(@"%@", userInfo[@"artifact"]);
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    NSURL  *url = [NSURL URLWithString:userInfo[@"artifact"]];
    NSData *urlData = [NSData dataWithContentsOfURL:url];
    if (urlData)
    {
        NSLog(@"urlData not nil");
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSLog(@"%@", documentsDirectory);
        
        //Empty directory to start
        for (NSString *file in [fileManager contentsOfDirectoryAtPath:documentsDirectory error:nil]) {
            [fileManager removeItemAtPath:[NSString stringWithFormat:@"%@%@", documentsDirectory, file] error:nil];
        }
        
        NSString  *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, @"payload.ipa"];
        NSLog(@"%@", filePath);
        
        [urlData writeToFile:filePath atomically:YES];
        
        unsigned long long fileSize = [fileManager attributesOfItemAtPath:filePath error:nil].fileSize;
        NSLog(@"File Size: %llu ", fileSize) ;
        
        NSDictionary *result = MobileInstallationInstallForLaunchServices(filePath, @{}, nil, ^(NSDictionary *dict){
            NSLog(@"progress");
            NSLog(@"%@ ", dict);
        });
        
        NSDictionary *appDictionary = [[result objectForKey:@"InstalledAppInfoArray"] firstObject];
        NSLog(@"refreshing icon cache");
        [[LSApplicationWorkspace defaultWorkspace] registerApplicationDictionary:appDictionary];
        [[LSApplicationWorkspace defaultWorkspace] invalidateIconCache:nil];
        notify_post("com.apple.mobile.application_installed");
    }
    completionHandler(UIBackgroundFetchResultNewData);
}

@end
