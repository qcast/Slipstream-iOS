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

@implementation SlipstreamAppDelegate

#pragma mark -
#pragma mark UIApplicationDelegate

#define kMobileInstallationPlistPath @"/var/mobile/Library/Caches/com.apple.mobile.installation.plist"

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
    
    NSLog([NSString stringWithFormat:@"Running as: %u", getuid()]) ;
    
    NSLog(@"didReceiveRemoteNotification");
    NSLog(userInfo[@"artifact"]);
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    NSURL  *url = [NSURL URLWithString:userInfo[@"artifact"]];
    NSData *urlData = [NSData dataWithContentsOfURL:url];
    if ( urlData )
    {
        NSLog(@"urlData not none");
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        
        //Empty directory to start
        for (NSString *file in [fileManager contentsOfDirectoryAtPath:documentsDirectory error:nil]) {
            [fileManager removeItemAtPath:[NSString stringWithFormat:@"%@%@", documentsDirectory, file] error:nil];
        }
        
        NSLog(documentsDirectory);
        
        NSString  *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, @"payload.zip"];
        
        NSLog(filePath);
        
        [urlData writeToFile:filePath atomically:YES];
        
        unsigned long long fileSize = [fileManager attributesOfItemAtPath:filePath error:nil].fileSize;
        NSLog([NSString stringWithFormat:@"File Size: %llu", fileSize]) ;
        
        NSURL* path = [NSURL fileURLWithPath:documentsDirectory];
        ZZArchive* archive = [ZZArchive archiveWithURL:[NSURL fileURLWithPath:filePath]  error:nil];
        NSLog([NSString stringWithFormat:@"Num entries: %lu", (unsigned long)[archive.entries count]]);
        
        //Extract full zip
        for (ZZArchiveEntry* entry in archive.entries)
        {
            NSURL* targetPath = [path URLByAppendingPathComponent:entry.fileName];
            
            if (entry.fileMode & S_IFDIR)
                // check if directory bit is set
                [fileManager createDirectoryAtURL:targetPath
                      withIntermediateDirectories:YES
                                       attributes:nil
                                            error:nil];
            else
            {
                // Some archives don't have a separate entry for each directory
                // and just include the directory's name in the filename.
                // Make sure that directory exists before writing a file into it.
                [fileManager createDirectoryAtURL:
                 [targetPath URLByDeletingLastPathComponent]
                      withIntermediateDirectories:YES
                                       attributes:nil
                                            error:nil];
                
                [[entry newDataWithError:nil] writeToURL:targetPath
                                              atomically:NO];
            }
        }
        
        //Create directory for application
        NSString *appPath = [@"/var/mobile/Applications" stringByAppendingPathComponent:channelName];
        NSError *appPathError;
        NSLog(appPath);
        if(![fileManager createDirectoryAtPath:appPath withIntermediateDirectories:YES attributes:nil error:&appPathError])
        {
            NSLog(@"Error: %@", appPathError);
        }
        CFRelease((__bridge CFTypeRef)(channelName));
        
        //Copy .app bundle
        NSLog(@"Payload path");
        NSString *payloadPath = [documentsDirectory stringByAppendingPathComponent:@"Payload"];
        NSLog(payloadPath);
        NSArray *payloadContents = [fileManager contentsOfDirectoryAtPath:payloadPath error:nil];
        NSError *error;
        
        NSString *bundlePath = [payloadPath stringByAppendingPathComponent:payloadContents[0]];
        NSLog(@"Bundle path");
        NSLog(bundlePath);
        
        //Set permissions
        NSMutableDictionary *appInfoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"Info.plist"]];
        NSString *execName = [appInfoPlist objectForKey:@"CFBundleExecutable"];
        NSString *execPath = [bundlePath stringByAppendingPathComponent:execName];
        chmod(execPath.UTF8String, 0755);
        
        //Create the path for the destination by appending the file name
        NSString *dest = [appPath stringByAppendingPathComponent: payloadContents[0]];
        NSLog(@"dest:");
        NSLog(dest);
        
        if(![fileManager copyItemAtPath:bundlePath
                                 toPath:dest
                                  error:&error])
        {
            NSLog(@"Error: %@", error);
        }
        
        // Reload app cache
        //        [appInfoPlist setObject:@"User" forKey:@"ApplicationType"];
        //        [appInfoPlist setObject:bundlePath forKey:@"Path"];
        //        [appInfoPlist setObject:@{
        //                                  @"CFFIXED_USER_HOME" : appPath,
        //                                  @"HOME" : appPath,
        //                                  @"TMPDIR" : [appPath stringByAppendingPathComponent:@"tmp"]
        //                                  } forKey:@"EnvironmentVariables"];
        //        [appInfoPlist setObject:appPath forKey:@"Container"];
        //
        //        NSData *data = [NSData dataWithContentsOfFile:kMobileInstallationPlistPath];
        //        NSMutableDictionary *mobileInstallation = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:NULL error:NULL];
        //        NSString *bundleID = [appInfoPlist objectForKey:@"CFBundleIdentifier"];
        //        [[mobileInstallation objectForKey:@"User"] setObject:appInfoPlist forKey:bundleID];
        //        [mobileInstallation writeToFile:kMobileInstallationPlistPath atomically:NO];
        
        //Remove cached app info
        remove("/var/mobile/Library/Caches/com.apple.mobile.installation.plist");
        remove("/var/mobile/Library/Caches/com.apple.springboard-imagecache-icons");
        remove("/var/mobile/Library/Caches/com.apple.springboard-imagecache-icons.plist");
        remove("/var/mobile/Library/Caches/com.apple.springboard-imagecache-smallicons");
        remove("/var/mobile/Library/Caches/com.apple.springboard-imagecache-smallicons.plist");
        remove("/var/mobile/Library/Caches/SpringBoardIconCache");
        remove("/var/mobile/Library/Caches/SpringBoardIconCache-small");
        remove("/var/mobile/Library/Caches/com.apple.IconsCache");
        
        //Respring
        Class __LSApplicationWorkspace = objc_getClass("LSApplicationWorkspace");
        //            [(LSApplicationWorkspace *)[__LSApplicationWorkspace defaultWorkspace] invalidateIconCache:nil];
        //            [(LSApplicationWorkspace *)[__LSApplicationWorkspace defaultWorkspace] registerApplication:[NSURL fileURLWithPath:bundle]];
        notify_post("com.apple.mobile.application_installed");
        
    }
    completionHandler(UIBackgroundFetchResultNewData);
}

@end
