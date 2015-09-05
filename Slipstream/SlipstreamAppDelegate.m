/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Parse/Parse.h>
#import <ZipZap/ZipZap.h>
#import "SlipstreamAppDelegate.h"
#import "SlipstreamViewController.h"

@implementation SlipstreamAppDelegate

#pragma mark -
#pragma mark UIApplicationDelegate

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

    return YES;
}

#pragma mark Push Notifications

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
//    for(NSString *key in [userInfo allKeys]) {
//        NSLog(@"%@",[userInfo objectForKey:key]);
//    }
    
    ZZArchive* oldArchive = [ZZArchive archiveWithURL:[NSURL fileURLWithPath:@"/tmp/old.zip"]
                                                error:nil];
//    ZZArchiveEntry* firstArchiveEntry = oldArchive.entries[0];
//    NSLog(@"The first entry's uncompressed size is %lu bytes.", (unsigned long)firstArchiveEntry.uncompressedSize);
//    NSLog(@"The first entry's data is: %@.", [firstArchiveEntry newDataWithError:nil]);
    
    completionHandler(UIBackgroundFetchResultNewData);
}

@end
