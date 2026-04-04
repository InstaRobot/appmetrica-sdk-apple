
#import <AppMetricaKiwi/AppMetricaKiwi.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMAAppMetricaPluginsImpl.h"

SPEC_BEGIN(AMAAppMetricaPluginsImplTests)

describe(@"AMAAppMetricaPluginsImpl", ^{

    AMAAppMetricaPluginsImpl *__block pluginsImpl = nil;
    AMAPluginErrorDetails *__block errorDetails = nil;
    NSObject<AMAAppMetricaPluginReporting> *__block pluginReporter = nil;
    NSError *__block resultError = nil;
    void __block (^onFailure)(NSError *) = nil;

    beforeEach(^{
        [AMAFailureDispatcher stub:@selector(dispatchError:withBlock:) withBlock:^id(NSArray *params) {
            NSError *error = params[0];
            void (^block)(NSError *) = params[1];
            if (block != nil && error != nil) {
                block(error);
            }
            return nil;
        }];
        pluginsImpl = [[AMAAppMetricaPluginsImpl alloc] init];
        resultError = nil;
        errorDetails = [AMAPluginErrorDetails nullMock];
        pluginReporter = [KWMock nullMockForProtocol:@protocol(AMAAppMetricaPluginReporting)];
        onFailure = ^void (NSError *error) {
            resultError = error;
        };
    });
    afterEach(^{
        [pluginsImpl setupCrashReporter:nil];
        pluginsImpl = nil;
        [pluginReporter clearStubs];
        pluginReporter = nil;
        [AMAFailureDispatcher clearStubs];
    });

    context(@"Report unhandled exception", ^{
        it(@"Should not report if not configured", ^{
            [pluginsImpl reportUnhandledException:errorDetails onFailure:onFailure];
            [[resultError shouldNot] beNil];
        });
        it(@"Should report if configured", ^{
            [pluginsImpl setupCrashReporter:pluginReporter];
            [[pluginReporter should] receive:@selector(reportUnhandledException:onFailure:) 
                               withArguments:errorDetails, onFailure];
            
            [pluginsImpl reportUnhandledException:errorDetails onFailure:onFailure];
            [[resultError should] beNil];
        });
    });

    context(@"Report error", ^{
        NSString *message = @"some message";
        it(@"Should not report if not configured", ^{;
            [pluginsImpl reportError:errorDetails message:message onFailure:onFailure];
            [[resultError shouldNot] beNil];
        });
        it(@"Should report if configured", ^{
            [pluginsImpl setupCrashReporter:pluginReporter];
            [[pluginReporter should] receive:@selector(reportError:message:onFailure:) 
                               withArguments:errorDetails, message, onFailure];
            
            [pluginsImpl reportError:errorDetails message:message onFailure:onFailure];
            [[resultError should] beNil];
        });
    });

    context(@"Report error with identifier", ^{
        NSString *identifier = @"some id";
        NSString *message = @"some message";
        it(@"Should not report if not configured", ^{
            [pluginsImpl reportErrorWithIdentifier:identifier
                                           message:message
                                           details:errorDetails
                                         onFailure:onFailure];
            [[resultError shouldNot] beNil];
        });
        it(@"Should report if configured", ^{
            [pluginsImpl setupCrashReporter:pluginReporter];
            [[pluginReporter should] receive:@selector(reportErrorWithIdentifier:message:details:onFailure:)
                               withArguments:identifier,message, errorDetails, onFailure];
            
            [pluginsImpl reportErrorWithIdentifier:identifier
                                           message:message
                                           details:errorDetails
                                         onFailure:onFailure];
            [[resultError should] beNil];
        });
    });

    context(@"Handle plugin init finished", ^{
        it(@"Should proxy call to crashes", ^{
            [[[AMAAppMetricaCrashes crashes] should] receive:@selector(handlePluginInitFinished)];
            [pluginsImpl handlePluginInitFinished];
        });
    });
    
    it(@"Should conform to AMAAppMetricaPlugins", ^{
        [[pluginsImpl should] conformToProtocol:@protocol(AMAAppMetricaPlugins)];
    });
});

SPEC_END
