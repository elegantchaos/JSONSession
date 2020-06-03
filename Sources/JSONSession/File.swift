// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 03/06/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

extension DispatchTime {
    public func distance_shim(to other: DispatchTime) -> DispatchTimeInterval {
        let diff = other.uptimeNanoseconds - uptimeNanoseconds
        return .nanoseconds(Int(diff))
    }

    public func advanced_shim(by n: DispatchTimeInterval) -> DispatchTime {
        switch n {
        case .nanoseconds(let nanoseconds): return DispatchTime(uptimeNanoseconds: uptimeNanoseconds + UInt64(nanoseconds))
        case .microseconds(let micro): return DispatchTime(uptimeNanoseconds: uptimeNanoseconds + (UInt64(micro) * 1000))
        case .milliseconds(let milli): return DispatchTime(uptimeNanoseconds: uptimeNanoseconds + (UInt64(milli) * 1000000))
        case .seconds(let seconds): return DispatchTime(uptimeNanoseconds: uptimeNanoseconds + (UInt64(seconds) * 1000000000))
        default:
            return self
        }
    }

}

#if os(Linux)
extension DispatchTime {
    public func distance(to other: DispatchTime) -> DispatchTimeInterval { distance_shim(to: other) }
    public func advanced(by n: DispatchTimeInterval) -> DispatchTime { advanced_shim(by: n) }
}
extension DispatchTimeInterval: Equatable {
}
#endif
