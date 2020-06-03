import XCTest
import DataFetcher

@testable import JSONSession

final class JSONSessionTests: XCTestCase {
    var result: Any?
    var resultExpectation: XCTestExpectation!
    let target = FixedTarget("blah")
    let endpoint = URL(string: "https://api.github.com")!
    var url: URL { endpoint.appendingPathComponent(target.path) }

    struct ExamplePayload: Codable, Equatable {
        let name: String
    }
    
    struct ExampleError: Codable, Equatable {
        let message: String
        let details: String
    }
    
    struct PayloadProcessor: Processor {
        typealias Payload = ExamplePayload
        var name = "Test"
        var codes: [Int] = [200]
        var callback: (ExamplePayload) -> Void
        
        func process(decoded: Decodable, response: HTTPURLResponse, in session: Session) -> RepeatStatus {
            callback(decoded as! ExamplePayload)
            return .inherited
        }
    }

    struct ErrorProcessor: Processor {
        typealias Payload = ExampleError
        let name = "Test"
        let codes: [Int] = [404]
        var callback: (ExampleError) -> Void
        
        func process(decoded: Decodable, response: HTTPURLResponse, in session: Session) -> RepeatStatus {
            callback(decoded as! ExampleError)
            return .inherited
        }
    }

    class Group: ProcessorGroup {
        let name = "Example Group"
        let processors: [ProcessorBase]
        let gotResult: (Any) -> Void
        
        init(test: JSONSessionTests, target: Int) {
            var count = 0
            let gotResult: (Any) -> Void = { result in
                count += 1
                if count == target {
                    test.gotResult(result)
                }
            }

            self.gotResult = gotResult
            self.processors = [
                PayloadProcessor() { gotResult($0) },
                ErrorProcessor() { gotResult($0) }
            ]
        }
        
        
        func unprocessed(response: HTTPURLResponse, data: Data, in session: Session) throws -> RepeatStatus {
            gotResult("Unprocessed")
            return .inherited
        }
    }
    
    func gotResult(_ result: Any) {
        self.result = result
        resultExpectation.fulfill()
    }
    
    func waitForResult(fetcher: DataFetcher, count: Int = 1) {
        let group = Group(test: self, target: count)
        let session = Session(endpoint: endpoint, token: "", fetcher: fetcher)
        session.schedule(target: target, processors: group, repeatingEvery: count == 1 ? nil : 0.1)
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
        XCTAssertEqual(result as? String, "Unprocessed")
    }
    
    func testPolling() {
        let payload = ExamplePayload(name: "test")
        let fetcher = MockDataFetcher(for: url, return: payload, withStatus: 200)
        waitForResult(fetcher: fetcher, count: 3)
        XCTAssertEqual(result as? ExamplePayload, payload)
    }
}
