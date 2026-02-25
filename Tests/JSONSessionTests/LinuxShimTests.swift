import Foundation
import Testing

@testable import JSONSession

@Suite("Linux shim helpers")
struct LinuxShimTests {
  @Test
  func advanced() {
    let t1 = DispatchTime(uptimeNanoseconds: 0)
    let t2 = t1.advanced_shim(by: .seconds(1))
    #expect(t2.uptimeNanoseconds == 1_000_000_000)
  }

  @Test
  func distance() {
    let t1 = DispatchTime(uptimeNanoseconds: 0)
    let t2 = DispatchTime(uptimeNanoseconds: 1_000_000_000)
    let d = t1.distance_shim(to: t2)
    #expect(d == .seconds(1))
  }
}
