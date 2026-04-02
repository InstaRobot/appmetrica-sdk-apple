
#import <AppMetricaKiwi/AppMetricaKiwi.h>
#import <AppMetricaTestUtils/AppMetricaTestUtils.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMADeviceDescription.h"
#import "AMAAppIdentifierProvider.h"
#import "AMAJailbreakCheck.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

SPEC_BEGIN(AMADeviceDescriptionTests)

describe(@"AMADeviceDescription", ^{
    
    context(@"Application", ^{
        
#if TARGET_OS_IPHONE
        afterEach(^{
            [[UIDevice currentDevice] clearStubs];
            [[UIScreen mainScreen] clearStubs];
        });
#endif
        
        it(@"Should return appIdentifierPrefix", ^{
            NSString *prefix = @"prefix";
            [AMAAppIdentifierProvider stub:@selector(appIdentifierPrefix) andReturn:prefix];
            
            [[[AMADeviceDescription appIdentifierPrefix] should] equal:prefix];
            
            [AMAAppIdentifierProvider clearStubs];
        });
        
        context(@"Jailbreak", ^{
            
            afterEach(^{
                [AMAJailbreakCheck clearStubs];
            });
            
#if TARGET_OS_IPHONE
            it(@"Should return device root status", ^{
                NSUInteger rand = arc4random_uniform(2) + 1;
                if (rand == 1) {
                    [AMAJailbreakCheck stub:@selector(jailbroken) andReturn:theValue(AMA_KFJailbroken)];
                    
                    [[theValue([AMADeviceDescription isDeviceRooted]) should] beYes];
                }
                else {
                    NSArray *jailChecks = @[
                        @(AMA_KFOpenURL),
                        @(AMA_KFCydia),
                        @(AMA_KFIFC),
                        @(AMA_KFPlist),
                        @(AMA_KFProcessesCydia),
                        @(AMA_KFProcessesOtherCydia),
                        @(AMA_KFProcessesOtherOCydia),
                        @(AMA_KFFSTab),
                        @(AMA_KFSystem),
                        @(AMA_KFSymbolic),
                        @(AMA_KFFileExists),
                    ];
                    NSUInteger rand = arc4random_uniform((uint32_t)[jailChecks count]);
                    NSUInteger value = [jailChecks objectAtIndex:rand];
                    
                    [AMAJailbreakCheck stub:@selector(jailbroken) andReturn:theValue(value)];
                    
                    [[theValue([AMADeviceDescription isDeviceRooted]) should] beNo];
                }
            });
#else
            it(@"Should always return not rooted on macOS", ^{
                [[theValue([AMADeviceDescription isDeviceRooted]) should] beNo];
            });
#endif
        });
        
#if TARGET_OS_IPHONE
        it(@"Should return true if current device contains device model", ^{
            NSString *deviceModel = @"AC-130";
            [[UIDevice currentDevice] stub:@selector(model) andReturn:[NSString stringWithFormat:@"%@H", deviceModel]];
            
            [[theValue([AMADeviceDescription isDeviceModelOfType:deviceModel]) should] beYes];
        });
        
        it(@"Should return UIScreen width", ^{
            CGRect bounds = [[UIScreen mainScreen] bounds];
            
            [[[AMADeviceDescription screenWidth] should] equal:[NSString stringWithFormat:@"%.0f",
                                                                CGRectGetWidth(bounds)]];
        });
        
        it(@"Should return UIScreen height", ^{
            CGRect bounds = [[UIScreen mainScreen] bounds];
            
            [[[AMADeviceDescription screenHeight] should] equal:[NSString stringWithFormat:@"%.0f",
                                                                 CGRectGetHeight(bounds)]];
        });
        
        it(@"Should return scalefactor", ^{
            [[UIScreen mainScreen] stub:@selector(scale) andReturn:theValue(30)];
            
            [[[AMADeviceDescription scalefactor] should] equal:@"30.00"];
        });
#else
        it(@"Should return non-empty screen width on macOS", ^{
            [[[AMADeviceDescription screenWidth] shouldNot] beNil];
            [[theValue([AMADeviceDescription screenWidth].length) should] beGreaterThan:theValue(0)];
        });

        it(@"Should return non-empty screen height on macOS", ^{
            [[[AMADeviceDescription screenHeight] shouldNot] beNil];
            [[theValue([AMADeviceDescription screenHeight].length) should] beGreaterThan:theValue(0)];
        });

        it(@"Should return non-empty scalefactor on macOS", ^{
            [[[AMADeviceDescription scalefactor] shouldNot] beNil];
            [[theValue([AMADeviceDescription scalefactor].length) should] beGreaterThan:theValue(0)];
        });
#endif
        
        it(@"Should return manufacturer", ^{
            [[[AMADeviceDescription manufacturer] should] equal:@"Apple"];
        });
        
#if TARGET_OS_IPHONE
        it(@"Should return OSVersion", ^{
            NSString *version = @"5.7";
            [[UIDevice currentDevice] stub:@selector(systemVersion) andReturn:version];
            
            [[[AMADeviceDescription OSVersion] should] equal:version];
        });
        
        it(@"Should return ipad if current idiom is ipad", ^{
            [[UIDevice currentDevice] stub:@selector(userInterfaceIdiom)
                                 andReturn:theValue(UIUserInterfaceIdiomPad)];
            
            [[[AMADeviceDescription appPlatform] should] equal:@"ipad"];
        });
        
        it(@"Should return iphone if current idiom is not ipad", ^{
            [[UIDevice currentDevice] stub:@selector(userInterfaceIdiom)
                                 andReturn:theValue(UIUserInterfaceIdiomTV)];
            
            [[[AMADeviceDescription appPlatform] should] equal:@"iphone"];
        });
#else
        it(@"Should return OSVersion on macOS", ^{
            NSString *version = [AMADeviceDescription OSVersion];
            [[version shouldNot] beNil];
            [[theValue(version.length) should] beGreaterThan:theValue(0)];
        });

        it(@"Should return mac as appPlatform on macOS", ^{
            [[[AMADeviceDescription appPlatform] should] equal:@"mac"];
        });
#endif
    });
});

SPEC_END
