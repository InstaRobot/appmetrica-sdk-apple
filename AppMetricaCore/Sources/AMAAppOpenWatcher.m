
#import "AMACore.h"
#import "AMAAppOpenWatcher.h"
#import "AMADeepLinkController.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#endif

@interface AMAAppOpenWatcher ()

@property (nonatomic, strong, readonly) NSNotificationCenter *notificationCenter;
@property (atomic, strong) AMADeepLinkController *deepLinkController;

@end

@implementation AMAAppOpenWatcher

- (instancetype)init
{
    return [self initWithNotificationCenter:[NSNotificationCenter defaultCenter]];
}

#pragma mark - Public -

- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)center
{
    self = [super init];
    if (self != nil) {
        _notificationCenter = center;
    }

    return self;
}

- (void)startWatchingWithDeeplinkController:(AMADeepLinkController *)controller
{
    AMALogInfo(@"Start");
    self.deepLinkController = controller;
#if TARGET_OS_IPHONE
    [self.notificationCenter addObserver:self
                                selector:@selector(didFinishLaunching:)
                                    name:UIApplicationDidFinishLaunchingNotification
                                  object:nil];
#else
    [self.notificationCenter addObserver:self
                                selector:@selector(didFinishLaunching:)
                                    name:NSApplicationDidFinishLaunchingNotification
                                  object:nil];
    [[NSAppleEventManager sharedAppleEventManager]
        setEventHandler:self
            andSelector:@selector(handleGetURLEvent:withReplyEvent:)
          forEventClass:kInternetEventClass
             andEventID:kAEGetURL];
#endif
}

#pragma mark - NSNotificationCenter callback

- (void)didFinishLaunching:(NSNotification *)notification
{
    AMALogInfo(@"User info: %@", notification.userInfo);
    NSURL *url = [self extractDeeplink:notification.userInfo];
    [self.deepLinkController reportUrl:url ofType:kAMADLControllerUrlTypeOpen isAuto:YES];
}

#if !TARGET_OS_IPHONE
- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event
           withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    AMALogInfo(@"macOS URL event: %@", urlString);
    if (urlString.length > 0) {
        NSURL *url = [NSURL URLWithString:urlString];
        [self.deepLinkController reportUrl:url ofType:kAMADLControllerUrlTypeOpen isAuto:YES];
    }
}
#endif

#pragma mark - Private -

- (NSURL *)extractDeeplink:(NSDictionary *)userInfo
{
    NSURL *__block openUrl = nil;
#if TARGET_OS_IPHONE
    if ([userInfo[UIApplicationLaunchOptionsURLKey] isKindOfClass:NSURL.class]) {
        openUrl = userInfo[UIApplicationLaunchOptionsURLKey];
    }
    if (openUrl.absoluteString.length == 0) {
        if ([userInfo[UIApplicationLaunchOptionsUserActivityDictionaryKey] isKindOfClass:NSDictionary.class]) {
            NSDictionary *userActivity = userInfo[UIApplicationLaunchOptionsUserActivityDictionaryKey];
            [userActivity enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
                if ([value isKindOfClass:NSUserActivity.class]) {
                    NSUserActivity *activity = value;
                    openUrl = activity.webpageURL;
                    *stop = YES;
                }
            }];
        }
    }
#endif
    return openUrl;
}

@end
