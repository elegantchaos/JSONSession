// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 27/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

public struct Target {
    public let name: String
    public let owner: String
    public let workflow: String
    
    public init(name: String, owner: String, workflow: String) {
        self.name = name
        self.owner = owner
        self.workflow = workflow
    }
    
    public var fullName: String { return "\(owner)/\(name):\(workflow)" }

}

extension Target: CustomStringConvertible {
    public var description: String {
        return fullName
    }
}
