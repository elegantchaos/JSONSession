import Foundation
import Testing

@testable import JSONSession

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("JSONSession")
@MainActor
struct JSONSessionTests {
  let target = Resource("blah")
  let base = URL(string: "https://api.github.com")!

  var url: URL {
    base.appendingPathComponent(target.path)
  }

  struct ExamplePayload: Codable, Equatable, Sendable {
    let name: String
  }

  struct ExampleError: Codable, Equatable, Sendable {
    let message: String
    let details: String
  }

  enum TestResult: Sendable, Equatable {
    case payload(ExamplePayload)
    case error(ExampleError)
    case unexpected
  }

  actor TestContext {
    let targetCount: Int
    let done: @MainActor (TestResult?) -> Void
    var seen = 0

    init(targetCount: Int, done: @escaping @MainActor (TestResult?) -> Void) {
      self.targetCount = targetCount
      self.done = done
    }

    func emit(_ value: TestResult?) async -> RepeatStatus {
      seen += 1
      if seen == targetCount {
        await MainActor.run {
          done(value)
        }
        return .cancel
      }

      return .request
    }
  }

  struct PayloadProcessor: Processor {
    typealias Context = TestContext
    let name = "payload"
    let codes = [200]

    func process(
      _ payload: ExamplePayload,
      response _: HTTPURLResponse,
      for _: Request<TestContext>,
      in context: TestContext
    ) async throws -> RepeatStatus {
      await context.emit(.payload(payload))
    }
  }

  struct ErrorProcessor: Processor {
    typealias Context = TestContext
    let name = "error"
    let codes = [404]

    func process(
      _ payload: ExampleError,
      response _: HTTPURLResponse,
      for _: Request<TestContext>,
      in context: TestContext
    ) async throws -> RepeatStatus {
      await context.emit(.error(payload))
    }
  }

  struct Group: ProcessorGroup {
    typealias Context = TestContext

    let name = "Example Group"
    let processors: [AnyProcessor<TestContext>] = [
      PayloadProcessor().eraseToAnyProcessor(),
      ErrorProcessor().eraseToAnyProcessor(),
      AnyProcessor(name: "catch-all", codes: []) { _, _ in
        ()
      } process: { _, _, _, context in
        await context.emit(.unexpected)
      },
    ]
  }

  final class ResultBox {
    var value: TestResult?
  }

  actor MockAsyncFetcher: HTTPDataFetcher {
    let url: URL
    let responses: [(Data, HTTPURLResponse)]
    var next = 0

    init(url: URL, responses: [(Data, HTTPURLResponse)]) {
      self.url = url
      self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard request.url == url else { throw URLError(.badURL) }
      guard !responses.isEmpty else { throw URLError(.badServerResponse) }
      let index = min(next, responses.count - 1)
      next += 1
      return responses[index]
    }
  }

  func makeResponse<T: Encodable>(_ payload: T, status: Int) throws -> (Data, HTTPURLResponse) {
    let data = try JSONEncoder().encode(payload)
    let response = try #require(
      HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: nil,
        headerFields: nil))
    return (data, response)
  }

  func awaitResult(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    start: (@escaping @MainActor (TestResult?) -> Void) -> Session
  ) async -> TestResult? {
    let box = ResultBox()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      var continuationRef: CheckedContinuation<Void, Never>? = continuation
      var session: Session?
      let finish: @MainActor (TestResult?) -> Void = { value in
        guard let c = continuationRef else { return }
        box.value = value
        continuationRef = nil
        c.resume()
      }

      let timeoutTask = Task { @MainActor in
        try? await Task.sleep(nanoseconds: timeoutNanoseconds)
        guard continuationRef != nil else { return }
        session?.cancel()
        finish(nil)
      }

      session = start { value in
        Task { @MainActor in
          timeoutTask.cancel()
          finish(value)
        }
      }
    }
    return box.value
  }

  func waitForResult(fetcher: any HTTPDataFetcher, count: Int = 1) async -> TestResult? {
    await awaitResult { done in
      let context = TestContext(targetCount: count, done: done)
      let activeSession = Session(base: base, token: "", fetcher: fetcher)
      activeSession.poll(
        target: target,
        context: context,
        processors: Group(),
        repeatingEvery: count == 1 ? nil : 0.1)
      return activeSession
    }
  }

  @Test
  func payload() async throws {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(payload, status: 200)])
    let result = await waitForResult(fetcher: fetcher)
    #expect(result == .payload(payload))
  }

  @Test
  func error() async throws {
    let error = ExampleError(message: "oops", details: "something bad happened")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(error, status: 404)])
    let result = await waitForResult(fetcher: fetcher)
    #expect(result == .error(error))
  }

  @Test
  func unknownResponse() async throws {
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse("blah", status: 303)])
    let result = await waitForResult(fetcher: fetcher)
    #expect(result == .unexpected)
  }

  @Test
  func polling() async throws {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(payload, status: 200)])
    let result = await waitForResult(fetcher: fetcher, count: 3)
    #expect(result == .payload(payload))
  }

  @Test
  func processorAsGroup() async throws {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(payload, status: 200)])
    let result = await awaitResult { done in
      let context = TestContext(targetCount: 1, done: done)
      let processor = PayloadProcessor().eraseToAnyProcessor()
      let activeSession = Session(base: base, token: "", fetcher: fetcher)
      activeSession.poll(target: target, context: context, processors: processor)
      return activeSession
    }
    #expect(result == .payload(payload))
  }

  @Test
  func transportFailureTimesOutWithoutResult() async throws {
    struct AlwaysFailingFetcher: HTTPDataFetcher {
      func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        throw URLError(.cannotConnectToHost)
      }
    }

    let result = await waitForResult(fetcher: AlwaysFailingFetcher())
    #expect(result == nil)
  }

  @Test
  func emptyResponseListTimesOutWithoutResult() async throws {
    let fetcher = MockAsyncFetcher(url: url, responses: [])
    let result = await waitForResult(fetcher: fetcher)
    #expect(result == nil)
  }
}
