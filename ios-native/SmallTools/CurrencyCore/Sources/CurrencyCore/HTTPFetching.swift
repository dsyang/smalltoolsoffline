import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fetches the body of a GET request. Injected so rate loading can run without the network.
public protocol HTTPFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

/// Production fetcher backed by URLSession.shared. Non-2xx responses throw, so an
/// error page is never parsed as rates.
public struct URLSessionFetcher: HTTPFetching {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    public func data(from url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.badStatus(http.statusCode)
        }
        return data
    }
}

private enum FetchError: Error {
    case badStatus(Int)
}
