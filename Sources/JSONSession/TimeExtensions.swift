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
        .nanoseconds(Int(self * 1_000_000_000.0))
    }
}

extension DispatchTimeInterval {
    var asTimeInterval: TimeInterval {
        switch self {
            case let .seconds(value):
                return TimeInterval(value)
            case let .milliseconds(value):
                return TimeInterval(value) * 0.001
            case let .microseconds(value):
                return TimeInterval(value) * 0.000001
            case let .nanoseconds(value):
                return TimeInterval(value) * 0.000000001

            case .never:
                return .infinity

            @unknown default:
                return .infinity
        }
    }
}

public extension DispatchTime {
    func distance_shim(to other: DispatchTime) -> DispatchTimeInterval {
        let diff = Int(other.uptimeNanoseconds) - Int(uptimeNanoseconds)
        return .nanoseconds(Int(diff))
    }

    func advanced_shim(by n: DispatchTimeInterval) -> DispatchTime {
        switch n {
            case let .nanoseconds(nanoseconds): return DispatchTime(uptimeNanoseconds: uptimeNanoseconds + UInt64(nanoseconds))
            case let .microseconds(micro): return DispatchTime(uptimeNanoseconds: uptimeNanoseconds + (UInt64(micro) * 1000))
            case let .milliseconds(milli): return DispatchTime(uptimeNanoseconds: uptimeNanoseconds + (UInt64(milli) * 1_000_000))
            case let .seconds(seconds): return DispatchTime(uptimeNanoseconds: uptimeNanoseconds + (UInt64(seconds) * 1_000_000_000))
            default:
                return self
        }
    }
}

#if os(Linux)
public extension DispatchTime {
    func distance(to other: DispatchTime) -> DispatchTimeInterval { distance_shim(to: other) }
    func advanced(by n: DispatchTimeInterval) -> DispatchTime { advanced_shim(by: n) }
}

extension DispatchTimeInterval: Equatable {}
#endif
