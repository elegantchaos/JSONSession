// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 27/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Logger

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Logging channel for request lifecycle messages.
public let sessionChannel = Channel("com.elegantchaos.jsonsession.JSONSession")
/// Logging channel for transport and network diagnostics.
public let networkingChannel = Channel("com.elegantchaos.jsonsession.JSONNetworking")

/// Minimal async data loading interface used by ``Session``.
public protocol HTTPDataFetcher: Sendable {
  /// Fetches bytes and response metadata for a request.
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataFetcher {}

/// Concurrency-safe HTTP session wrapper used to fetch and decode JSON resources.
public actor Session {
  /// Result event produced by stream-based polling.
  public enum PollDataEvent: Sendable {
    /// Successful response payload.
    case response(Data, HTTPURLResponse)
    /// Transport-level failure while executing a poll request.
    case transportError(String)
  }

  /// Transport used for outbound HTTP requests.
  public let fetcher: any HTTPDataFetcher
  /// Base URL for all polled resources.
  public nonisolated let base: URL
  /// Bearer token sent with each request.
  public nonisolated let token: String

  /// Creates a session bound to a base URL and bearer token.
  public init(
    base: URL,
    token: String,
    fetcher: any HTTPDataFetcher = URLSession.shared
  ) {
    self.base = base
    self.token = token
    self.fetcher = fetcher
  }

  /// Executes a single request and runs the provided processors over the response.
  public func request<Context: Sendable>(
    target: any ResourceResolver,
    context: Context,
    processors: some ProcessorGroup<Context>,
    tag: String? = nil
  ) async {
    let request = Request(
      resource: target,
      processors: processors,
      tag: tag,
      repeating: false,
      interval: 0
    )
    await sendRequest(request: request, context: context)
  }

  /// Executes a single request and returns the raw bytes and HTTP response.
  public func data(for target: any ResourceResolver, tag: String? = nil) async throws -> (Data, HTTPURLResponse) {
    let path = target.path
    let authorization = "bearer \(token)"
    var request = URLRequest(url: base.appendingPathComponent(path))
    request.addValue(authorization, forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    request.cachePolicy = .reloadIgnoringLocalCacheData
    if let tag {
      request.addValue(tag, forHTTPHeaderField: "If-None-Match")
    }

    let (data, response) = try await fetcher.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw Errors.badResponse
    }

    return (data, http)
  }

  /// Starts polling for a target and yields responses in an async stream.
  ///
  /// The stream issues an immediate request unless `initialDelay` is non-zero.
  /// It continues until the consumer stops iteration or the polling task is cancelled.
  public nonisolated func pollData(
    for target: any ResourceResolver,
    every interval: Duration,
    initialDelay: Duration = .zero,
    tag: String? = nil
  ) -> AsyncStream<PollDataEvent> {
    AsyncStream(PollDataEvent.self, bufferingPolicy: .bufferingNewest(1)) { continuation in
      let pollingTask = Task {
        if initialDelay > .zero {
          do {
            try await Task.sleep(for: initialDelay)
          } catch {
            continuation.finish()
            return
          }
        }

        var currentTag = tag
        while !Task.isCancelled {
          do {
            let (data, response) = try await self.data(for: target, tag: currentTag)
            currentTag = response.value(forHTTPHeaderField: "Etag") ?? currentTag
            continuation.yield(.response(data, response))
          } catch {
            networkingChannel.log(error)
            continuation.yield(.transportError(String(describing: error)))
          }

          do {
            try await Task.sleep(for: interval)
          } catch {
            break
          }
        }

        continuation.finish()
      }

      continuation.onTermination = { _ in
        pollingTask.cancel()
      }
    }
  }
}

extension Session {
  /// Internal session error states while handling responses.
  enum Errors: Error {
    /// Response was not an `HTTPURLResponse`.
    case badResponse
    /// Response body was unexpectedly absent.
    case missingData
    /// API returned an explicit failure payload.
    case apiError(Failure)
    /// No processor handled the received status code.
    case unexpectedResponse(Int)
  }

  /// Runs a request and forwards the result into processor decoding.
  func sendRequest<Context: Sendable>(request: Request<Context>, context: Context) async {
    do {
      let (data, response) = try await data(for: request.resource, tag: request.tag)
      request.log(response: response)
      _ = await processResponse(.success(data), response: response, for: request, context: context)
    } catch {
      request.log(response: nil)
      _ = await processResponse(.failure(error), response: nil, for: request, context: context)
    }
  }

  /// Decodes and dispatches response data through the processor chain.
  func processResponse<Context: Sendable>(
    _ result: Result<Data, Error>,
    response: URLResponse?,
    for request: Request<Context>,
    context: Context
  ) async -> Request<Context> {
    switch result {
    case .failure(let error):
      networkingChannel.log(error)

    case .success(let data):
      do {
        guard let response = response as? HTTPURLResponse else { throw Errors.badResponse }

        var updatedRequest = request
        if let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
          let tag = response.value(forHTTPHeaderField: "Etag")
        {
          updatedRequest.tag = tag
          networkingChannel.log("rate limit remaining: \(remaining)")
        }

        if let intervalHeader = response.value(forHTTPHeaderField: "X-Poll-Interval"),
          let seconds = Double(intervalHeader)
        {
          updatedRequest.capInterval(to: seconds)
        }

        let status = try await request.processors.decode(
          response: response,
          data: data,
          for: request,
          in: context)
        updatedRequest.updateRepeat(status: status)
        return updatedRequest

      } catch {
        request.log(error: error, data: data)
      }
    }

    return request
  }
}

extension Data {
  /// Returns human-readable JSON or UTF-8 output for diagnostic logging.
  public var prettyPrinted: String {
    if let decoded = try? JSONSerialization.jsonObject(with: self, options: []),
      let encoded = try? JSONSerialization.data(withJSONObject: decoded, options: .prettyPrinted),
      let string = String(data: encoded, encoding: .utf8)
    {
      return string
    }

    if let string = String(data: self, encoding: .utf8) {
      return string
    }

    return String(describing: self)
  }
}
