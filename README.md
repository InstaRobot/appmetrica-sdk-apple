# [AppMetrica SDK](https://appmetrica.io) — Apple Platforms

[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen?style=for-the-badge)](https://github.com/InstaRobot/appmetrica-sdk-apple)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2013%2B%20%7C%20tvOS%2013%2B%20%7C%20macOS%2011%2B-blue?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

Community fork of [appmetrica/appmetrica-sdk-ios](https://github.com/appmetrica/appmetrica-sdk-ios) with **macOS support** and SPM-only distribution.

## Differences from the Original SDK

| Feature | Original SDK | This Fork |
|---|---|---|
| **macOS support** | iOS & tvOS only | iOS 13+, tvOS 13+, **macOS 11+** |
| **Package manager** | SPM + CocoaPods | SPM only (CocoaPods removed) |
| **Repository name** | `appmetrica-sdk-ios` | `appmetrica-sdk-apple` |
| **Device ID (macOS)** | N/A | IOKit hardware UUID |
| **Deep links (macOS)** | N/A | `NSAppleEventManager` (`kAEGetURL`) |
| **Memory pressure (macOS)** | N/A | `DISPATCH_SOURCE_TYPE_MEMORYPRESSURE` |
| **Lifecycle (macOS)** | N/A | `NSApplication` notifications |
| **AdServices (macOS)** | N/A | `@available(macOS 11.1, *)` guard |
| **Encryption (macOS)** | `SecKeyEncrypt`/`SecKeyDecrypt` | `SecKeyCreateEncryptedData`/`SecKeyCreateDecryptedData` |
| **Screenshot tracking** | UIKit notification | No-op on macOS (no system equivalent) |
| **Jailbreak detection** | Active checks | Disabled on macOS (always returns not-rooted) |

## Installation

### Swift Package Manager

#### Through Xcode:

1. Go to **File** > **Add Package Dependency**.
2. Put the GitHub link: https://github.com/InstaRobot/appmetrica-sdk-apple.
3. In **Add to Target**, select **None** for modules you don't want.

#### Via Package.swift Manifest:

1. Add the SDK to your project's dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/InstaRobot/appmetrica-sdk-apple", from: "6.0.0")
],
```

2. List the modules in your target's dependencies:

```swift
.target(
    name: "YourTargetName",
    dependencies: [
        // For all analytics features, add this umbrella module:
        .product(name: "AppMetricaAnalytics", package: "appmetrica-sdk-apple"),

        // Or add specific modules:
        // .product(name: "AppMetricaCore", package: "appmetrica-sdk-apple"),
        // .product(name: "AppMetricaCrashes", package: "appmetrica-sdk-apple"),
        // .product(name: "AppMetricaAdSupport", package: "appmetrica-sdk-apple"),
    ]
)
```

### Optional

#### Children's Apps:

To meet Apple's App Store rules regarding children's privacy (like COPPA), add AppMetrica but leave out the `AppMetricaAdSupport` module. Don't include `AppMetricaAdSupport` — either choose **None** for this module when selecting packages in Xcode or specify dependencies in `Package.swift`.

### Modules Overview

- `AppMetricaAnalytics`: Umbrella module that includes all analytics features (Core, Crashes, AdSupport, WebKit, etc).
- `AppMetricaCore`: Required for basic SDK use.
- `AppMetricaCrashes`: Enables crash reports.
- `AppMetricaWebKit`: Used for handling events from WebKit.
- `AppMetricaAdSupport`: Needed for IDFA collection, don't include for children's apps.
- `AppMetricaScreenshot`: Allows AppMetrica SDK to collect screenshot taken events (iOS/tvOS only).
- `AppMetricaIDSync`: Enhances integration capabilities and improves overall system performance in cross-platform environments.

## Integration Quickstart

Here's how to add AppMetrica to your project:

1. `import AppMetricaCore` in your app delegate.
2. Initialize AppMetrica with your API key at launch.

### For UIKit (iOS/tvOS):

```swift
import AppMetricaCore

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    if let configuration = AppMetricaConfiguration(apiKey: "Your_API_Key") {
        AppMetrica.activate(with: configuration)
    }
    return true
}
```

### For SwiftUI (iOS/tvOS):

```swift
import UIKit
import AppMetricaCore

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if let configuration = AppMetricaConfiguration(apiKey: "Your_API_Key") {
            AppMetrica.activate(with: configuration)
        }
        return true
    }
}

@main
struct YourAppNameApp: App {
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### For macOS (AppKit):

```swift
import Cocoa
import AppMetricaCore

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let configuration = AppMetricaConfiguration(apiKey: "Your_API_Key") {
            AppMetrica.activate(with: configuration)
        }
    }
}

@main
struct YourAppNameApp: App {
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### For macOS (Storyboard-based):

In your `AppDelegate.swift`:

```swift
import Cocoa
import AppMetricaCore

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let configuration = AppMetricaConfiguration(apiKey: "Your_API_Key") {
            AppMetrica.activate(with: configuration)
        }
    }
}
```

**Note:** Replace `"Your_API_Key"` with your actual AppMetrica API key, which is a unique identifier for your application provided in the [AppMetrica web interface](https://appmetrica.io/application/new) under **Settings**.

## Advanced Configuration

### Configure Sending of Events, Profile Attributes, and Revenue

- **Sending Custom Events**: To capture and analyze user actions within your app, you should configure the sending of custom events. For more information, see [Events](https://appmetrica.io/docs/en/data-collection/about-events).

- **User Profiles**: To gather insights into your user base, set up the sending of profile attributes. This allows for a richer analysis of user behavior segmented by custom attributes. Remember, a profile attribute can hold only one value, and sending a new value for an attribute will overwrite the existing one. For more information, see [User profile](https://appmetrica.io/docs/en/data-collection/about-profiles).

- **In-App Purchases (Revenue Tracking)**: To monitor in-app purchases effectively, configure the sending of revenue events. This feature enables you to comprehensively track transactions within your application. For setup details, see [In-app purchases](https://appmetrica.io/docs/en/data-collection/about-revenue).

## Testing the SDK integration

Before you move on to testing, it's advisable to isolate your test data from actual app statistics. Consider using a separate API key for test data by [sending statistics to an additional API key](https://appmetrica.io/docs/en/sdk/ios/analytics/ios-operations#reporter) or adding another app instance with a new API key in the AppMetrica interface.

### Steps to Test the Library's Operation:

1. **Launch the App**: Start your application integrated with the AppMetrica SDK and interact with it for a while to generate test data.

2. **Internet Connection**: Ensure that the device running the app is connected to the internet to allow data transmission to AppMetrica.

3. **Verify data in the AppMetrica Interface**: Log into the AppMetrica interface and confirm the following:
   - A new user has appeared in the [Audience](https://appmetrica.io/docs/en/mobile-reports/audience-report) report, indicating successful user tracking.
   - An increase in the number of sessions is visible in the **Engagement → Sessions** report, showing active app usage.
   - Custom events and profile attributes you've set up are reflected in the [Events](https://appmetrica.io/docs/en/mobile-reports/events-report) and [Profiles](https://appmetrica.io/docs/en/mobile-reports/profile-report) reports, which means that event tracking and user profiling are working as intended.

If you encounter any issues, please consult the [troubleshooting section](https://appmetrica.io/docs/en/sdk/ios/analytics/quick-start#step-4-test-the-library-operation).

## Documentation

You can find comprehensive integration details and instructions for installation, configuration, testing, and more in our [full documentation](https://appmetrica.io/docs/).

## License

AppMetrica is released under the MIT License.
License agreement is available at [LICENSE](LICENSE).
