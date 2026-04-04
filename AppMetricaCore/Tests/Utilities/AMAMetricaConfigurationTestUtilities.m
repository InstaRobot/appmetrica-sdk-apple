
#import "AMAMetricaConfigurationTestUtilities.h"
#import "AMAMockDatabase.h"
#import <AppMetricaTestUtils/AMAKeychainBridgeMock.h>
#import <AppMetricaKiwi/AppMetricaKiwi.h>
#import "AMAInstantFeaturesConfiguration.h"
#import "AMAAppGroupIdentifierProvider.h"
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMAAppMetricaConfigurationProviderMock.h"
@import AppMetricaIdentifiers;

@implementation AMAMetricaConfigurationTestUtilities

+ (void)stubConfigurationWithAppVersion:(NSString *)appVersion buildNumber:(uint32_t)buildNumber
{
    [AMAPlatformDescription stub:@selector(appVersion) andReturn:appVersion];
    [AMAPlatformDescription stub:@selector(appBuildNumber) andReturn:[@(buildNumber) stringValue]];
    [self stubConfiguration];
}

+ (void)stubConfiguration
{
    AMAKeychainBridge *keychainBridge = [[AMAKeychainBridgeMock alloc] init];
    id<AMADatabaseProtocol> database = [AMAMockDatabase configurationDatabase];
    AMAAppMetricaConfigurationProviderMock *storingMock = [AMAAppMetricaConfigurationProviderMock new];
    
    AMAMetricaConfiguration *config =
        [[AMAMetricaConfiguration alloc] initWithKeychainBridge:keychainBridge
                                                       database:database
                                     appGroupIdentifierProvider:[AMAAppGroupIdentifierProvider new]
                                 appMetricaConfigurationStorage:storingMock];
    [AMAMetricaConfiguration amatest_setSharedInstanceOverride:config];
}

+ (void)stubConfigurationWithNullMock
{
    AMAMetricaConfiguration *configuration = [AMAMetricaConfiguration nullMock];
    [configuration stub:@selector(inMemory) andReturn:[[AMAMetricaInMemoryConfiguration alloc] init]];
    [configuration stub:@selector(persistent) andReturn:[AMAMetricaPersistentConfiguration nullMock]];
    [configuration stub:@selector(startup) andReturn:[AMAStartupParametersConfiguration nullMock]];
    [configuration stub:@selector(instant) andReturn:[AMAInstantFeaturesConfiguration nullMock]];
    [configuration stub:@selector(identifierProvider) andReturn:[KWMock nullMockForProtocol:@protocol(AMAIdentifierProviding)]];
    
    [AMAMetricaConfiguration amatest_setSharedInstanceOverride:configuration];
}

+ (void)destubConfiguration
{
    [AMAMetricaConfiguration amatest_setSharedInstanceOverride:nil];
    [AMAMetricaConfiguration clearStubs];
    [AMAPlatformDescription clearStubs];
}

@end
