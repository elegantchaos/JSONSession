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
        let request: URLRequest
        let error: Error?
        let callback: DataCallback
        
        init(data: Data? = nil, request: URLRequest, error: Error? = nil, callback: @escaping DataCallback) {
            self.data = data
            self.request = request
            self.error = error
            self.callback = callback
        }
        
        public var isDone = false
        public func cancel() { }
        public func resume() {
            let length = data?.count ?? 0
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: length, textEncodingName: "")
            callback(data, response, error)
            isDone = true
        }
    }

    public enum InternalError: Error {
        case urlMissing
        case outputMissing
    }
    
    public enum Output {
        case data(Data)
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
            case .data(let data): return Task(data: data, request: request, callback: callback)
            case .error(let error): outputError = error
            case .missing: outputError = InternalError.outputMissing
            }
        } else {
            outputError = InternalError.urlMissing
        }
        
        return Task(request: request, error: outputError, callback: callback)
    }
}
