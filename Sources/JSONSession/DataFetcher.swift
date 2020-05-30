// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/05/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
import Foundation

// TODO: move to separate package

/**
 Simple abstraction for fetching data synchronously from a URL and returning it as
 dictionary data.
 
 This mainly exists to allow us to use dependency injection to swap in a non network-dependent
 fetcher for testing purposes.
 */

public typealias DataCallback = (Data?, URLResponse?, Error?) -> Void
public typealias JSONCallback = (JSONDictionary?, URLResponse?, Error?) -> Void

public protocol DataTask {
    var isDone: Bool { get }
    func resume()
    func cancel()
}

public protocol DataFetcher {
    func data(for request: URLRequest, callback: @escaping DataCallback) -> DataTask
    func json(for request: URLRequest, callback: @escaping JSONCallback) -> DataTask
}

public extension DataFetcher {
    func json(for request: URLRequest, callback: @escaping JSONCallback) -> DataTask {
        data(for: request) { data, request, error in
            let json: JSONDictionary?
            if let data = data, let parsed = try? JSONSerialization.jsonObject(with: data, options: []) {
                json = parsed as? JSONDictionary
            } else {
                json = nil
            }
            callback(json, request, error)
        }
    }
}

extension URLSessionDataTask: DataTask {
    public var isDone: Bool {
        state == .completed
    }
}

extension URLSession: DataFetcher {
    public func data(for request: URLRequest, callback: @escaping DataCallback) -> DataTask {
        let task = dataTask(with: request) { data, response, error in
            callback(data, response, error)
        }
        return task
    }
}

