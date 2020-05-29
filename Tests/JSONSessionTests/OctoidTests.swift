import XCTest
import XCTestExtensions

@testable import Octoid

final class OctoidTests: XCTestCase {
    func testEventDecoding() {
        let data = self.testData(named: "events", withExtension: "json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let formatter = ISO8601DateFormatter()
        
        let events = try! decoder.decode(Events.self, from: data)
        XCTAssertEqual(events.count, 5)
        
        let event = events.first!
        XCTAssertEqual(event.id, "12444868583")
        XCTAssertEqual(event.type, "PushEvent")
        XCTAssertEqual(event.created_at, formatter.date(from: "2020-05-26T19:06:39Z"))
        
        let actor = event.actor
        XCTAssertEqual(actor.display_login, "samdeane")
        XCTAssertEqual(actor.id, 206306)
        XCTAssertEqual(actor.login, "samdeane")
        XCTAssertEqual(actor.avatar_url, "https://avatars.githubusercontent.com/u/206306?")
        XCTAssertEqual(actor.url, "https://api.github.com/users/samdeane")
        XCTAssertEqual(actor.gravatar_id, "")
    }
    
    func testWorkflowDecoding() {
        let data = self.testData(named: "runs", withExtension: "json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let runs = try! decoder.decode(WorkflowRuns.self, from: data)
        XCTAssertEqual(runs.total_count, 1)
        
        let run = runs.latestRun
        XCTAssertEqual(run.id, 115887997)
        XCTAssertEqual(run.status, "in_progress")
        XCTAssertNil(run.conclusion)
    }
}
