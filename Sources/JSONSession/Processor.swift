// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 28/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Indicates whether polling should continue after processing a response.
public enum RepeatStatus {
  /// Request an immediate repeat using the current interval policy.
  case request
  /// Stop repeating this request.
  case cancel
  /// Leave repeat behavior unchanged.
  case inherited
}

/// Base interface for response processors used by a ``ProcessorGroup``.
public protocol ProcessorBase: ProcessorGroup {
  /// Human-readable processor name for logging.
  var name: String { get }
  /// HTTP status codes this processor accepts. Empty means all codes.
  var codes: [Int] { get }
  /// Decodes raw response bytes into a payload value.
  func decode(data: Data, with decoder: JSONDecoder) throws -> Decodable
  /// Handles a decoded payload and returns repeat behavior.
  func process(
    decoded: Decodable, response: HTTPURLResponse, for request: Request, in session: Session
  ) -> RepeatStatus
}

extension ProcessorBase {
  public var name: String { "untitled" }
  public var processors: [ProcessorBase] { [self] }
}

/// Typed processor convenience protocol for concrete payload/session types.
public protocol Processor: ProcessorBase {
  /// Decoded response type this processor consumes.
  associatedtype Payload: Decodable
  /// Session subtype expected by this processor.
  associatedtype SessionType: Session
  /// Handles a decoded payload and returns repeat behavior.
  func process(
    _ payload: Payload, response: HTTPURLResponse, for request: Request, in session: SessionType
  ) -> RepeatStatus
}

extension Processor {
  public func decode(data: Data, with decoder: JSONDecoder) throws -> Decodable {
    try decoder.decode(Payload.self, from: data)
  }

  public func process(
    decoded: Decodable, response: HTTPURLResponse, for request: Request, in session: Session
  ) -> RepeatStatus {
    process(decoded as! Payload, response: response, for: request, in: session as! SessionType)
  }
}
