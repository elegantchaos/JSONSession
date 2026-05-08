// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 08/05/2026.
//  All code (c) 2026 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Parsed rate-limit information advertised by an HTTP API response.
public struct RateLimitSnapshot: Sendable, Equatable {
  /// Total request budget for the current rate-limit window.
  public let limit: Int?
  /// Requests remaining in the current rate-limit window.
  public let remaining: Int?
  /// Requests already used in the current rate-limit window.
  public let used: Int?
  /// Time when the current rate-limit window resets.
  public let resetDate: Date?
  /// Named rate-limit resource bucket, when the API reports one.
  public let resource: String?
  /// Server-requested retry delay in seconds.
  public let retryAfter: TimeInterval?

  /// Creates a parsed rate-limit snapshot.
  public init(
    limit: Int? = nil,
    remaining: Int? = nil,
    used: Int? = nil,
    resetDate: Date? = nil,
    resource: String? = nil,
    retryAfter: TimeInterval? = nil
  ) {
    self.limit = limit
    self.remaining = remaining
    self.used = used
    self.resetDate = resetDate
    self.resource = resource
    self.retryAfter = retryAfter
  }

  /// Whether the response reports that no requests remain in the current window.
  public var isDepleted: Bool {
    remaining == 0
  }

  /// Best retry date derived from `Retry-After` or the rate-limit reset timestamp.
  public func retryDate(relativeTo now: Date = Date()) -> Date? {
    if let retryAfter {
      return now.addingTimeInterval(retryAfter)
    }

    return resetDate
  }
}

/// HTTP response details that are useful to callers after request processing.
public struct HTTPResponseMetadata: Sendable, Equatable {
  /// HTTP status code.
  public let statusCode: Int
  /// Response headers normalized to string values.
  public let headers: [String: String]
  /// Parsed rate-limit information from standard GitHub-style headers.
  public let rateLimit: RateLimitSnapshot?

  /// Creates metadata from a status code and headers.
  public init(statusCode: Int, headers: [String: String]) {
    self.statusCode = statusCode
    self.headers = headers
    self.rateLimit = Self.parseRateLimit(headers: headers)
  }

  /// Creates metadata from an `HTTPURLResponse`.
  public init(response: HTTPURLResponse) {
    self.init(
      statusCode: response.statusCode,
      headers: Self.stringHeaders(from: response)
    )
  }

  /// Returns a header value using case-insensitive field-name matching.
  public func value(forHTTPHeaderField field: String) -> String? {
    if let value = headers[field] {
      return value
    }

    let lowercaseField = field.lowercased()
    return headers.first { $0.key.lowercased() == lowercaseField }?.value
  }

  /// Converts response headers to string-keyed and string-valued storage.
  private static func stringHeaders(from response: HTTPURLResponse) -> [String: String] {
    Dictionary(
      uniqueKeysWithValues: response.allHeaderFields.compactMap { key, value in
        guard let name = key as? String else { return nil }
        return (name, String(describing: value))
      }
    )
  }

  /// Parses standard GitHub-style rate-limit response headers.
  private static func parseRateLimit(headers: [String: String]) -> RateLimitSnapshot? {
    let metadata = HTTPResponseHeaderLookup(headers: headers)
    let limit = metadata.intValue(forHTTPHeaderField: "X-RateLimit-Limit")
    let remaining = metadata.intValue(forHTTPHeaderField: "X-RateLimit-Remaining")
    let used = metadata.intValue(forHTTPHeaderField: "X-RateLimit-Used")
    let resetDate = metadata.unixDateValue(forHTTPHeaderField: "X-RateLimit-Reset")
    let resource = metadata.value(forHTTPHeaderField: "X-RateLimit-Resource")
    let retryAfter = metadata.timeIntervalValue(forHTTPHeaderField: "Retry-After")

    guard
      limit != nil || remaining != nil || used != nil || resetDate != nil || resource != nil
        || retryAfter != nil
    else {
      return nil
    }

    return RateLimitSnapshot(
      limit: limit,
      remaining: remaining,
      used: used,
      resetDate: resetDate,
      resource: resource,
      retryAfter: retryAfter
    )
  }
}

/// Case-insensitive helper for parsing HTTP header dictionaries.
private struct HTTPResponseHeaderLookup {
  /// Header storage with original field names.
  let headers: [String: String]

  /// Returns a header value using case-insensitive field-name matching.
  func value(forHTTPHeaderField field: String) -> String? {
    if let value = headers[field] {
      return value
    }

    let lowercaseField = field.lowercased()
    return headers.first { $0.key.lowercased() == lowercaseField }?.value
  }

  /// Parses an integer header value.
  func intValue(forHTTPHeaderField field: String) -> Int? {
    value(forHTTPHeaderField: field).flatMap(Int.init)
  }

  /// Parses a time interval header value in seconds.
  func timeIntervalValue(forHTTPHeaderField field: String) -> TimeInterval? {
    value(forHTTPHeaderField: field).flatMap(TimeInterval.init)
  }

  /// Parses a Unix timestamp header value into a `Date`.
  func unixDateValue(forHTTPHeaderField field: String) -> Date? {
    timeIntervalValue(forHTTPHeaderField: field).map { Date(timeIntervalSince1970: $0) }
  }
}

extension HTTPURLResponse {
  /// Typed metadata derived from this response.
  public var metadata: HTTPResponseMetadata {
    HTTPResponseMetadata(response: self)
  }
}
