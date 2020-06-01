// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 28/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

public enum RepeatStatus {
    case request
    case cancel
    case inherited

    func shouldRepeat(current: Bool) -> Bool {
        switch self {
            case .request: return true
            case .cancel: return false
            case .inherited: return current
        }
    }
}

public protocol ProcessorBase {
    var name: String { get }
    var codes: [Int] { get }
    func decode(data: Data, with decoder: JSONDecoder) throws -> Decodable
    func process(decoded: Decodable, response: HTTPURLResponse, in session: Session) -> RepeatStatus
}

public protocol Processor: ProcessorBase {
    associatedtype Payload: Decodable
}

public extension Processor {
    func decode(data: Data, with decoder: JSONDecoder) throws -> Decodable {
        return try decoder.decode(Payload.self, from: data)
    }
 }
