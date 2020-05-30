import XCTest
@testable import JSONSession

final class JSONSessionTests: XCTestCase {
    struct A: Codable {
        let name: String
    }
    
    struct AProcessor: Processor {
        var response: JSONSessionTests.A?
        
        func process(decoded: Decodable, response: HTTPURLResponse, in session: Session) -> RepeatStatus {
            return .inherited
        }
        
        typealias Payload = A
        var name = "Test"
        var codes: [Int] = [200]
    }
    
    struct Group: ProcessorGroup {
        var name = "Test"
        
        var processors: [ProcessorBase] = [AProcessor()]
    }
    
    func testExample() {
        let url = URL(string: "https://api.github.com")!
        let session = Session(endpoint: url, token: "", fetcher: MockDataFetcher())
        let target = FixedTarget("target")
        let group = Group()
        
        session.fetcher = MockDataFetcher()
        session.schedule(target: target, processors: group)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
