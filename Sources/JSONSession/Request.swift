// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 05/08/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct Request {
    public let resource: ResourceResolver
    let processors: ProcessorGroup
    var tag: String?
    var repeating: Bool
    var interval: TimeInterval

    var repeatTime: DispatchTime? {
        repeating ? DispatchTime.now().advanced(by: interval.asDispatchTimeInterval) : nil
    }

    mutating func updateRepeat(status: RepeatStatus) {
        switch status {
            case .request: repeating = true
            case .cancel: repeating = false
            case .inherited: break
        }
    }

    mutating func capInterval(to seconds: Double) {
        let current = interval
        let interval = max(current, seconds)
        if interval != current {
            networkingChannel.log("capped repeat interval of \(current) to X-Poll-Interval \(interval)")
        }
    }

    func urlRequest(for session: Session) -> URLRequest {
        let authorization = "bearer \(session.token)"
        let path = processors.path(for: resource, in: session)
        var request = URLRequest(url: session.base.appendingPathComponent(path))
        request.addValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData

        if let tag = tag {
            request.addValue(tag, forHTTPHeaderField: "If-None-Match")
        }

        sessionChannel.log("Requesting \(processors.name) for \(resource) (\(request))")
        return request
    }

    func log(deadline: DispatchTime) {
        let distance = DispatchTime.now().distance(to: deadline).asTimeInterval
        let timeInfo = distance < 0 ? "now." : "in \(seconds: distance)."
        let repeatInfo = repeating ? " Will repeat in \(seconds: interval)." : ""
        sessionChannel.log("Polling for \(processors.name) \(timeInfo)\(repeatInfo)")
    }

    func log(error: Error, data: Data) {
        sessionChannel.log("Error thrown:\n- query: \(processors.name)\n- target: \(resource)\n- processor: \(processors.name)\n- error: \(error)\n")
        sessionChannel.log("- data: \(data.prettyPrinted)\n\n")
    }

    func log(response: URLResponse?) {
        if let _ = response {
            networkingChannel.log("got response for \(resource)")
        }
    }
}
