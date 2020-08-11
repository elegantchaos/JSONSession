import XCTest
import DataFetcher

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@testable import JSONSession

final class JSONSessionTests: XCTestCase {
    var result: Any?
    var resultExpectation: XCTestExpectation!
    let target = Resource("blah")
    let base = URL(string: "https://api.github.com")!
    var url: URL { base.appendingPathComponent(target.path) }

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
        
        func process(_ payload: ExamplePayload, response: HTTPURLResponse, for request: Request, in session: Session) -> RepeatStatus {
            return callback(payload)
        }
    }

    struct ErrorProcessor: Processor {
        let name = "Test"
        let codes: [Int] = [404]
        var callback: (ExampleError) -> Void
        
        func process(_ payload: ExampleError, response: HTTPURLResponse, for request: Request, in session: Session) -> RepeatStatus {
            callback(payload)
            return .inherited
        }
    }

    struct CatchAllProcessor: ProcessorBase {
        var codes: [Int] = []
        var callback: () -> Void

        func process(decoded: Decodable, response: HTTPURLResponse, for request: Request, in session: Session) -> RepeatStatus {
            callback()
            return .inherited
        }

        func decode(data: Data, with decoder: JSONDecoder) throws -> Decodable {
            return data
        }
    }
    
    class Group: ProcessorGroup {
        let name = "Example Group"
        let processors: [ProcessorBase]
        let gotResult: (Any) -> RepeatStatus
        
        init(target: Int, done: @escaping (Any) -> Void) {
            var count = 0
            let gotResult: (Any) -> RepeatStatus = { result in
                count += 1
                if count == target {
                    DispatchQueue.main.async {
                        done(result)
                    }
                    return .cancel
                } else {
                    return .request
                }
            }

            self.gotResult = gotResult
            self.processors = [
                PayloadProcessor() { return gotResult($0) },
                ErrorProcessor() { _ = gotResult($0) },
                CatchAllProcessor() { _ = gotResult( "Unexpected Result" ) }
            ]
        }
    }
    
    func gotResult(_ result: Any) {
        self.result = result
        resultExpectation.fulfill()
    }
    
    func waitForResult(fetcher: DataFetcher, count: Int = 1) {
        let group = Group(target: count) { result in self.gotResult(result) }
        waitForResult(fetcher: fetcher, group: group, count: count)
    }

    func waitForResult(fetcher: DataFetcher, group: ProcessorGroup, count: Int = 1) {
        let session = Session(base: base, token: "", fetcher: fetcher)
        session.poll(target: target, processors: group, repeatingEvery: count == 1 ? nil : 0.1)
        resultExpectation = expectation(description: "Got Result")
        wait(for: [resultExpectation], timeout: 1.0)
    }

    func testPayload() {
        let payload = ExamplePayload(name: "test")
        let fetcher = MockDataFetcher(for: url, return: payload, withStatus: 200)
        waitForResult(fetcher: fetcher)
        XCTAssertEqual(result as? ExamplePayload, payload)
    }

    func testError() {
        let error = ExampleError(message: "oops", details: "something bad happened")
        let fetcher = MockDataFetcher(for: url, return: error, withStatus: 404)
        waitForResult(fetcher: fetcher)
        XCTAssertEqual(result as? ExampleError, error)
    }

    func testUnknownResponse() {
        let fetcher = MockDataFetcher(for: url, return: "blah", withStatus: 303)
        waitForResult(fetcher: fetcher)
        XCTAssertEqual(result as? String, "Unexpected Result")
    }
    
    func testPolling() {
        let payload = ExamplePayload(name: "test")
        let fetcher = MockDataFetcher(for: url, return: payload, withStatus: 200)
        waitForResult(fetcher: fetcher, count: 3)
        XCTAssertEqual(result as? ExamplePayload, payload)
    }
    
    func testProcessorAsGroup() {
        let payload = ExamplePayload(name: "test")
        let processor = PayloadProcessor() { result in
            self.gotResult(result)
            return .cancel
        }
        
        let fetcher = MockDataFetcher(for: url, return: payload, withStatus: 200)
        waitForResult(fetcher: fetcher, group: processor)
        XCTAssertEqual(result as? ExamplePayload, payload)
    }

}
