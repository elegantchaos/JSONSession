// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 28/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Standard GitHub-style API failure payload.
public struct Failure: Codable, Sendable {
  /// Human-readable failure summary.
  let message: String
  /// Documentation URL supplied by the API.
  let documentation_url: String

  /// Indicates whether this failure can be ignored by higher-level callers.
  var canIgnore: Bool { false }
}
