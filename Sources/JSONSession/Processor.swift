// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 28/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

public enum RepeatStatus {
    case inherit
    case request
    case cancel
}

public protocol ProcessorBase {
    var name: String { get }
    var codes: [Int] { get }
    var payloadType: Decodable.Type { get }
    func decode(data: Data) throws -> Decodable
    func process(decoded: Decodable, response: HTTPURLResponse, in session: Session) -> RepeatStatus
}

public protocol ProcessorGroup {
    var name: String { get }
    var processors: [ProcessorBase] { get }

    func query(for session: Session) -> Query
    func decode(response: HTTPURLResponse, data: Data, in session: Session) throws -> RepeatStatus
}

public struct SimpleProcessorGroup: ProcessorGroup {
    public let name: String
    public var processors: [ProcessorBase] = []

    public func decode(response: HTTPURLResponse, data: Data, in session: Session) throws -> RepeatStatus {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let code = response.statusCode
        for processor in processors {
            if processor.codes.contains(code) {
                do {
                    let decoded = try processor.decode(data: data)
                    let status = processor.process(decoded: decoded, response: response, in: session)
                    sessionChannel.log("Processed \(name) with \(processor.name). Repeat status: \(status).")
                    return status
                } catch {
                    sessionChannel.log("Error thrown:\n- query: \(name)\n- target: \(response.url!)\n- processor: \(processor.name)\n- error: \(error)\n")
                }
            }
        }
        
        throw Session.Errors.unexpectedResponse(response.statusCode)
    }
    
    public func query(for session: Session) -> Query {
        return Query(name: "test", query: { _ in "test" })
    }

}
public protocol Processor: ProcessorBase {
    associatedtype Payload: Decodable
    var response: Payload? { get set }
    
    func process(state: ResponseState, response: Payload, in session: Session) -> Bool
}

public extension Processor {
    
    fileprivate func decode(data: Data, state: ResponseState, in session: Session) throws -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Payload.self, from: data)
        return process(state: state, response: decoded, in: session)
    }
    
    fileprivate func decodeError(_ data: Data) throws -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let error = try decoder.decode(Failure.self, from: data)
        if !error.canIgnore {
            throw Session.Errors.apiError(error)
        }
        
        return false
    }
}
