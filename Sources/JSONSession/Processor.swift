// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 28/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum RepeatStatus {
    case request
    case cancel
    case inherited
}

public protocol ProcessorBase: ProcessorGroup {
    var name: String { get }
    var codes: [Int] { get }
    func decode(data: Data, with decoder: JSONDecoder) throws -> Decodable
    func process(decoded: Decodable, response: HTTPURLResponse, for request: Request, in session: Session) -> RepeatStatus
}

extension ProcessorBase {
    var name: String { "untitled" }
    var processors: [ProcessorBase] { return [self] }
}

public protocol Processor: ProcessorBase {
    associatedtype Payload: Decodable
    associatedtype SessionType: Session
    func process(_ payload: Payload, response: HTTPURLResponse, for request: Request, in session: SessionType) -> RepeatStatus
}

public extension Processor {
    func decode(data: Data, with decoder: JSONDecoder) throws -> Decodable {
        return try decoder.decode(Payload.self, from: data)
    }
    
    func process(decoded: Decodable, response: HTTPURLResponse, for request: Request, in session: Session) -> RepeatStatus {
        return process(decoded as! Payload, response: response, for: request, in: session as! SessionType)
    }
}

