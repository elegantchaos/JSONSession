// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 27/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

protocol QueryResponse: Codable {
    
}

public struct Query {
    let name: String
    let query: (Target) -> String
    
    func request(with context: Context, repo: Target) -> URLRequest {
        let authorization = "bearer \(context.token)"
        var request = URLRequest(url: context.endpoint.appendingPathComponent(query(repo)))
        request.addValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        return request
    }
}
