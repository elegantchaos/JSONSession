[comment]: <> (Header Generated by ActionStatus 1.0.2 - 320)

[![Test results][tests shield]][actions] [![Latest release][release shield]][releases] [![swift 5.3 shield] ![swift dev shield]][swift] ![Platforms: macOS, iOS, tvOS, Linux][platforms shield]

[release shield]: https://img.shields.io/github/v/release/elegantchaos/JSONSession
[platforms shield]: https://img.shields.io/badge/platforms-macOS_iOS_tvOS_Linux-lightgrey.svg?style=flat "macOS, iOS, tvOS, Linux"
[tests shield]: https://github.com/elegantchaos/JSONSession/workflows/Tests/badge.svg
[swift 5.3 shield]: https://img.shields.io/badge/swift-5.3-F05138.svg "Swift 5.3"
[swift dev shield]: https://img.shields.io/badge/swift-dev-F05138.svg "Swift dev"

[swift]: https://swift.org
[releases]: https://github.com/elegantchaos/JSONSession/releases
[actions]: https://github.com/elegantchaos/JSONSession/actions

[comment]: <> (End of ActionStatus Header)

# JSONSession

Support for periodic polling of a server endpoint.

Authentication is passed in the `Authorization` header, as `bearer <token>`. 

The response is expected to contain an `Etag` header field, which represents the current state of the endpoint, and is passed back to the server with subsequent requests.

This mechanism allows efficient polling of the server for changes, and can be a workaround for rate-limiting (where requests that didn't pick up any change in state don't count towards the rate limit).

## Parsing Responses

When a request is sent, it is passed a `ProcessorGroup` which contains a list of `Processor` objects. 

When a response comes back, it is matched against each `Processor` in turn, matching against the HTTP status code. If a processor supports the code, it is given a chance to decode the response. 

If a processor fails to decode the response (throws an error), matching is continued unless the list of processors is exhausted. The first successful match ends this process. If all processors are exhausted without success, then the `unprocessed` method of the `ProcessorGroup` is called; this can be used for catch-all error handling.


### Requirements

The `swift-tools-version` requirement is set to Swift 5, as the Foundation Networking API isn't quite right on Linux prior to 5.3. 

Strictly speaking the code works with Swift 5.2 on Apple platforms, though it requires a fairly modern SDK.

### Made For Github

This is a generalisation of some code I built to access the Github API, and is used by [Octoid](https://github.com/elegantchaos/Octoid) which is a more general Github library.

I split out the JSONSession functionality because I imagined that other servers may use the same mechanism. This may be an incorrect assumption, and/or this code may need to be generalised further to work with other servers. If so, let me know via an issue.
