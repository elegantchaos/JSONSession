// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 28/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Indicates whether polling should continue after processing a response.
public enum RepeatStatus: Sendable {
  /// Request an immediate repeat using the current interval policy.
  case request
  /// Stop repeating this request.
  case cancel
  /// Leave repeat behavior unchanged.
  case inherited
}

/// Type-erased processor used by ``ProcessorGroup`` dispatch.
public struct AnyProcessor<Context: Sendable>: Sendable {
  /// Human-readable processor name for logging.
  public let name: String
  /// HTTP status codes this processor accepts. Empty means all codes.
  public let codes: [Int]

  private let decodePayload: @Sendable (Data, JSONDecoder) throws -> Any
  private let processPayload: @Sendable (Any, HTTPURLResponse, Request<Context>, Context) async throws
    -> RepeatStatus

  /// Creates an erased processor from explicit decode and process closures.
  public init(
    name: String,
    codes: [Int],
    decode: @escaping @Sendable (Data, JSONDecoder) throws -> Any,
    process: @escaping @Sendable (Any, HTTPURLResponse, Request<Context>, Context) async throws
      -> RepeatStatus
  ) {
    self.name = name
    self.codes = codes
    decodePayload = decode
    processPayload = process
  }

  func decode(data: Data, with decoder: JSONDecoder) throws -> Any {
    try decodePayload(data, decoder)
  }

  func process(
    decoded: Any,
    response: HTTPURLResponse,
    for request: Request<Context>,
    in context: Context
  ) async throws -> RepeatStatus {
    try await processPayload(decoded, response, request, context)
  }
}

extension AnyProcessor: ProcessorGroup {
  public var processors: [AnyProcessor<Context>] { [self] }
  public var groupIsProcessor: Bool { true }
}

/// Typed processor convenience protocol for concrete payload/context types.
public protocol Processor<Context>: Sendable {
  /// Context type supplied by the caller while polling.
  associatedtype Context: Sendable
  /// Decoded response type this processor consumes.
  associatedtype Payload: Decodable

  /// Human-readable processor name for logging.
  var name: String { get }
  /// HTTP status codes this processor accepts. Empty means all codes.
  var codes: [Int] { get }

  /// Handles a decoded payload and returns repeat behavior.
  func process(
    _ payload: Payload,
    response: HTTPURLResponse,
    for request: Request<Context>,
    in context: Context
  ) async throws -> RepeatStatus
}

extension Processor {
  public var name: String { "untitled" }

  /// Erases this processor for storage in heterogeneous processor groups.
  public func eraseToAnyProcessor() -> AnyProcessor<Context> {
    AnyProcessor(name: name, codes: codes) { data, decoder in
      try decoder.decode(Payload.self, from: data)
    } process: { decoded, response, request, context in
      try await process(
        decoded as! Payload,
        response: response,
        for: request,
        in: context)
    }
  }
}
