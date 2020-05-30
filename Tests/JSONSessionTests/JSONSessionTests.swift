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
        let x = expectation(description: "Decoded")
        let url = URL(string: "https://api.github.com")!
        let fetcher = MockDataFetcher(output: [
            url: .string("{ 'name': 'test' }", 200)
        ])
        let session = Session(endpoint: url, token: "", fetcher: fetcher)
        let target = FixedTarget("target")
        var decoded: A? = nil
        let group = Group() { d in
            decoded = d
            x.fulfill()
        }
        
        session.schedule(target: target, processors: group)
        wait(for: [x], timeout: 1.0)
        XCTAssertEqual(decoded?.name, "Test")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
