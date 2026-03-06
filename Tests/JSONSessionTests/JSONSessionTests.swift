import Foundation
import Testing

@testable import JSONSession

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("JSONSession")
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
    private var emitted: [TestResult] = []

    func emit(_ value: TestResult) -> RepeatStatus {
      emitted.append(value)
      return .cancel
    }

    func results() -> [TestResult] {
      emitted
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

  actor CountingFetcher: HTTPDataFetcher {
    private let url: URL
    private let response: (Data, HTTPURLResponse)
    private(set) var callCount = 0

    init(url: URL, response: (Data, HTTPURLResponse)) {
      self.url = url
      self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard request.url == url else { throw URLError(.badURL) }
      callCount += 1
      return response
    }

    func count() -> Int {
      callCount
    }
  }

  func makeResponse<T: Encodable>(
    _ payload: T,
    status: Int,
    headers: [String: String]? = nil
  ) throws -> (Data, HTTPURLResponse) {
    let data = try JSONEncoder().encode(payload)
    let response = try #require(
      HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: nil,
        headerFields: headers))
    return (data, response)
  }

  func executeRequests(
    fetcher: any HTTPDataFetcher,
    count: Int = 1,
    processorGroup: some ProcessorGroup<TestContext> = Group()
  ) async -> [TestResult] {
    let context = TestContext()
    let session = Session(base: base, token: "", fetcher: fetcher)

    for _ in 0 ..< count {
      _ = await session.request(target: target, context: context, processors: processorGroup)
    }

    return await context.results()
  }

  @Test
  func payload() async throws {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(payload, status: 200)])
    let results = await executeRequests(fetcher: fetcher)
    #expect(results == [.payload(payload)])
  }

  @Test
  func error() async throws {
    let error = ExampleError(message: "oops", details: "something bad happened")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(error, status: 404)])
    let results = await executeRequests(fetcher: fetcher)
    #expect(results == [.error(error)])
  }

  @Test
  func unknownResponse() async throws {
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse("blah", status: 303)])
    let results = await executeRequests(fetcher: fetcher)
    #expect(results == [.unexpected])
  }

  @Test
  func repeatedRequests() async throws {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(payload, status: 200)])
    let results = await executeRequests(fetcher: fetcher, count: 3)
    #expect(results == [.payload(payload), .payload(payload), .payload(payload)])
  }

  @Test
  func processorAsGroup() async throws {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(payload, status: 200)])
    let results = await executeRequests(fetcher: fetcher, processorGroup: PayloadProcessor().eraseToAnyProcessor())
    #expect(results == [.payload(payload)])
  }

  @Test
  func transportFailureProducesNoResult() async throws {
    struct AlwaysFailingFetcher: HTTPDataFetcher {
      func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        throw URLError(.cannotConnectToHost)
      }
    }

    let results = await executeRequests(fetcher: AlwaysFailingFetcher())
    #expect(results.isEmpty)
  }

  @Test
  func emptyResponseListProducesNoResult() async throws {
    let fetcher = MockAsyncFetcher(url: url, responses: [])
    let results = await executeRequests(fetcher: fetcher)
    #expect(results.isEmpty)
  }

  @Test
  func pollDataStreamsResponses() async throws {
    let payload = ExamplePayload(name: "test")
    let fetcher = CountingFetcher(url: url, response: try makeResponse(payload, status: 200))
    let session = Session(base: base, token: "", fetcher: fetcher)

    var events: [Session.PollDataEvent] = []
    var iterator = session.pollData(for: target, every: .milliseconds(10)).makeAsyncIterator()
    while events.count < 3, let event = await iterator.next() {
      events.append(event)
    }

    #expect(events.count == 3)
    for event in events {
      switch event {
      case .response:
        break
      case .transportError(let message):
        Issue.record("Unexpected transport error event: \(message)")
      }
    }
  }

  @Test
  func pollDataStopsAfterStreamTermination() async throws {
    let payload = ExamplePayload(name: "test")
    let fetcher = CountingFetcher(url: url, response: try makeResponse(payload, status: 200))
    let session = Session(base: base, token: "", fetcher: fetcher)

    do {
      let stream = session.pollData(for: target, every: .milliseconds(20))
      let consumeOneTask = Task {
        var seen = 0
        for await _ in stream {
          seen += 1
          if seen == 1 {
            break
          }
        }
      }
      _ = await consumeOneTask.value
    }

    let countAfterTermination = await fetcher.count()
    try await Task.sleep(for: .milliseconds(120))
    let finalCount = await fetcher.count()
    #expect(finalCount - countAfterTermination <= 1)
  }

  @Test
  func requestReturnsOutcomeWithTagRepeatAndInterval() async throws {
    struct RequestingProcessor: Processor {
      typealias Context = TestContext
      let codes = [200]

      func process(
        _ payload: ExamplePayload,
        response _: HTTPURLResponse,
        for _: Request<TestContext>,
        in context: TestContext
      ) async throws -> RepeatStatus {
        _ = await context.emit(.payload(payload))
        return .request
      }
    }

    let payload = ExamplePayload(name: "test")
    let fetcher = MockAsyncFetcher(
      url: url,
      responses: [
        try makeResponse(
          payload,
          status: 200,
          headers: ["Etag": "\"abc123\"", "X-Poll-Interval": "42"])
      ])
    let session = Session(base: base, token: "", fetcher: fetcher)
    let context = TestContext()

    let outcome = await session.request(
      target: target,
      context: context,
      processors: RequestingProcessor().eraseToAnyProcessor())

    #expect(outcome.nextTag == "\"abc123\"")
    #expect(outcome.repeatStatus == .request)
    #expect(outcome.pollInterval == 42)
    #expect(await context.results() == [.payload(payload)])
  }

  @Test
  func queryRequestUsesQueryClosurePath() async {
    struct NeverUsedFetcher: HTTPDataFetcher {
      func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        throw URLError(.badServerResponse)
      }
    }

    let session = Session(base: base, token: "token", fetcher: NeverUsedFetcher())
    let query = Query(name: "override") { _, _ in
      "custom/path"
    }

    let request = query.request(for: target, in: session)
    #expect(request.url == base.appendingPathComponent("custom/path"))
    #expect(request.value(forHTTPHeaderField: "Authorization") == "bearer token")
  }

  @Test
  func requestUsesProcessorGroupPathOverride() async throws {
    struct OverridePathGroup: ProcessorGroup {
      typealias Context = TestContext
      let name = "Override Path Group"
      let processors: [AnyProcessor<TestContext>] = [PayloadProcessor().eraseToAnyProcessor()]

      func path(for _: any ResourceResolver) -> String {
        "override/path"
      }
    }

    let payload = ExamplePayload(name: "test")
    let overrideURL = base.appendingPathComponent("override/path")
    let fetcher = MockAsyncFetcher(url: overrideURL, responses: [try makeResponse(payload, status: 200)])
    let context = TestContext()
    let session = Session(base: base, token: "", fetcher: fetcher)

    _ = await session.request(target: target, context: context, processors: OverridePathGroup())
    #expect(await context.results() == [.payload(payload)])
  }
}
