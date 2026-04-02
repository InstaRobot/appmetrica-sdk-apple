
#import "AMAStorageTrimManager.h"
#import "AMANotificationsListener.h"
#import "AMADatabaseProtocol.h"
#import "AMAStorageTrimming.h"
#import "AMAStorageEventsTrimTransaction.h"
#import "AMAPlainStorageTrimmer.h"
#import "AMAReporterNotifications.h"
#import "AMAEventsCountStorageTrimmer.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <dispatch/dispatch.h>
#endif

@interface AMAStorageTrimManager ()

@property (nonatomic, copy, readonly) NSString *apiKey;
@property (nonatomic, strong, readonly) AMAEventsCleaner *eventsCleaner;
@property (nonatomic, strong, readonly) AMANotificationsListener *listener;
#if !TARGET_OS_IPHONE
@property (nonatomic, strong) dispatch_source_t memoryPressureSource;
@property (nonatomic, strong) NSHashTable *memoryPressureDatabases;
@property (nonatomic, strong) NSMutableArray *memoryPressureTrimmers;
#endif

@end

@implementation AMAStorageTrimManager

- (instancetype)initWithApiKey:(NSString *)apiKey
                 eventsCleaner:(AMAEventsCleaner *)eventsCleaner
{
    return [self initWithApiKey:apiKey
                  eventsCleaner:eventsCleaner
          notificationsListener:[AMANotificationsListener new]];
}

- (instancetype)initWithApiKey:(NSString *)apiKey
                 eventsCleaner:(AMAEventsCleaner *)eventsCleaner
         notificationsListener:(AMANotificationsListener *)listener
{
    self = [super init];
    if (self != nil) {
        _apiKey = [apiKey copy];
        _eventsCleaner = eventsCleaner;
        _listener = listener;
    }
    return self;
}

#pragma mark - Public -

- (void)subscribeDatabase:(id<AMADatabaseProtocol>)database
{
    switch (database.databaseType) {
        case AMADatabaseTypeInMemory:
            [self subscribeDatabaseToMemoryWarningTrim:database];
            break;

        case AMADatabaseTypePersistent:
            [self subscribeDatabaseToEventsCountTrim:database];
            break;

        default:
            break;
    }
}

- (void)unsubscribeDatabase:(id<AMADatabaseProtocol>)database
{
    [self.listener unsubscribeObject:database];
}

#pragma mark - Private -

- (void)subscribeDatabaseToMemoryWarningTrim:(id<AMADatabaseProtocol>)database
{
    AMAStorageEventsTrimTransaction *transaction =
        [[AMAStorageEventsTrimTransaction alloc] initWithCleaner:self.eventsCleaner];
    AMAPlainStorageTrimmer *trimmer = [[AMAPlainStorageTrimmer alloc] initWithTrimTransaction:transaction];
    __weak __typeof(database) weakDatabase = database;
#if TARGET_OS_IPHONE
    NSNotificationName memoryNotification = UIApplicationDidReceiveMemoryWarningNotification;
    [self.listener subscribeObject:database
                    toNotification:memoryNotification
                      withCallback:^(NSNotification *notification) {
        [trimmer trimDatabase:weakDatabase];
    }];
#else
    @synchronized (self) {
        if (self.memoryPressureDatabases == nil) {
            self.memoryPressureDatabases = [NSHashTable weakObjectsHashTable];
            self.memoryPressureTrimmers = [NSMutableArray array];
        }
        [self.memoryPressureDatabases addObject:database];
        [self.memoryPressureTrimmers addObject:trimmer];

        if (self.memoryPressureSource == nil) {
            dispatch_source_t source = dispatch_source_create(
                DISPATCH_SOURCE_TYPE_MEMORYPRESSURE,
                0,
                DISPATCH_MEMORYPRESSURE_WARN | DISPATCH_MEMORYPRESSURE_CRITICAL,
                dispatch_get_main_queue()
            );
            __weak __typeof(self) weakSelf = self;
            dispatch_source_set_event_handler(source, ^{
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf == nil) { return; }
                @synchronized (strongSelf) {
                    NSArray *trimmers = [strongSelf.memoryPressureTrimmers copy];
                    NSArray *databases = strongSelf.memoryPressureDatabases.allObjects;
                    for (NSUInteger i = 0; i < trimmers.count && i < databases.count; i++) {
                        [trimmers[i] trimDatabase:databases[i]];
                    }
                }
            });
            dispatch_resume(source);
            self.memoryPressureSource = source;
        }
    }
#endif
}

- (void)subscribeDatabaseToEventsCountTrim:(id<AMADatabaseProtocol>)database
{
    AMAStorageEventsTrimTransaction *transaction =
        [[AMAStorageEventsTrimTransaction alloc] initWithCleaner:self.eventsCleaner];
    AMAEventsCountStorageTrimmer *trimmer = [[AMAEventsCountStorageTrimmer alloc] initWithApiKey:self.apiKey
                                                                                 trimTransaction:transaction];
    NSString *expectedApiKey = self.apiKey;
    __weak __typeof(database) weakDatabase = database;
    [self.listener subscribeObject:database
                    toNotification:kAMAReporterDidAddEventNotification
                      withCallback:^(NSNotification *notification) {
        NSString *apiKey = notification.userInfo[kAMAReporterDidAddEventNotificationUserInfoKeyApiKey];
        if (apiKey == nil || [apiKey isEqual:expectedApiKey] == NO) {
            return;
        }
        AMALogInfo(@"Check event count trimming for '%@'. Notification: %@", apiKey, notification);
        [trimmer handleEventAdding];
        [trimmer trimDatabase:weakDatabase];
    }];
}

@end
