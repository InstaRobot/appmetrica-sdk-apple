
import Foundation
import XCTest
@testable import AppMetricaIdentifiers

#if canImport(UIKit)
import UIKit
#endif
#if canImport(IOKit)
import IOKit
#endif

final class UIDeviceGeneratorTests: XCTestCase {
    
    var generator: IdentifierForVendorGenerator!
    
    override func setUp() {
        super.setUp()
        
        generator = IdentifierForVendorGenerator()
    }
    
    func testIdentifierForVendor() {
        #if os(iOS) || os(tvOS)
        XCTAssertEqual(generator.generateDeviceID()?.rawValue, UIDevice.current.identifierForVendor?.uuidString)
        #elseif os(macOS)
        let deviceID = generator.generateDeviceID()
        XCTAssertNotNil(deviceID, "macOS hardware UUID should be available")
        if let raw = deviceID?.rawValue {
            XCTAssertFalse(raw.isEmpty)
            XCTAssertNotNil(UUID(uuidString: raw), "Should be a valid UUID string")
        }
        #endif
    }
    
}
