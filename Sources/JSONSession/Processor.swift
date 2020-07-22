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

    func shouldRepeat(current: Bool) -> Bool {
        switch self {
            case .request:      return true
            case .cancel:       return false
            case .inherited:    return current
        }
    }
}

public protocol ProcessorBase: ProcessorGroup {
    var name: String { get }
    var codes: [Int] { get }
    func decode(data: Data, with decoder: JSONDecoder) throws -> Decodable
    func process(decoded: Decodable, response: HTTPURLResponse, in session: Session) -> RepeatStatus
}

extension ProcessorBase {
    var processors: [ProcessorBase] { return [self] }
}

public protocol Processor: ProcessorBase {
    associatedtype Payload: Decodable
    associatedtype SessionType: Session
    func process(_ payload: Payload, response: HTTPURLResponse, in session: SessionType) -> RepeatStatus
}

public extension Processor {
    func decode(data: Data, with decoder: JSONDecoder) throws -> Decodable {
        return try decoder.decode(Payload.self, from: data)
    }
    
    func process(decoded: Decodable, response: HTTPURLResponse, in session: Session) -> RepeatStatus {
        return process(decoded as! Payload, response: response, in: session as! SessionType)
    }
}

