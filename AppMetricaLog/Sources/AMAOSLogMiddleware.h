
#import "AMALogMiddleware.h"

API_AVAILABLE(ios(10.0), macos(10.12), tvos(10.0))
@interface AMAOSLogMiddleware : NSObject <AMALogMiddleware>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithCategory:(const char *)category;

@end
