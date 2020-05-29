// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 27/05/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Logger

public let networkingChannel = Channel("com.elegantchaos.jsonsession.networking")

public struct Context {
    public let endpoint: URL
    public let token: String
    
    public init(endpoint: URL, token: String) {
        self.endpoint = endpoint
        self.token = token
    }
}
