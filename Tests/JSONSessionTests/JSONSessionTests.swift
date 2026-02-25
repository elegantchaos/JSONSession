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

  struct ExamplePayload: Codable, Equatable {
    let name: String
  }

  struct ExampleError: Codable, Equatable {
    let message: String
    let details: String
  }

  struct PayloadProcessor: Processor {
    var name = "Test"
    var codes: [Int] = [200]
    var callback: (ExamplePayload) -> RepeatStatus

    func process(
      _ payload: ExamplePayload, response _: HTTPURLResponse, for _: Request, in _: Session
    ) -> RepeatStatus {
      callback(payload)
    }
  }

  struct ErrorProcessor: Processor {
    let name = "Test"
    let codes: [Int] = [404]
    var callback: (ExampleError) -> Void

    func process(
      _ payload: ExampleError, response _: HTTPURLResponse, for _: Request, in _: Session
    ) -> RepeatStatus {
      callback(payload)
      return .inherited
    }
  }

  struct CatchAllProcessor: ProcessorBase {
    var codes: [Int] = []
    var callback: () -> Void

    func process(decoded _: Decodable, response _: HTTPURLResponse, for _: Request, in _: Session)
      -> RepeatStatus
    {
      callback()
      return .inherited
    }

    func decode(data: Data, with _: JSONDecoder) throws -> Decodable {
      data
    }
  }

  final class Group: ProcessorGroup {
    let name = "Example Group"
    let processors: [ProcessorBase]

    init(target: Int, done: @escaping (Any) -> Void) {
      var count = 0
      let gotResult: (Any) -> RepeatStatus = { result in
        count += 1
        if count == target {
          done(result)
          return .cancel
        } else {
          return .request
        }
      }

      processors = [
        PayloadProcessor { gotResult($0) },
        ErrorProcessor { _ = gotResult($0) },
        CatchAllProcessor { _ = gotResult("Unexpected Result") },
      ]
    }
  }

  final class ResultBox {
    var value: Any?
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
        url: url, statusCode: status, httpVersion: nil,
        headerFields: nil))
    return (data, response)
  }

  func awaitResult(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    start: (@escaping @MainActor (Any?) -> Void) -> Session
  ) async -> Any? {
    let box = ResultBox()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      var continuationRef: CheckedContinuation<Void, Never>? = continuation
      var session: Session?
      let finish: @MainActor (Any?) -> Void = { value in
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

  func waitForResult(fetcher: any HTTPDataFetcher, count: Int = 1) async -> Any? {
    await awaitResult { done in
      let group = Group(target: count) { result in
        done(result)
      }
      let activeSession = Session(base: base, token: "", fetcher: fetcher)
      activeSession.poll(
        target: target, processors: group, repeatingEvery: count == 1 ? nil : 0.1)
      return activeSession
    }
  }

  @Test
  func payload() async throws {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(payload, status: 200)])
    let result = await waitForResult(fetcher: fetcher)
    #expect(result as? ExamplePayload == payload)
  }

  @Test
  func error() async throws {
    let error = ExampleError(message: "oops", details: "something bad happened")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(error, status: 404)])
    let result = await waitForResult(fetcher: fetcher)
    #expect(result as? ExampleError == error)
  }

  @Test
  func unknownResponse() async throws {
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse("blah", status: 303)])
    let result = await waitForResult(fetcher: fetcher)
    #expect(result as? String == "Unexpected Result")
  }

  @Test
  func polling() async throws {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(payload, status: 200)])
    let result = await waitForResult(fetcher: fetcher, count: 3)
    #expect(result as? ExamplePayload == payload)
  }

  @Test
  func processorAsGroup() async throws {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockAsyncFetcher(url: url, responses: [try makeResponse(payload, status: 200)])
    let result = await awaitResult { done in
      let processor = PayloadProcessor { value in
        done(value)
        return .cancel
      }
      let activeSession = Session(base: base, token: "", fetcher: fetcher)
      activeSession.poll(target: target, processors: processor)
      return activeSession
    }
    #expect(result as? ExamplePayload == payload)
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
