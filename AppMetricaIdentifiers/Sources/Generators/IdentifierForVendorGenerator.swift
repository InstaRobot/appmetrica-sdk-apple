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
        #if os(iOS) || os(tvOS)
        return UIDevice.current.identifierForVendor?.uuidString
        #elseif os(macOS)
        return macOSHardwareUUID()
        #else
        return nil
        #endif
    }
    
    #if os(macOS)
    private func macOSHardwareUUID() -> String? {
        let port: mach_port_t
        if #available(macOS 12.0, *) {
            port = kIOMainPortDefault
        } else {
            port = kIOMasterPortDefault
        }
        let platformExpert = IOServiceGetMatchingService(
            port,
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
