import Foundation

struct NormalizedURL {
    enum ValidationError: LocalizedError, Equatable {
        case invalidURL
        case unsupportedScheme
        case missingHost

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                "Enter a valid web address."
            case .unsupportedScheme:
                "Only HTTP and HTTPS links are supported."
            case .missingHost:
                "The web address needs a domain."
            }
        }
    }

    let url: URL
    let string: String

    init(_ value: String) throws {
        guard var components = URLComponents(string: value) else {
            throw ValidationError.invalidURL
        }
        guard let rawScheme = components.scheme else {
            throw ValidationError.invalidURL
        }
        let scheme = rawScheme.lowercased()
        guard scheme == "http" || scheme == "https" else {
            throw ValidationError.unsupportedScheme
        }
        guard let rawHost = components.host, !rawHost.isEmpty else {
            throw ValidationError.missingHost
        }
        guard let originalURL = components.url else {
            throw ValidationError.invalidURL
        }

        components.scheme = scheme
        components.host = rawHost.lowercased()
        if (scheme == "http" && components.port == 80)
            || (scheme == "https" && components.port == 443) {
            components.port = nil
        }
        components.fragment = nil
        if components.path.isEmpty {
            components.path = "/"
        }

        if let queryItems = components.queryItems {
            let meaningfulItems = queryItems.filter { item in
                let name = item.name.lowercased()
                return !name.hasPrefix("utm_") && name != "fbclid" && name != "gclid"
            }
            components.queryItems = meaningfulItems.isEmpty ? nil : meaningfulItems
        }

        guard let normalizedURL = components.url else {
            throw ValidationError.invalidURL
        }
        url = originalURL
        string = normalizedURL.absoluteString
    }
}

