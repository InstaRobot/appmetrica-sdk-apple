# macOS Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Добавить поддержку macOS в AppMetrica SDK, сохранив обратную совместимость с iOS и tvOS.

**Architecture:** Условная компиляция через `TARGET_OS_IPHONE` / `TARGET_OS_MAC` в Objective-C и `#if canImport(UIKit)` / `#if canImport(AppKit)` в Swift. Все UIKit-зависимости (~13 файлов) заменяются на кросс-платформенные абстракции или AppKit-аналоги. Модули, не имеющие macOS-смысла (Screenshot), компилируются как no-op.

**Tech Stack:** Swift 5.8+, Objective-C, SPM, macOS 11.0+ (Big Sur), AppKit, IOKit, CoreLocation, WebKit, AdSupport

---

## Карта UIKit-зависимостей

Все файлы с прямым `import UIKit` / `#import <UIKit/UIKit.h>` в `Sources/`:

| # | Файл | Что использует из UIKit | macOS-замена |
|---|------|------------------------|--------------|
| 1 | `AppMetricaHostState/Sources/AMAApplicationHostStateProvider.m` | `UIApplication*Notification` (DidBecomeActive, WillResignActive, WillTerminate) | `NSApplication` нотификации |
| 2 | `AppMetricaPlatform/Sources/AMADeviceDescription.m` | `UIDevice`, `UIScreen`, `userInterfaceIdiom` | `ProcessInfo`, `NSScreen`, `sysctl` |
| 3 | `AppMetricaPlatform/Sources/AMAJailbreakCheck.m` | `UIDevice.systemVersion`, iOS-файлы jailbreak | `return NO` на macOS |
| 4 | `AppMetricaCore/Sources/AMAAppOpenWatcher.m` | `UIApplicationDidFinishLaunchingNotification`, `UIApplicationLaunchOptionsURLKey` | `NSApplication.didFinishLaunchingNotification`, `NSAppleEventManager` |
| 5 | `AppMetricaCore/Sources/AMAStartupClientIdentifierFactory.m` | `UIDevice.identifierForVendor` | Абстракция через `IdentifierProvider` |
| 6 | `AppMetricaCore/Sources/Configuration/AMAMetricaPersistentConfiguration.m` | Только `#import <UIKit/UIKit.h>` (транзитивно) | Заменить на `Foundation` |
| 7 | `AppMetricaCore/Sources/Database/KeyValueStorage/DataProviders/AMABackingKVSDataProvider.h` | Только `#import <UIKit/UIKit.h>` (для NSObject) | Заменить на `Foundation` |
| 8 | `AppMetricaCore/Sources/Database/Trimming/AMAStorageTrimManager.m` | `UIApplicationDidReceiveMemoryWarningNotification` | `NSApplication.didBecomeActiveNotification` или пропуск |
| 9 | `AppMetricaScreenshot/Sources/AMAScreenshotWatcher.m` | `UIApplicationUserDidTakeScreenshotNotification` | no-op на macOS |
| 10 | `AppMetricaIDSync/Sources/Network/AMAIDSyncReportRequest.m` | `UIDevice.identifierForVendor` | Абстракция IFV |
| 11 | `AppMetricaIdentifiers/Sources/Generators/DeviceIDGenerator.swift` | `import UIKit` (для протокола) | `#if canImport(UIKit)` / `Foundation` |
| 12 | `AppMetricaIdentifiers/Sources/Generators/IdentifierForVendorGenerator.swift` | `UIDevice.current.identifierForVendor` | IOKit serial number hash |
| 13 | `AppMetricaIdentifiers/Sources/Public/IdentifierProvider.swift` | `import UIKit` (транзитивно) | `Foundation` |

---

## Task 1: Package.swift — добавить macOS платформу

**Files:**
- Modify: `Package.swift:126-129`

**Step 1: Добавить macOS в platforms**

В `Package.swift` строка 126-129, заменить:

```swift
platforms: [
    .iOS(.v13),
    .tvOS(.v13),
],
```

на:

```swift
platforms: [
    .iOS(.v13),
    .tvOS(.v13),
    .macOS(.v11),
],
```

**Step 2: Проверить сборку**

```bash
swift build 2>&1 | head -50
```

Expected: ошибки компиляции в файлах с UIKit — это нормально, именно их мы будем фиксить далее.

**Step 3: Commit**

```bash
git add Package.swift
git commit -m "feat: add macOS 11+ platform to Package.swift"
```

---

## Task 2: AppMetricaHostState — NSApplication нотификации для macOS

**Files:**
- Modify: `AppMetricaHostState/Sources/AMAApplicationHostStateProvider.m`

**Step 1: Добавить условную компиляцию для подписки на нотификации**

Заменить содержимое метода `subscribeToNotifications` и импорт:

```objc
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif
```

Метод `subscribeToNotifications`:

```objc
- (void)subscribeToNotifications
{
#if TARGET_OS_IPHONE
    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidBecomeActive)
                                    name:UIApplicationDidBecomeActiveNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillResignActive)
                                    name:UIApplicationWillResignActiveNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillTerminate)
                                    name:UIApplicationWillTerminateNotification
                                  object:nil];
#elif TARGET_OS_MAC
    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidBecomeActive)
                                    name:NSApplicationDidBecomeActiveNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillResignActive)
                                    name:NSApplicationWillResignActiveNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillTerminate)
                                    name:NSApplicationWillTerminateNotification
                                  object:nil];
#endif
}
```

**Step 2: Собрать модуль**

```bash
swift build --target AppMetricaHostState 2>&1 | tail -20
```

Expected: PASS

**Step 3: Прогнать тесты**

```bash
swift test --filter AppMetricaHostStateTests 2>&1 | tail -20
```

**Step 4: Commit**

```bash
git add AppMetricaHostState/
git commit -m "feat(HostState): add macOS NSApplication notification support"
```

---

## Task 3: AppMetricaPlatform/AMADeviceDescription — macOS-совместимая информация об устройстве

**Files:**
- Modify: `AppMetricaPlatform/Sources/AMADeviceDescription.m`

Это самый объёмный файл. Нужно заменить все UIKit-вызовы.

**Step 1: Заменить импорт**

```objc
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#import <IOKit/IOKitLib.h>
#endif
```

**Step 2: Заменить `appPlatform`**

```objc
+ (NSString *)appPlatform
{
#if TARGET_OS_IPHONE
    switch ([[UIDevice currentDevice] userInterfaceIdiom]) {
        case UIUserInterfaceIdiomPad:
            return @"ipad";
        default:
            return @"iphone";
    }
#else
    return @"mac";
#endif
}
```

**Step 3: Заменить `screenWidth`, `screenHeight`, `scalefactor`, `screenScale`**

```objc
+ (NSString *)screenWidth
{
#if TARGET_OS_IPHONE
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat width = CGRectGetWidth(bounds);
#else
    CGFloat width = 0;
    NSScreen *screen = [NSScreen mainScreen];
    if (screen != nil) {
        width = CGRectGetWidth(screen.frame);
    }
#endif
    return [NSString stringWithFormat:@"%.0f", width];
}

+ (NSString *)screenHeight
{
#if TARGET_OS_IPHONE
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat height = CGRectGetHeight(bounds);
#else
    CGFloat height = 0;
    NSScreen *screen = [NSScreen mainScreen];
    if (screen != nil) {
        height = CGRectGetHeight(screen.frame);
    }
#endif
    return [NSString stringWithFormat:@"%.0f", height];
}

+ (CGFloat)screenScale
{
#if TARGET_OS_IPHONE
    CGFloat screenScale = 1.0f;
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        screenScale = [[UIScreen mainScreen] scale];
    }
    return screenScale;
#else
    NSScreen *screen = [NSScreen mainScreen];
    return screen != nil ? screen.backingScaleFactor : 1.0;
#endif
}
```

**Step 4: Заменить `OSVersion`**

```objc
+ (NSString *)OSVersion
{
#if TARGET_OS_IPHONE
    return [[UIDevice currentDevice] systemVersion];
#else
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    return [NSString stringWithFormat:@"%ld.%ld.%ld",
            (long)version.majorVersion, (long)version.minorVersion, (long)version.patchVersion];
#endif
}
```

**Step 5: Заменить `isDeviceModelOfType:`**

```objc
+ (BOOL)isDeviceModelOfType:(NSString *)type
{
#if TARGET_OS_IPHONE
    NSString *model = [[[UIDevice currentDevice] model] lowercaseString];
    return ([model rangeOfString:[type lowercaseString]].location != NSNotFound);
#else
    NSString *model = [[self model] lowercaseString];
    return ([model rangeOfString:[type lowercaseString]].location != NSNotFound);
#endif
}
```

**Step 6: Обновить `screenDPI` — macOS ветка**

```objc
+ (NSString *)screenDPI
{
#if TARGET_OS_TV
    return nil;
#elif TARGET_OS_IPHONE
    // ... существующий код с таблицей DPI ...
#else
    // macOS: DPI ≈ 72 * backingScaleFactor для стандартных дисплеев, 110 для Retina
    CGFloat scale = [self screenScale];
    NSUInteger dpi = (NSUInteger)(72.0 * scale);
    return [NSString stringWithFormat:@"%lu", (unsigned long)dpi];
#endif
}
```

> **Важно:** Существующая таблица DPI и код для iOS должны остаться внутри `#elif TARGET_OS_IPHONE` блока без изменений.

**Step 7: Добавить линковку IOKit для macOS в Package.swift (если нужно для идентификаторов)**

В `Package.swift`, target `.platform`, добавить `linkerSettings` для macOS:

```swift
.target(target: .platform, dependencies: [.log, .coreUtils]),
```

→ Если IOKit не используется непосредственно в Platform модуле, этот шаг пропустить. IOKit понадобится в `AppMetricaIdentifiers`.

**Step 8: Собрать**

```bash
swift build --target AppMetricaPlatform 2>&1 | tail -20
```

**Step 9: Commit**

```bash
git add AppMetricaPlatform/
git commit -m "feat(Platform): macOS device description via AppKit/ProcessInfo/NSScreen"
```

---

## Task 4: AppMetricaPlatform/AMAJailbreakCheck — отключить на macOS

**Files:**
- Modify: `AppMetricaPlatform/Sources/AMAJailbreakCheck.m`

**Step 1: Обернуть весь iOS-код**

В начале файла после `#import "AMAJailbreakCheck.h"`:

```objc
#if TARGET_OS_IPHONE
// ... весь существующий код ...
#else

@implementation AMAJailbreakCheck

+ (AMA_KFJailbroken)jailbroken
{
    return AMA_KFNotJailbroken;
}

@end

#endif
```

**Step 2: Собрать**

```bash
swift build --target AppMetricaPlatform 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add AppMetricaPlatform/
git commit -m "feat(Platform): disable jailbreak check on macOS"
```

---

## Task 5: AppMetricaPlatform/AMAPlatformDescription — deviceType и OSName для macOS

**Files:**
- Modify: `AppMetricaPlatform/Sources/AMAPlatformDescription.m`

**Step 1: Добавить device type для macOS**

В начале файла добавить:

```objc
NSString *const kAMADeviceTypeDesktop = @"desktop";
```

Заменить метод `deviceType`:

```objc
+ (NSString *)deviceType
{
#if TARGET_OS_TV
    return kAMADeviceTypeTV;
#elif TARGET_OS_WATCH
    return kAMADeviceTypeWatch;
#elif TARGET_OS_IPHONE
    return [AMADeviceDescription isDeviceModelOfType:@"ipad"] ? kAMADeviceTypeTablet : kAMADeviceTypePhone;
#else
    return kAMADeviceTypeDesktop;
#endif
}
```

**Step 2: Обновить OSName**

```objc
+ (NSString *)OSName
{
#if TARGET_OS_IPHONE || TARGET_OS_TV || TARGET_OS_WATCH
    return @"iOS";
#else
    return @"macOS";
#endif
}
```

> **Заметка:** Сервер AppMetrica может ожидать конкретные значения `OSName` и `deviceType`. Необходимо уточнить у серверной команды, какие значения допустимы. `"macOS"` и `"desktop"` — предположение; возможно потребуется `"osx"` или `"mac"`.

**Step 3: Commit**

```bash
git add AppMetricaPlatform/
git commit -m "feat(Platform): add macOS device type and OS name"
```

---

## Task 6: AppMetricaIdentifiers — macOS-совместимая генерация Device ID

**Files:**
- Modify: `AppMetricaIdentifiers/Sources/Generators/DeviceIDGenerator.swift`
- Modify: `AppMetricaIdentifiers/Sources/Generators/IdentifierForVendorGenerator.swift`
- Modify: `AppMetricaIdentifiers/Sources/Public/IdentifierProvider.swift`

**Step 1: Убрать UIKit из DeviceIDGenerator.swift**

```swift
import Foundation

protocol DeviceIDGenerator {
    func generateDeviceID() -> DeviceID?
}
```

**Step 2: Заменить IdentifierForVendorGenerator.swift — кроссплатформенный**

```swift
#if canImport(UIKit)
import UIKit
#endif

#if canImport(IOKit)
import IOKit
#endif

final class IdentifierForVendorGenerator: DeviceIDGenerator {
    
    func generateDeviceID() -> DeviceID? {
        let uuid = platformVendorIdentifier()
        return uuid.flatMap { DeviceID(nonEmptyString: $0) }
    }
    
    private func platformVendorIdentifier() -> String? {
        #if canImport(UIKit) && !os(macOS)
        return UIDevice.current.identifierForVendor?.uuidString
        #elseif os(macOS)
        return macOSHardwareUUID()
        #else
        return nil
        #endif
    }
    
    #if os(macOS)
    private func macOSHardwareUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }
        
        let uuidCF = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )
        return uuidCF?.takeRetainedValue() as? String
    }
    #endif
}
```

**Step 3: Убрать UIKit из IdentifierProvider.swift**

Заменить `import UIKit` на:

```swift
import Foundation
```

> UIKit здесь не использовался по существу — только транзитивный импорт.

**Step 4: Добавить линковку IOKit в Package.swift**

В `Package.swift`, модифицировать target `.identifiers`:

```swift
// Нужно использовать нативный Target API вместо хелпера, чтобы добавить linkerSettings.
// Альтернативно — расширить хелпер .target() для поддержки linkerSettings.
```

Добавить в расширение `Target` поддержку `linkerSettings`, или напрямую добавить IOKit линковку в `IdentifierForVendorGenerator.swift` через `#if canImport(IOKit)` (IOKit доступен по умолчанию на macOS, линковка автоматическая для фреймворков Apple при использовании `import IOKit`).

**Step 5: Собрать**

```bash
swift build --target AppMetricaIdentifiers 2>&1 | tail -20
```

**Step 6: Commit**

```bash
git add AppMetricaIdentifiers/
git commit -m "feat(Identifiers): macOS device ID via IOKit hardware UUID"
```

---

## Task 7: AppMetricaCore — кроссплатформенные исправления (5 файлов)

**Files:**
- Modify: `AppMetricaCore/Sources/AMAAppOpenWatcher.m`
- Modify: `AppMetricaCore/Sources/AMAStartupClientIdentifierFactory.m`
- Modify: `AppMetricaCore/Sources/Configuration/AMAMetricaPersistentConfiguration.m`
- Modify: `AppMetricaCore/Sources/Database/KeyValueStorage/DataProviders/AMABackingKVSDataProvider.h`
- Modify: `AppMetricaCore/Sources/Database/Trimming/AMAStorageTrimManager.m`

### 7a: AMAAppOpenWatcher.m

**Step 1: Заменить UIKit импорт и нотификации**

```objc
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif
```

Метод `startWatchingWithDeeplinkController:`:

```objc
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
#endif
}
```

Метод `extractDeeplink:` — deep link extraction:

```objc
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
#else
    // На macOS deep links обрабатываются через NSAppleEventManager, 
    // а не через launch options. Возвращаем nil из userInfo.
    // Обработка URL-событий на macOS должна быть реализована отдельно 
    // через NSApplicationDelegate.application(_:open:).
#endif
    return openUrl;
}
```

### 7b: AMAStartupClientIdentifierFactory.m

**Step 1: Заменить прямое обращение к UIDevice.identifierForVendor**

```objc
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
```

В методе `startupClientIdentifier`:

```objc
+ (AMAStartupClientIdentifier *)startupClientIdentifier
{
    AMAStartupClientIdentifier *identifier = [[AMAStartupClientIdentifier alloc] init];
    identifier.deviceID = [AMAMetricaConfiguration sharedInstance].persistent.deviceID;
    identifier.deviceIDHash = [AMAMetricaConfiguration sharedInstance].persistent.deviceIDHash;
    identifier.UUID = [AMAMetricaConfiguration sharedInstance].identifierProvider.appMetricaUUID;
#if TARGET_OS_IPHONE
    identifier.IFV = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
#else
    identifier.IFV = [AMAMetricaConfiguration sharedInstance].identifierProvider.deviceID;
#endif
    return identifier;
}
```

> **Заметка:** На macOS `identifierForVendor` отсутствует. Используем `deviceID` из `IdentifierProvider` (который на macOS генерится через IOKit hardware UUID). Альтернатива — отправлять nil для IFV.

### 7c: AMAMetricaPersistentConfiguration.m

**Step 1: Заменить импорт**

```objc
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
```

> UIKit здесь не используется напрямую — импорт был для транзитивных зависимостей. Foundation достаточно.

### 7d: AMABackingKVSDataProvider.h

**Step 1: Заменить импорт**

```objc
#import <Foundation/Foundation.h>
```

> UIKit не использовался — `NSObject`, `NSSet`, `NSString`, `NSArray` — всё из Foundation.

### 7e: AMAStorageTrimManager.m

**Step 1: Заменить memory warning нотификацию**

```objc
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif
```

В методе `subscribeDatabaseToMemoryWarningTrim:`:

```objc
- (void)subscribeDatabaseToMemoryWarningTrim:(id<AMADatabaseProtocol>)database
{
    AMAStorageEventsTrimTransaction *transaction =
        [[AMAStorageEventsTrimTransaction alloc] initWithCleaner:self.eventsCleaner];
    AMAPlainStorageTrimmer *trimmer = [[AMAPlainStorageTrimmer alloc] initWithTrimTransaction:transaction];
    __weak __typeof(database) weakDatabase = database;
#if TARGET_OS_IPHONE
    NSNotificationName notificationName = UIApplicationDidReceiveMemoryWarningNotification;
#else
    // macOS не имеет memory warning нотификации.
    // Используем NSApplication.didBecomeActiveNotification как триггер для проверки/тримминга.
    // Альтернатива: dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, ...)
    NSNotificationName notificationName = NSApplicationDidBecomeActiveNotification;
#endif
    [self.listener subscribeObject:database
                    toNotification:notificationName
                      withCallback:^(NSNotification *notification) {
        [trimmer trimDatabase:weakDatabase];
    }];
}
```

> **Заметка:** Более корректный подход для macOS — `dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, ...)`. Но для MVP `didBecomeActive` достаточен — триммит реже, но работает. Можно улучшить позже.

**Step 2: Собрать весь Core**

```bash
swift build --target AppMetricaCore 2>&1 | tail -30
```

**Step 3: Commit**

```bash
git add AppMetricaCore/
git commit -m "feat(Core): macOS-compatible notifications, IFV, storage trimming"
```

---

## Task 8: AppMetricaScreenshot — no-op на macOS

**Files:**
- Modify: `AppMetricaScreenshot/Sources/AMAScreenshotWatcher.m`

**Step 1: Обернуть реализацию в TARGET_OS_IPHONE**

```objc
#import "AMAScreenshotWatcher.h"
#import <AppMetricaCore/AppMetricaCore.h>
#import "AMAScreenshotReporting.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

@interface AMAScreenshotWatcher ()

@property (nonatomic, strong, nonnull, readonly) id<AMAScreenshotReporting> reporter;
@property (nonatomic, strong, nonnull, readonly) NSNotificationCenter *notificationCenter;

@end

@implementation AMAScreenshotWatcher

@synthesize isStarted = _isStarted;

- (instancetype)initWithReporter:(id<AMAScreenshotReporting>)reporter
{
    return [self initWithReporter:reporter notificationCenter:[NSNotificationCenter defaultCenter]];
}

- (instancetype)initWithReporter:(id<AMAScreenshotReporting>)reporter
              notificationCenter:(NSNotificationCenter *)notificationCenter
{
    self = [super init];
    if (self) {
        _reporter = reporter;
        _notificationCenter = notificationCenter;
    }
    return self;
}

- (void)dealloc
{
    [self.notificationCenter removeObserver:self];
}

- (void)setIsStarted:(BOOL)isStarted
{
    @synchronized (self) {
        if (_isStarted == isStarted) {
            return;
        }
        
#if TARGET_OS_IPHONE
        if (isStarted) {
            [self.notificationCenter addObserver:self
                                        selector:@selector(handleNotification:)
                                            name:UIApplicationUserDidTakeScreenshotNotification
                                          object:nil];
        } else {
            [self.notificationCenter removeObserver:self];
        }
#endif
        
        _isStarted = isStarted;
    }
}

- (BOOL)isStarted
{
    @synchronized (self) {
        return _isStarted;
    }
}

- (void)handleNotification:(NSNotification*)notification
{
    [self.reporter reportScreenshot];
}

@end
```

**Step 2: Собрать**

```bash
swift build --target AppMetricaScreenshot 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add AppMetricaScreenshot/
git commit -m "feat(Screenshot): no-op on macOS (no screenshot notification)"
```

---

## Task 9: AppMetricaIDSync — убрать прямую зависимость от UIDevice

**Files:**
- Modify: `AppMetricaIDSync/Sources/Network/AMAIDSyncReportRequest.m`

**Step 1: Заменить UIDevice.identifierForVendor**

```objc
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
```

В методе `GETParameters`:

```objc
- (NSDictionary *)GETParameters
{
    NSMutableDictionary *parameters = [[super GETParameters] mutableCopy];

#if TARGET_OS_IPHONE
    NSString *ifv = [UIDevice currentDevice].identifierForVendor.UUIDString;
#else
    NSString *ifv = [AMAAppMetrica deviceID];
#endif
    NSString *deviceID = [AMAAppMetrica deviceID];
    NSString *uuid = [AMAAppMetrica UUID];

    if (ifv != nil) parameters[kAMAIFVParamKey] = ifv;
    if (deviceID != nil) parameters[kAMADeviceIDParamKey] = deviceID;
    if (uuid != nil) parameters[kAMAUUIDParamKey] = uuid;

    return parameters;
}
```

**Step 2: Собрать**

```bash
swift build --target AppMetricaIDSync 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add AppMetricaIDSync/
git commit -m "feat(IDSync): macOS-compatible IFV parameter"
```

---

## Task 10: AppMetricaLog — ASL на macOS

**Files:**
- Verify: `AppMetricaLog/Sources/AMAASLLogMiddleware.m`

Этот файл уже имеет `#if !TARGET_OS_TV` / `#if TARGET_OS_TV` разделение. ASL доступен на macOS, поэтому:

**Step 1: Проверить компиляцию**

```bash
swift build --target AppMetricaLog 2>&1 | tail -20
```

Expected: PASS без изменений (ASL API доступен на macOS).

Если есть ошибки — нужно добавить `#if !TARGET_OS_TV && TARGET_OS_IPHONE` → `#if !TARGET_OS_TV` (оставить как есть — macOS попадает в "не TV" ветку, что корректно).

---

## Task 11: Полная сборка и smoke test

**Step 1: Собрать всё**

```bash
swift build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED

**Step 2: Собрать тесты**

```bash
swift build --build-tests 2>&1 | tail -30
```

Если тесты используют UIKit-специфичные API (Kiwi-тесты с `UIApplication` в тестах Core), они могут не скомпилироваться на macOS. Это ОК для MVP — тесты запускаются на iOS-симуляторе, а на macOS нужно будет адаптировать отдельно.

**Step 3: Xcodebuild macOS**

```bash
xcodebuild build \
    -scheme "AppMetrica-Package" \
    -destination "platform=macOS" \
    2>&1 | tail -30
```

Expected: BUILD SUCCEEDED

**Step 4: Commit (если были мелкие фиксы)**

```bash
git add -A
git commit -m "fix: resolve remaining macOS build issues"
```

---

## Task 12: CI — добавить macOS build job

**Files:**
- Modify: `.github/workflows/objective-c-xcode.yml`

**Step 1: Добавить macOS job**

Добавить в workflow рядом с существующим iOS job:

```yaml
  build-macos:
    name: macOS Build
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build for macOS
        run: |
          xcodebuild build \
            -scheme "AppMetrica-Package" \
            -destination "platform=macOS" \
            | xcpretty
```

> **Заметка:** Тесты на macOS пока не запускаем (Kiwi + UIKit-моки нужно адаптировать). Только сборка.

**Step 2: Commit**

```bash
git add .github/
git commit -m "ci: add macOS build verification job"
```

---

## Task 13: CocoaPods (опционально, не блокирует)

**Files:**
- Modify: `AppMetricaCore.podspec`
- Modify: `AppMetricaHostState.podspec`
- Modify: `AppMetricaPlatform.podspec`
- Modify: `AppMetricaIdentifiers.podspec`
- Modify: Все остальные `.podspec` файлы

**Step 1: Добавить `osx.deployment_target` в каждый podspec**

Пример для `AppMetricaCore.podspec`:

```ruby
s.ios.deployment_target = '13.0'
s.tvos.deployment_target = '13.0'
s.osx.deployment_target = '11.0'
```

Для подспеков с `s.frameworks = 'UIKit'`:

```ruby
s.ios.frameworks = 'UIKit'
s.tvos.frameworks = 'UIKit'
s.osx.frameworks = 'AppKit'
```

Для `AppMetricaIdentifiers.podspec`:

```ruby
s.osx.frameworks = 'IOKit'
```

**Step 2: Проверить**

```bash
pod lib lint AppMetricaCore.podspec --platforms=osx 2>&1 | tail -30
```

**Step 3: Commit**

```bash
git add *.podspec
git commit -m "feat(podspec): add macOS deployment target to all podspecs"
```

---

## Порядок зависимостей при реализации

```
Task 1 (Package.swift)
  ├── Task 2 (HostState) — нет зависимостей от других задач
  ├── Task 3 (DeviceDescription) — нет зависимостей
  ├── Task 4 (JailbreakCheck) — нет зависимостей
  ├── Task 5 (PlatformDescription) — зависит от Task 3
  ├── Task 6 (Identifiers) — нет зависимостей
  ├── Task 8 (Screenshot) — нет зависимостей
  ├── Task 9 (IDSync) — нет зависимостей
  └── Task 7 (Core — 5 файлов) — зависит от Task 2, 3, 5, 6
       └── Task 10 (Log — только проверка)
            └── Task 11 (Full build)
                 ├── Task 12 (CI)
                 └── Task 13 (CocoaPods)
```

**Tasks 2, 3, 4, 6, 8, 9 можно делать параллельно** после Task 1.

---

## Известные риски и open questions

1. **Серверные значения OSName / deviceType** — нужно уточнить, какие строки принимает бэкенд AppMetrica (`"macOS"` vs `"osx"`, `"desktop"` vs `"mac"`). Неправильные значения могут привести к отбрасыванию данных.

2. **IFV на macOS** — IOKit hardware UUID уникален для машины, а не для вендора. Это отличается от `identifierForVendor` на iOS (сбрасывается при удалении всех приложений вендора). Для macOS это приемлемо, но стоит задокументировать.

3. **Deep links на macOS** — `NSApplicationDelegate.application(_:open:)` работает иначе, чем `UIApplicationLaunchOptionsURLKey`. Для MVP deep links на macOS будут не функциональны (nil). Полная поддержка потребует регистрации `NSAppleEventManager` обработчика.

4. **Memory pressure на macOS** — использование `didBecomeActive` для тримминга — компромисс. Для продакшена стоит реализовать `DISPATCH_SOURCE_TYPE_MEMORYPRESSURE`.

5. **Тесты** — Kiwi-тесты используют UIKit-моки (`UIApplication`, `UIDevice`). Для полноценного тестирования на macOS потребуется:
   - Создание AppKit-моков
   - Или запуск тестов только на iOS-симуляторе (текущее поведение)

6. **KSCrash на macOS** — KSCrash 2.x поддерживает macOS, но нужно проверить, что версия `2.5.x` корректно линкуется.

7. **AdServices на macOS** — `AAAttribution.attributionToken()` доступен на macOS 12+, а minimum deployment у нас macOS 11. Нужен `@available(macOS 12.0, *)` guard (вероятно уже есть через `__IPHONE_OS_VERSION_MAX_ALLOWED`, но нужно проверить).
