// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 22/07/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Basic resource with a fixed path.
public struct Resource: ResourceResolver {
  /// Relative path appended to the configured API base URL.
  public let path: String
  /// Creates a fixed-path resource.
  public init(_ path: String) { self.path = path }
}
