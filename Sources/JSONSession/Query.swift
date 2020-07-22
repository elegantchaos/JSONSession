// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 27/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct Query {
    let name: String
    let query: (ResourceResolver, Session) -> String
    
    func request(for target: ResourceResolver, in session: Session) -> URLRequest {
        let authorization = "bearer \(session.token)"
        var request = URLRequest(url: session.base.appendingPathComponent(target.path(in: session)))
        request.addValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        return request
    }
}
