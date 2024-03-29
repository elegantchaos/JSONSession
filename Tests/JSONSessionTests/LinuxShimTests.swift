// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 03/06/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import DataFetcher
import XCTest

@testable import JSONSession

final class LinuxShimTests: XCTestCase {
    func testAdvanced() {
        let t1 = DispatchTime(uptimeNanoseconds: 0)
        let t2 = t1.advanced_shim(by: .seconds(1))
        XCTAssertEqual(t2.uptimeNanoseconds, 1_000_000_000)
    }

    func testDistance() {
        let t1 = DispatchTime(uptimeNanoseconds: 0)
        let t2 = DispatchTime(uptimeNanoseconds: 1_000_000_000)
        let d = t1.distance_shim(to: t2)
        XCTAssertEqual(d, .seconds(1))
    }
}
