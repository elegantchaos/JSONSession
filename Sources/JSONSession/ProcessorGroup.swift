// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol ProcessorGroup {
    var name: String { get }
    var processors: [ProcessorBase] { get }

    func path(for target: Target, in session: Session) -> String
    func decode(response: HTTPURLResponse, data: Data, in session: Session) throws -> RepeatStatus
    func unprocessed(response: HTTPURLResponse, data: Data, in session: Session) throws -> RepeatStatus
}

public extension ProcessorGroup {
    func path(for target: Target, in session: Session) -> String {
        return target.path(in: session)
    }
    
    func decode(response: HTTPURLResponse, data: Data, in session: Session) throws -> RepeatStatus {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let code = response.statusCode
        for processor in processors {
            if processor.codes.contains(code) {
                do {
                    let decoded = try processor.decode(data: data, with: decoder)
                    let status = processor.process(decoded: decoded, response: response, in: session)
                    sessionChannel.log("Processed \(name) with \(processor.name). Repeat status: \(status).")
                    return status
                } catch {
                    sessionChannel.log("Error thrown:\n- query: \(name)\n- target: \(response.url!)\n- processor: \(processor.name)\n- error: \(error)\n")
                }
            }
        }
        
        return try unprocessed(response: response, data: data, in: session)
    }
    
    func unprocessed(response: HTTPURLResponse, data: Data, in session: Session) throws -> RepeatStatus {
        throw Session.Errors.unexpectedResponse(response.statusCode)
    }

}
