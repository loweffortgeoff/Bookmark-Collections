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

    /// Text a person typed or pasted, with `https://` added when it reads as
    /// a bare web address ("example.com"). Share capture does not use this:
    /// shared items already carry a scheme.
    static func userEntered(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // "a@b.com" would parse as a host with a user name, so it is not an
        // address to fix up.
        guard !trimmed.contains("://"),
              !trimmed.contains("@"),
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return trimmed
        }
        // The host must end in a letters-only label of two or more letters.
        // That keeps "v1.2" and "3.14" in a pasted list out of the library.
        let host = trimmed.prefix { !"/?#:".contains($0) }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              let last = labels.last, last.count >= 2,
              last.allSatisfy(\.isLetter) else {
            return trimmed
        }
        // "mailto:a@b.com" has a real scheme and stays as typed, so it gets
        // the unsupported-scheme message. "example.com:8080" parses with the
        // host as its scheme; a scheme with a dot is a host.
        if let scheme = URLComponents(string: trimmed)?.scheme, !scheme.contains(".") {
            return trimmed
        }
        return "https://" + trimmed
    }

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

