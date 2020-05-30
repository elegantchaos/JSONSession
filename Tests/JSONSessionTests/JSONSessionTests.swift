import XCTest
@testable import JSONSession

final class JSONSessionTests: XCTestCase {
    struct A: Codable {
        let name: String
    }
    
    struct AProcessor: Processor {
        var response: JSONSessionTests.A?
        var callback: (A) -> Void
        
        func process(decoded: Decodable, response: HTTPURLResponse, in session: Session) -> RepeatStatus {
            callback(decoded as! A)
            return .inherited
        }
        
        typealias Payload = A
        var name = "Test"
        var codes: [Int] = [200]
    }
    
    struct Group: ProcessorGroup {
        var name = "Test"
        var callback: (A) -> Void
        var processors: [ProcessorBase]
        
        init(callback: @escaping (A) -> Void) {
            self.callback = callback
            self.processors = [AProcessor(callback: callback)]
        }
    }
    
    func testExample() {
        let a = A(name: "test")
        let encoder = JSONEncoder()
        let json = try! encoder.encode(a)
        let x = expectation(description: "Decoded")
        let target = FixedTarget("blah")
        let endpoint = URL(string: "https://api.github.com")!
        let url = endpoint.appendingPathComponent(target.path)
        let fetcher = MockDataFetcher(output: [
            url : .init(for: 200, return: json)
        ])
        let session = Session(endpoint: endpoint, token: "", fetcher: fetcher)
        var decoded: A? = nil
        let group = Group() { d in
            decoded = d
            x.fulfill()
        }
        
        session.schedule(target: target, processors: group)
        wait(for: [x], timeout: 1.0)
        XCTAssertEqual(decoded?.name, "test")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
