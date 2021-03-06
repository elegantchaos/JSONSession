// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 03/06/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

extension String.StringInterpolation {
    mutating func appendInterpolation(seconds: TimeInterval) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 2
        if let result = formatter.string(from: seconds as NSNumber) {
            appendLiteral("\(result) seconds")
        }
    }
}

extension TimeInterval {
    var asDispatchTimeInterval: DispatchTimeInterval {
        return .nanoseconds(Int(self * 1000000000.0))
    }
}

extension DispatchTimeInterval {
    var asTimeInterval: TimeInterval {
        switch self {
        case .seconds(let value):
            return TimeInterval(value)
        case .milliseconds(let value):
            return TimeInterval(value)*0.001
        case .microseconds(let value):
            return TimeInterval(value)*0.000001
        case .nanoseconds(let value):
            return TimeInterval(value)*0.000000001

        case .never:
            return .infinity
            
        @unknown default:
            return .infinity
        }
    }
}

extension DispatchTime {
    public func distance_shim(to other: DispatchTime) -> DispatchTimeInterval {
        let diff = Int(other.uptimeNanoseconds) - Int(uptimeNanoseconds)
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
