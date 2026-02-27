// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 27/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Legacy helper for constructing authenticated URL requests.
public struct Query {
  /// Human-readable query name.
  let name: String
  /// Closure that resolves query-specific path components.
  let query: @Sendable (any ResourceResolver, Session) -> String

  /// Builds an authenticated GET request for a target resource.
  func request(for target: any ResourceResolver, in session: Session) -> URLRequest {
    let authorization = "bearer \(session.token)"
    var request = URLRequest(url: session.base.appendingPathComponent(target.path))
    request.addValue(authorization, forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    return request
  }
}
