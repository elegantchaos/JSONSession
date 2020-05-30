// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 30/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/**
 Test fetcher which ignores the URL and just returns the data it's been given.
 Useful for testing.
 */

public struct MockDataFetcher: DataFetcher {
    public class Task: DataTask {
        let data: Data?
        let response: URLResponse?
        let error: Error?
        let callback: DataCallback
        
        init(data: Data? = nil, response: URLResponse? = nil, error: Error? = nil, callback: @escaping DataCallback) {
            self.data = data
            self.response = response
            self.error = error
            self.callback = callback
        }
        
        public var isDone = false
        public func cancel() { }
        public func resume() {
            callback(data, response, error)
            isDone = true
        }
    }

    public enum InternalError: Error {
        case urlMissing
        case outputMissing
    }
    
    public enum Output {
        case string(String, Int)
        case data(Data, Int)
        case error(Error)
        case missing
    }
    
    public let output: [URL:Output]
    
    public init(output: [URL:Output]) {
        self.output = output
    }
    
    public func data(for request: URLRequest, callback: @escaping DataCallback) -> DataTask {
        var outputError: Error
        if let url = request.url, let output = output[url] {
            switch output {
            case .string(let string, let code): return task(url: url, data: string.data(using: .utf8)!, code: code, callback: callback)
            case .data(let data, let code): return task(url: url, data: data, code: code, callback: callback)
            case .error(let error): outputError = error
            case .missing: outputError = InternalError.outputMissing
            }
        } else {
            outputError = InternalError.urlMissing
        }
        
        return Task(error: outputError, callback: callback)
    }
    
    func task(url: URL, data: Data, code: Int, callback: @escaping DataCallback) -> DataTask {
        let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: "1.0", headerFields: [:])
        return Task(data: data, response: response, callback: callback)
    }
}
