// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 27/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Logger

public let sessionChannel = Channel("com.elegantchaos.jsonsession.session")

public enum ResponseState {
    case updated
    case unchanged
    case error
    case other
}

open class Session {
    public let session = URLSession.shared
    public let target: Target
    public let context: Context
    public let defaultInterval: Int
    
    var tasks: [URLSessionDataTask] = []
    
    public init(repo: Target, context: Context, defaultInterval: Int = 60) {
        self.target = repo
        self.context = context
        self.defaultInterval = defaultInterval
    }
    
    
    public func schedule(processors: ProcessorGroup, for deadline: DispatchTime, tag: String? = nil, repeatingEvery: Int? = nil) {
        let query = processors.query(for: self)
        let distance = deadline.distance(to: DispatchTime.now())
        sessionChannel.log("Scheduled \(query.name) in \(distance)")
        DispatchQueue.global(qos: .background).asyncAfter(deadline: deadline) {
            self.sendRequest(query: query, processors: processors, repeatingEvery: repeatingEvery)
        }
    }
        
    enum Errors: Error {
        case badResponse
        case missingData
        case apiError(Failure)
        case unexpectedResponse(Int)
    }
    
    func sendRequest(query: Query, processors: ProcessorGroup, tag: String? = nil, repeatingEvery: Int? = nil) {
        var request = query.request(with: context, repo: target)
        if let tag = tag {
            request.addValue(tag, forHTTPHeaderField: "If-None-Match")
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            var updatedTag = tag
            var shouldRepeat = repeatingEvery != nil
            var repeatInterval = repeatingEvery ?? self.defaultInterval

            networkingChannel.log("got response for \(self.target)")
            if let error = error {
                networkingChannel.log(error)
            }
            
            do {
                guard let response = response as? HTTPURLResponse else { throw Errors.badResponse }
                guard let data = data else { throw Errors.missingData }

                if let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"), let tag = response.value(forHTTPHeaderField: "Etag") {
                    updatedTag = tag
                    networkingChannel.log("rate limit remaining: \(remaining)")
                }
                
                if let seconds = response.value(forHTTPHeaderField: "X-Poll-Interval").asInt {
                    repeatInterval = max(repeatInterval, seconds)
                    networkingChannel.log("repeat interval \(repeatInterval) (capped at \(seconds))")
                }

                shouldRepeat = try processors.decode(response: response, data: data, in: self) || shouldRepeat

            } catch {
                sessionChannel.log("Error thrown:\n- query: \(query.name)\n- target: \(self.target)\n- payload: \(ProcessorType.Payload.self)\n- error: \(error)\n")
                if let data = data { sessionChannel.log("- data: \(data.prettyPrinted)\n\n") }
            }
            
            if shouldRepeat {
                self.schedule(processor: processor, for: DispatchTime.now().advanced(by: DispatchTimeInterval.seconds(repeatInterval)), tag: updatedTag, repeatingEvery: repeatingEvery)
            }
            
            DispatchQueue.main.async {
                self.tasks = self.tasks.filter { task in return task.state == .running }
            }
        }
        
        DispatchQueue.main.async {
            sessionChannel.log("Sending \(query.name) for \(self.target) (\(request))")
            self.tasks.append(task)
            task.resume()
        }
    }
}

extension Sequence {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        return sorted { a, b in
            return a[keyPath: keyPath] < b[keyPath: keyPath]
        }
    }
}

extension Optional where Wrapped == String {
    var asInt: Int? {
        if let value = self {
            return Int(value)
        } else {
            return nil
        }
    }
}


public extension Data {
    var prettyPrinted: String {
        if let decoded = try? JSONSerialization.jsonObject(with: self, options: []), let encoded = try? JSONSerialization.data(withJSONObject: decoded, options: .prettyPrinted), let string = String(data: encoded, encoding: .utf8) {
            return string
        }
        
        if let string = String(data: self, encoding: .utf8) {
            return string
        }
        
        return String(describing: self)
    }
}
