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
  public let name: String
  /// Closure that resolves query-specific path components.
  private let query: @Sendable (any ResourceResolver, Session) -> String

  /// Creates a named query helper with custom path resolution.
  public init(name: String, query: @escaping @Sendable (any ResourceResolver, Session) -> String) {
    self.name = name
    self.query = query
  }

  /// Builds an authenticated GET request for a target resource.
  public func request(for target: any ResourceResolver, in session: Session) -> URLRequest {
    let authorization = "bearer \(session.token)"
    let path = query(target, session)
    var request = URLRequest(url: session.base.appendingPathComponent(path))
    request.addValue(authorization, forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    return request
  }
}
