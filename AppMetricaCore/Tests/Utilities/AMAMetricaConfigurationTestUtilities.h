
#import <Foundation/Foundation.h>
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAStartupParametersConfiguration.h"

@interface AMAMetricaConfiguration (AMATestOverride)
+ (void)amatest_setSharedInstanceOverride:(AMAMetricaConfiguration *)instance;
@end

@interface AMAMetricaConfigurationTestUtilities : NSObject

+ (void)stubConfigurationWithAppVersion:(NSString *)appVersion buildNumber:(uint32_t)buildNumber;
+ (void)stubConfiguration;
+ (void)stubConfigurationWithNullMock;
+ (void)destubConfiguration;

@end
