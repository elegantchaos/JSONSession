// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 27/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Logger

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public let sessionChannel = Channel("com.elegantchaos.jsonsession.JSONSession")
public let networkingChannel = Channel("com.elegantchaos.jsonsession.JSONNetworking")

/// Minimal async data loading interface used by ``Session``.
public protocol HTTPDataFetcher {
  /// Fetches bytes and response metadata for a request.
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataFetcher {}

open class Session: @unchecked Sendable {
  /// Transport used for outbound HTTP requests.
  public let fetcher: any HTTPDataFetcher
  /// Base URL for all polled resources.
  public let base: URL
  /// Bearer token sent with each request.
  public let token: String
  /// Default repeat interval in seconds when none is supplied per poll call.
  public let defaultInterval: TimeInterval

  final class ManagedTask: @unchecked Sendable {
    var task: Task<Void, Never>?
    var isDone = false

    func cancel() {
      task?.cancel()
      isDone = true
    }
  }

  var tasks: [ManagedTask] = []

  public init(
    base: URL,
    token: String,
    defaultInterval: TimeInterval = 60.0,
    fetcher: any HTTPDataFetcher = URLSession.shared
  ) {
    self.base = base
    self.token = token
    self.defaultInterval = defaultInterval
    self.fetcher = fetcher
  }

  public func poll<Context: Sendable>(
    target: ResourceResolver,
    context: Context,
    processors: some ProcessorGroup<Context>,
    for deadline: DispatchTime = DispatchTime.now(),
    tag: String? = nil,
    repeatingEvery: TimeInterval? = nil
  ) {
    let request = Request(
      resource: target,
      processors: processors,
      tag: tag,
      repeating: repeatingEvery != nil,
      interval: repeatingEvery ?? defaultInterval)
    poll(request, context: context, deadline: deadline)
  }

  public func cancel() {
    for task in tasks {
      task.cancel()
    }
    tasks = []
  }
}

extension Session {
  /// Internal session error states while handling responses.
  enum Errors: Error {
    case badResponse
    case missingData
    case apiError(Failure)
    case unexpectedResponse(Int)
  }

  func poll<Context: Sendable>(
    _ request: Request<Context>,
    context: Context,
    deadline: DispatchTime
  ) {
    request.log(deadline: deadline)
    let managed = ManagedTask()
    tasks.append(managed)
    managed.task = Task { [weak self] in
      defer {
        managed.isDone = true
        self?.tasks = self?.tasks.filter { !$0.isDone } ?? []
      }

      let delay = max(0, DispatchTime.now().distance(to: deadline).asTimeInterval)
      if delay > 0 {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
      guard !Task.isCancelled, let self else { return }
      await self.sendRequest(request: request, context: context)
    }
  }

  func sendRequest<Context: Sendable>(request: Request<Context>, context: Context) async {
    let urlRequest = request.urlRequest(for: self)
    do {
      let (data, response) = try await fetcher.data(for: urlRequest)
      request.log(response: response)
      let updatedRequest = await processResponse(.success(data), response: response, for: request, context: context)
      if let deadline = updatedRequest.repeatTime {
        poll(updatedRequest, context: context, deadline: deadline)
      }
    } catch {
      request.log(response: nil)
      _ = await processResponse(.failure(error), response: nil, for: request, context: context)
    }
  }

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
