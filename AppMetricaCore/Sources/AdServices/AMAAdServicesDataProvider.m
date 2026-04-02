
#import "AMACore.h"
#import "AMAAdServicesDataProvider.h"

#define AMA_ADSERVICES_AVAILABLE 0
#if TARGET_OS_IPHONE && !TARGET_OS_TV
    #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140300
        #undef AMA_ADSERVICES_AVAILABLE
        #define AMA_ADSERVICES_AVAILABLE 1
    #endif
#elif TARGET_OS_MAC && !TARGET_OS_IPHONE
    #if __MAC_OS_X_VERSION_MAX_ALLOWED >= 110100
        #undef AMA_ADSERVICES_AVAILABLE
        #define AMA_ADSERVICES_AVAILABLE 1
    #endif
#endif

#if AMA_ADSERVICES_AVAILABLE
    #import <AdServices/AdServices.h>
#endif

#import "AMAFramework.h"
#import "AMAMetricaDynamicFrameworks.h"

@interface AMAAdServicesDataProvider ()

@property (nonatomic, strong, readonly) AMAFramework *adServices;

@end

@implementation AMAAdServicesDataProvider

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _adServices = AMAMetricaDynamicFrameworks.adServices;
    }

    return self;
}

- (NSString *)tokenWithError:(NSError **)error
{
#if AMA_ADSERVICES_AVAILABLE && !TARGET_OS_SIMULATOR
    if (@available(iOS 14.3, macOS 11.1, *)) {
        NSError *localError = nil;
        Class aaAttribution = [self.adServices classFromString:@"AAAttribution"];
        if (aaAttribution != Nil) {
            NSString *token = [aaAttribution attributionTokenWithError:&localError];

            if (token != nil) {
                AMALogInfo(@"AdServices token successfully received!");
            }
            else if (localError != nil) {
                AMALogInfo(@"AdServices attribution token error: %@", localError);
                [AMAErrorUtilities fillError:error withError:localError];
            }
            else {
                AMALogInfo(@"AdServices available, but received unexpected `nil` token");
                [AMAErrorUtilities fillError:error withInternalErrorName:@"AdServices available. Nil token"];
            }

            return token;
        }
    }
#endif
    AMALogInfo(@"AdServices unavailable");
    [AMAErrorUtilities fillError:error withInternalErrorName:@"AdServices unavailable"];
    return nil;
}

@end
