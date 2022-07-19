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

public let sessionChannel = Channel("com.elegantchaos.jsonsession.JSONSession")
public let networkingChannel = Channel("com.elegantchaos.jsonsession.JSONNetworking")

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
        let request = Request(resource: target, processors: processors, tag: tag, repeating: repeatingEvery != nil, interval: repeatingEvery ?? defaultInterval)
        poll(request, deadline: deadline)
    }

    public func cancel() {
        for task in tasks {
            task.cancel()
        }
        tasks = []
    }
}

internal extension Session {
    enum Errors: Error {
        case badResponse
        case missingData
        case apiError(Failure)
        case unexpectedResponse(Int)
    }

    func poll(_ request: Request, deadline: DispatchTime) {
        request.log(deadline: deadline)
        DispatchQueue.global(qos: .background).asyncAfter(deadline: deadline) {
            self.sendRequest(request: request)
        }
    }

    func sendRequest(request: Request) {
        // TODO: add a SessionSession which contains the session and the target. Pass that to the processor group instead of self. This allows processors to read the target, and allows custom target objects to store state.
        let urlRequest = request.urlRequest(for: self)
        let task = fetcher.data(for: urlRequest) { result, response in
            request.log(response: response)
            let updatedRequest = self.processResponse(result, response: response, for: request)
            if let deadline = updatedRequest.repeatTime {
                self.poll(updatedRequest, deadline: deadline)
            }

            DispatchQueue.main.async {
                self.tasks = self.tasks.filter { task in !task.isDone }
            }
        }

        DispatchQueue.main.async {
            self.tasks.append(task)
            task.resume()
        }
    }

    func processResponse(_ result: Result<Data, Error>, response: URLResponse?, for request: Request) -> Request {
        switch result {
            case let .failure(error):
                networkingChannel.log(error)

            case let .success(data):
                do {
                    guard let response = response as? HTTPURLResponse else { throw Errors.badResponse }

                    var updatedRequest = request
                    if let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"), let tag = response.value(forHTTPHeaderField: "Etag") {
                        updatedRequest.tag = tag
                        networkingChannel.log("rate limit remaining: \(remaining)")
                    }

                    if let seconds = response.value(forHTTPHeaderField: "X-Poll-Interval")?.asDouble {
                        updatedRequest.capInterval(to: seconds)
                    }

                    let status = try request.processors.decode(response: response, data: data, for: request, in: self)
                    updatedRequest.updateRepeat(status: status)
                    return updatedRequest

                } catch {
                    request.log(error: error, data: data)
                }
        }

        return request
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

private func example() {
    /// if the response is 200, the server will send us an item
    struct ItemProcessor: Processor {
        struct Item: Decodable {
            let name: String
        }

        let codes = [200]
        func process(_ item: Item, response _: HTTPURLResponse, for _: Request, in _: Session) -> RepeatStatus {
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
        func process(_ payload: Error, response _: HTTPURLResponse, for _: Request, in _: Session) -> RepeatStatus {
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
