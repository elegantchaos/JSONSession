// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 27/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Coercion
import DataFetcher
import Foundation
import Logger

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public let sessionChannel = Channel("com.elegantchaos.jsonsession.session")
public let networkingChannel = Channel("com.elegantchaos.jsonsession.networking")

extension TimeInterval {
    var asDispatchTimeInterval: DispatchTimeInterval {
        return .nanoseconds(Int(self * 1000000000.0))
    }
}

public enum ResponseState {
    case updated
    case unchanged
    case error
    case other
}

open class Session {
    public let fetcher: DataFetcher
    public let base: URL
    public let token: String
    public let defaultInterval: TimeInterval
    
    var tasks: [DataTask] = []
    
    public init(base: URL, token: String, defaultInterval: TimeInterval = 60.0, fetcher: DataFetcher = URLSession.shared) {
        self.base = base
        self.token = token
        self.defaultInterval = defaultInterval
        self.fetcher = fetcher
    }
    
    
    public func poll(target: ResourceResolver, processors: ProcessorGroup, for deadline: DispatchTime = DispatchTime.now(), tag: String? = nil, repeatingEvery: TimeInterval? = nil) {
        let distance = DispatchTime.now().distance(to: deadline)
        sessionChannel.log("Scheduled \(processors.name) in \(distance)")
        DispatchQueue.global(qos: .background).asyncAfter(deadline: deadline) {
            self.sendRequest(target: target, processors: processors, repeatingEvery: repeatingEvery)
        }
    }
        
    enum Errors: Error {
        case badResponse
        case missingData
        case apiError(Failure)
        case unexpectedResponse(Int)
    }
    
    func request(for target: ResourceResolver, processors: ProcessorGroup) -> URLRequest {
        let authorization = "bearer \(token)"
        let path = processors.path(for: target, in: self)
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.addValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        return request
    }

    func sendRequest(target: ResourceResolver, processors: ProcessorGroup, tag: String? = nil, repeatingEvery: TimeInterval? = nil) {
        // TODO: add a SessionSession which contains the session and the target. Pass that to the processor group instead of self. This allows processors to read the target, and allows custom target objects to store state.
        var request = self.request(for: target, processors: processors)
        if let tag = tag {
            request.addValue(tag, forHTTPHeaderField: "If-None-Match")
        }
        
        let task = fetcher.data(for: request) { result, response in
            var updatedTag = tag
            var shouldRepeat = repeatingEvery != nil
            var repeatInterval = repeatingEvery ?? self.defaultInterval

            networkingChannel.log("got response for \(target)")
            
            switch result {
            case .failure(let error):
                networkingChannel.log(error)
                
            case .success(let data):
                do {
                    guard let response = response as? HTTPURLResponse else { throw Errors.badResponse }

                    if let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"), let tag = response.value(forHTTPHeaderField: "Etag") {
                        updatedTag = tag
                        networkingChannel.log("rate limit remaining: \(remaining)")
                    }
                    
                    if let seconds = response.value(forHTTPHeaderField: "X-Poll-Interval")?.asDouble {
                        repeatInterval = max(repeatInterval, seconds)
                        networkingChannel.log("repeat interval \(repeatInterval) (capped at \(seconds))")
                    }

                    let status = try processors.decode(response: response, data: data, in: self)
                    shouldRepeat = status.shouldRepeat(current: shouldRepeat)

                } catch {
                    sessionChannel.log("Error thrown:\n- query: \(processors.name)\n- target: \(target)\n- processor: \(processors.name)\n- error: \(error)\n")
                    sessionChannel.log("- data: \(data.prettyPrinted)\n\n")
                }

            }
            
            
            if shouldRepeat {
                let nextRepeat = DispatchTime.now().advanced(by: repeatInterval.asDispatchTimeInterval)
                self.poll(target: target, processors: processors, for: nextRepeat, tag: updatedTag, repeatingEvery: repeatingEvery)
            }
            
            DispatchQueue.main.async {
                self.tasks = self.tasks.filter { task in !task.isDone }
            }
        }
        
        DispatchQueue.main.async {
            sessionChannel.log("Sending \(processors.name) for \(target) (\(request))")
            self.tasks.append(task)
            task.resume()
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


fileprivate func example() {
    /// if the response is 200, the server will send us an item
    struct ItemProcessor: Processor {
        struct Item: Decodable {
            let name: String
        }

        let codes = [200]
        func process(_ item: Item, response: HTTPURLResponse, in session: Session) -> RepeatStatus {
            print("Received item \(item.name)")
            return .inherited
        }
    }
    
    /// if the response is 400, the server will send us an error
    struct ErrorProcessor: Processor {
        struct Error: Decodable {
            let error: String
        }

        let codes = [400]
        func process(_ payload: Error, response: HTTPURLResponse, in session: Session) -> RepeatStatus {
            print("Something went wrong: \(payload.error)")
            return .inherited
        }
    }

    // make a session for the service we're targetting, supplying the authorization token
    let session = Session(base: URL(string: "https://some.endpoint/v1/")!, token: "<api-token>")
    
    // schedule polling of some REST resource
    session.poll(target: Resource("some/rest/request"), processors: [ItemProcessor(), ErrorProcessor()], repeatingEvery: 1.0)

    // the endpoint will be queried repeatedly by the session
    // when an expected response comes back, the response will be decoded and one of our processor objects will be called to process it
    RunLoop.main.run()
}
