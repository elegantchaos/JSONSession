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
        let data: Data
        let request: URLRequest
        let callback: DataCallback
        
        init(data: Data, request: URLRequest, callback: @escaping DataCallback) {
            self.data = data
            self.request = request
            self.callback = callback
        }
        
        public var isDone = false
        public func cancel() { }
        public func resume() {
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: data.count, textEncodingName: "")
            callback(data, response, nil)
            isDone = true
        }
    }
    
    public let data: Data
    
    public init(data: Data) {
        self.data = data
    }
    
    public func data(for request: URLRequest, callback: @escaping DataCallback) -> DataTask {
        return Task(data: data, request: request, callback: callback)
    }
}
