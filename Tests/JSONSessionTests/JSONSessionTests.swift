import DataFetcher
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

  func waitForResult(fetcher: DataFetcher, count: Int = 1) async -> Any? {
    let box = ResultBox()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      let group = Group(target: count) { result in
        Task { @MainActor in
          box.value = result
          continuation.resume()
        }
      }
      let session = Session(base: base, token: "", fetcher: fetcher)
      session.poll(target: target, processors: group, repeatingEvery: count == 1 ? nil : 0.1)
    }
    return box.value
  }

  @Test
  func payload() async {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockDataFetcher(for: url, return: payload, withStatus: 200)
    let result = await waitForResult(fetcher: fetcher)
    #expect(result as? ExamplePayload == payload)
  }

  @Test
  func error() async {
    let error = ExampleError(message: "oops", details: "something bad happened")
    let fetcher = MockDataFetcher(for: url, return: error, withStatus: 404)
    let result = await waitForResult(fetcher: fetcher)
    #expect(result as? ExampleError == error)
  }

  @Test
  func unknownResponse() async {
    let fetcher = MockDataFetcher(for: url, return: "blah", withStatus: 303)
    let result = await waitForResult(fetcher: fetcher)
    #expect(result as? String == "Unexpected Result")
  }

  @Test
  func polling() async {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockDataFetcher(for: url, return: payload, withStatus: 200)
    let result = await waitForResult(fetcher: fetcher, count: 3)
    #expect(result as? ExamplePayload == payload)
  }

  @Test
  func processorAsGroup() async {
    let payload = ExamplePayload(name: "test")
    let fetcher = MockDataFetcher(for: url, return: payload, withStatus: 200)
    let box = ResultBox()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      let processor = PayloadProcessor { value in
        Task { @MainActor in
          box.value = value
          continuation.resume()
        }
        return .cancel
      }
      let session = Session(base: base, token: "", fetcher: fetcher)
      session.poll(target: target, processors: processor)
    }
    let result = box.value
    #expect(result as? ExamplePayload == payload)
  }
}
