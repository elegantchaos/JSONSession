// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Group of processors that can decode and handle responses for a resource.
public protocol ProcessorGroup<Context>: Sendable {
  /// Context type threaded through response processing.
  associatedtype Context: Sendable

  /// Name of the resource type we process.
  var name: String { get }

  /// Individual processors which match against HTTP responses.
  var processors: [AnyProcessor<Context>] { get }

  /// Is this group actually a single processor. Used to tailor logging messages.
  var groupIsProcessor: Bool { get }

  /// Path to the resource we process.
  func path(for target: any ResourceResolver) -> String

  /// Decode a response and return repeat behavior.
  func decode(
    response: HTTPURLResponse,
    data: Data,
    for request: Request<Context>,
    in context: Context
  ) async throws -> RepeatStatus
}

extension ProcessorGroup {
  /// Default name used when a group does not provide one.
  public var name: String { "untitled group" }
  /// Default assumes this value is a group and not a single processor.
  public var groupIsProcessor: Bool { false }

  /// Resolves request path from the provided target.
  public func path(for target: any ResourceResolver) -> String {
    target.path
  }

  public func decode(
    response: HTTPURLResponse,
    data: Data,
    for request: Request<Context>,
    in context: Context
  ) async throws -> RepeatStatus {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let code = response.statusCode
    for processor in processors {
      let acceptedCodes = processor.codes
      if acceptedCodes.isEmpty || acceptedCodes.contains(code) {
        do {
          let decoded = try processor.decode(data: data, with: decoder)
          let status = try await processor.process(
            decoded: decoded,
            response: response,
            for: request,
            in: context)
          sessionChannel.log(processedMessage(processor: processor, status: status))
          return status

        } catch {
          sessionChannel.log(
            "Error thrown:\n- query: \(name)\n- target: \(response.url!)\n- processor: \(processor.name)\n- error: \(error)\n"
          )
          if let string = String(data: data, encoding: .utf8) {
            sessionChannel.log("Data was: \(string).")
          }
        }
      }
    }

    throw Session.Errors.unexpectedResponse(response.statusCode)
  }

  /// Returns a consistent log message for successful processing.
  private func processedMessage(processor: AnyProcessor<Context>, status: RepeatStatus) -> String {
    let nameInfo = groupIsProcessor ? name : "\(name) using \(processor.name)"
    return "Processed \(nameInfo). Repeat status: \(status)."
  }
}

/// Convenience group wrapper for a list of erased processors.
public struct AnyProcessorGroup<Context: Sendable>: ProcessorGroup {
  /// Group name used in logs.
  public let name: String
  /// Ordered processor chain used for decoding and handling responses.
  public let processors: [AnyProcessor<Context>]

  /// Creates a named group from an ordered list of processors.
  public init(name: String, processors: [AnyProcessor<Context>]) {
    self.name = name
    self.processors = processors
  }
}
