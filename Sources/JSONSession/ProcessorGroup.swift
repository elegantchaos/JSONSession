// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol ProcessorGroup {
    
    /// Name of the resource type we process.
    var name: String { get }
    
    /// Individual processors which match against HTTP responses.
    var processors: [ProcessorBase] { get }
    
    /// Is this group actually a single processor. Used to tailor the logging messages.
    var groupIsProcessor: Bool { get }
    
    /// Path the to resource we process.
    func path(for target: ResourceResolver, in session: Session) -> String
    
    /// Decode a response.
    func decode(response: HTTPURLResponse, data: Data, for request: Request, in session: Session) throws -> RepeatStatus
}

public extension ProcessorGroup {
    var name: String { "untitled group" }   // Default name
    var groupIsProcessor: Bool { false }    // Normally a group contains individual processors.

    func path(for target: ResourceResolver, in session: Session) -> String {
        // By default, just use the target's path
        return target.path(in: session)
    }
    
    func decode(response: HTTPURLResponse, data: Data, for request: Request, in session: Session) throws -> RepeatStatus {
        // Decode the response as JSON, and try to pass it to a processor which handles the http response code.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let code = response.statusCode
        for processor in processors {
            let codes = processor.codes
            if codes.isEmpty || codes.contains(code) {
                do {
                    let decoded = try processor.decode(data: data, with: decoder)
                    let status = processor.process(decoded: decoded, response: response, for: request, in: session)
                    sessionChannel.log(processedMessage(processor: processor, status: status))
                    return status
                } catch {
                    sessionChannel.log("Error thrown:\n- query: \(name)\n- target: \(response.url!)\n- processor: \(processor.name)\n- error: \(error)\n")
                    if let string = String(data: data, encoding: .utf8) {
                        sessionChannel.log("Data was: \(string).")
                    }
                }
            }
        }
        
        // Nothing matched or succeeded.
        throw Session.Errors.unexpectedResponse(response.statusCode)
    }
    
    /// Formatted message for logging.
    fileprivate func processedMessage(processor: ProcessorBase, status: RepeatStatus) -> String {
        let nameInfo = groupIsProcessor ? name : "\(name) using \(processor.name)"
        return "Processed \(nameInfo). Repeat status: \(status)."
    }
}

// For brevity, we can just use a list of processors as a ProcessorGroup.
// It will have a default name, and no special `unprocessed` handler, but for simple
// cases that might be enough.
typealias ProcessorList = [Processor]
extension ProcessorList: ProcessorGroup {
    public var processors: [ProcessorBase] { self }
    public var groupIsProcessor: Bool { true }
}
