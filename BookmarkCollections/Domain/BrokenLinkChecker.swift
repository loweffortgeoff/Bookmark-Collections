import Foundation
import Network
import os
import SwiftData

struct LinkCheckTarget: Identifiable, Equatable, Sendable {
    let id: PersistentIdentifier
    let url: URL
    let title: String
    let domain: String
}

enum LinkCheckReason: Equatable, Sendable {
    case notFound
    case gone
    case hostNotFound
    case invalidAddress

    var localizedDescription: String {
        switch self {
        case .notFound: String(localized: "Page not found (404)")
        case .gone: String(localized: "Page removed (410)")
        case .hostNotFound: String(localized: "Server not found")
        case .invalidAddress: String(localized: "Invalid web address")
        }
    }
}

struct BrokenLinkFinding: Identifiable, Equatable, Sendable {
    let id: PersistentIdentifier
    let url: URL
    let title: String
    let domain: String
    let reason: LinkCheckReason
}

struct BrokenLinkSweepProgress: Equatable, Sendable {
    let checked: Int
    let total: Int
}

struct BrokenLinkSweepResult: Equatable, Sendable {
    let totalChecked: Int
    let uncertainCount: Int
    let findings: [BrokenLinkFinding]
    let abortedOffline: Bool
    let wasCancelled: Bool
}

/// Manual dead-link sweep. Flags only clear signals (404, 410, DNS failure, invalid address).
/// Everything ambiguous (auth walls, rate limits, 5xx, timeouts, TLS) gets the benefit of the doubt.
struct BrokenLinkChecker: Sendable {
    typealias RequestPerformer = @Sendable (URLRequest) async throws -> Int
    typealias ConnectivityCheck = @Sendable () async -> Bool

    private let performRequest: RequestPerformer
    private let isOnline: ConnectivityCheck
    /// Confirms real internet access against a known-good endpoint before any
    /// "Server not found" result is trusted (captive portal, broken VPN DNS).
    private let isInternetReachable: ConnectivityCheck

    init(
        performRequest: @escaping RequestPerformer = BrokenLinkChecker.defaultPerformer(),
        isOnline: @escaping ConnectivityCheck = BrokenLinkChecker.defaultConnectivityCheck,
        isInternetReachable: @escaping ConnectivityCheck = BrokenLinkChecker.defaultInternetProbe
    ) {
        self.performRequest = performRequest
        self.isOnline = isOnline
        self.isInternetReachable = isInternetReachable
    }

    /// The bookmark behind a finding, or nil when its row no longer exists
    /// (deleted or merged away while the review sheet was open).
    @MainActor
    static func liveBookmark(with id: PersistentIdentifier, in context: ModelContext) -> Bookmark? {
        // A fetch, not model(for:): that returns an instance even for a
        // deleted row, and touching it then faults.
        var descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    static func targets(from bookmarks: [Bookmark]) -> [LinkCheckTarget] {
        bookmarks.compactMap { bookmark in
            guard bookmark.kind == .link, bookmark.deletedAt == nil,
                  let url = URL(string: bookmark.urlString.trimmingCharacters(in: .whitespacesAndNewlines))
            else { return nil }
            return LinkCheckTarget(
                id: bookmark.persistentModelID,
                url: url,
                title: bookmark.title,
                domain: bookmark.domain.isEmpty ? (url.host() ?? "") : bookmark.domain
            )
        }
    }

    func check(
        _ targets: [LinkCheckTarget],
        maxConcurrency: Int = 6,
        onProgress: @escaping @Sendable (BrokenLinkSweepProgress) async -> Void
    ) async -> BrokenLinkSweepResult {
        let total = targets.count
        guard total > 0 else {
            return BrokenLinkSweepResult(totalChecked: 0, uncertainCount: 0, findings: [], abortedOffline: false, wasCancelled: false)
        }
        guard await isOnline() else {
            return BrokenLinkSweepResult(totalChecked: 0, uncertainCount: 0, findings: [], abortedOffline: true, wasCancelled: Task.isCancelled)
        }
        if Task.isCancelled {
            return BrokenLinkSweepResult(totalChecked: 0, uncertainCount: 0, findings: [], abortedOffline: false, wasCancelled: true)
        }

        await onProgress(BrokenLinkSweepProgress(checked: 0, total: total))

        let distinctHostTotal = Set(targets.map(Self.host(of:))).count
        // Probe once the DNS failures could be a storm: five distinct hosts,
        // or every host in a smaller library.
        let probeThreshold = max(1, min(5, distinctHostTotal))
        var checked = 0
        var uncertainCount = 0
        var findings: [BrokenLinkFinding] = []
        var hostNotFoundHosts: Set<String> = []
        var internetConfirmed: Bool?
        var abortedOffline = false

        await withTaskGroup(of: (LinkCheckTarget, Outcome).self) { group in
            var pending = targets.makeIterator()
            for _ in 0..<max(1, maxConcurrency) {
                guard let target = pending.next() else { break }
                group.addTask { (target, await outcome(for: target)) }
            }

            while let (target, result) = await group.next() {
                guard !abortedOffline else { continue }

                switch result {
                case .offline:
                    abortedOffline = true
                    group.cancelAll()
                    continue
                case .cancelled:
                    continue
                case .reachable:
                    break
                case .broken(let reason):
                    findings.append(BrokenLinkFinding(
                        id: target.id, url: target.url, title: target.title, domain: target.domain, reason: reason
                    ))
                    if reason == .hostNotFound { hostNotFoundHosts.insert(Self.host(of: target)) }
                case .uncertain:
                    uncertainCount += 1
                }

                checked += 1
                await onProgress(BrokenLinkSweepProgress(checked: checked, total: total))

                // Captive portal or broken DNS makes every lookup fail. Confirm
                // the internet works before trusting "Server not found".
                if internetConfirmed == nil, hostNotFoundHosts.count >= probeThreshold {
                    internetConfirmed = await isInternetReachable()
                    if internetConfirmed == false {
                        abortedOffline = true
                        group.cancelAll()
                        continue
                    }
                }

                if !Task.isCancelled, let next = pending.next() {
                    group.addTask { (next, await outcome(for: next)) }
                }
            }
        }

        // Any remaining DNS finding is trusted only after the probe succeeds.
        if !abortedOffline, !Task.isCancelled, internetConfirmed == nil, !hostNotFoundHosts.isEmpty {
            abortedOffline = await isInternetReachable() == false
        }

        if abortedOffline {
            return BrokenLinkSweepResult(
                totalChecked: checked, uncertainCount: uncertainCount, findings: [], abortedOffline: true, wasCancelled: false
            )
        }
        return BrokenLinkSweepResult(
            totalChecked: checked,
            uncertainCount: uncertainCount,
            findings: findings,
            abortedOffline: false,
            wasCancelled: Task.isCancelled
        )
    }
}

// MARK: - Classification

private extension BrokenLinkChecker {
    enum Outcome: Sendable {
        case reachable
        case broken(LinkCheckReason)
        /// `gotResponse` is true when a server answered (so the network itself works).
        case uncertain(gotResponse: Bool)
        case offline
        case cancelled
    }

    enum StatusVerdict {
        case reachable
        case broken(LinkCheckReason)
        case retryWithGET
        case uncertain
    }

    static func host(of target: LinkCheckTarget) -> String {
        (target.url.host() ?? target.domain).lowercased()
    }

    static func verdict(forStatus status: Int, method: String) -> StatusVerdict {
        switch status {
        case 200...399: .reachable
        case 404: .broken(.notFound)
        case 410: .broken(.gone)
        case 405, 501: method == "HEAD" ? .retryWithGET : .uncertain
        default: .uncertain
        }
    }

    static func outcome(forError error: Error) -> Outcome {
        if error is CancellationError { return .cancelled }
        guard let urlError = error as? URLError else { return .uncertain(gotResponse: false) }
        switch urlError.code {
        case .cancelled:
            return Task.isCancelled ? .cancelled : .uncertain(gotResponse: false)
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            return .offline
        case .networkConnectionLost:
            // One server dropping a connection is not the device going offline.
            return .uncertain(gotResponse: false)
        case .cannotFindHost, .dnsLookupFailed:
            return .broken(.hostNotFound)
        case .badURL, .unsupportedURL:
            return .broken(.invalidAddress)
        default:
            return .uncertain(gotResponse: false)
        }
    }

    func outcome(for target: LinkCheckTarget) async -> Outcome {
        if Task.isCancelled { return .cancelled }

        var head = URLRequest(url: target.url)
        head.httpMethod = "HEAD"

        do {
            let status = try await performRequest(head)
            switch Self.verdict(forStatus: status, method: "HEAD") {
            case .reachable: return .reachable
            case .uncertain: return .uncertain(gotResponse: true)
            case .broken, .retryWithGET:
                // Some servers answer HEAD with 404 while the page loads.
                // Confirm with a GET before flagging, since findings feed Move All.
                var get = URLRequest(url: target.url)
                get.httpMethod = "GET"
                get.setValue("bytes=0-0", forHTTPHeaderField: "Range")
                let getStatus = try await performRequest(get)
                switch Self.verdict(forStatus: getStatus, method: "GET") {
                case .reachable: return .reachable
                case .broken(let reason): return .broken(reason)
                case .uncertain, .retryWithGET: return .uncertain(gotResponse: true)
                }
            }
        } catch {
            return Self.outcome(forError: error)
        }
    }
}

// MARK: - Production defaults

extension BrokenLinkChecker {
    /// Waits for the first `NWPathMonitor` update. If none arrives in ~1.5 s, assume online and let the
    /// requests themselves decide (offline errors abort the sweep).
    @Sendable
    static func defaultConnectivityCheck() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let gate = OSAllocatedUnfairLock<CheckedContinuation<Bool, Never>?>(initialState: continuation)
            let monitor = NWPathMonitor()
            let finish: @Sendable (Bool) -> Void = { value in
                let pending = gate.withLock { state -> CheckedContinuation<Bool, Never>? in
                    defer { state = nil }
                    return state
                }
                pending?.resume(returning: value)
                monitor.cancel()
            }
            monitor.pathUpdateHandler = { path in finish(path.status == .satisfied) }
            let queue = DispatchQueue(label: "BrokenLinkChecker.connectivity")
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 1.5) { finish(true) }
        }
    }

    /// Apple's captive-portal check: a working internet connection returns a
    /// page containing "Success". Anything else means DNS failures are not
    /// evidence against the links.
    @Sendable
    static func defaultInternetProbe() async -> Bool {
        guard let url = URL(string: "https://captive.apple.com/hotspot-detect.html") else { return false }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
        return String(decoding: data, as: UTF8.self).contains("Success")
    }

    /// One ephemeral session per request, because the per-task delegate of `URLSession.data(for:delegate:)`
    /// does not receive `didReceive response`. A session-level delegate does, which lets GET fallbacks
    /// cancel right after the headers instead of downloading the body.
    static func defaultPerformer() -> RequestPerformer {
        { request in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 10
            configuration.timeoutIntervalForResource = 15
            configuration.waitsForConnectivity = false

            let delegate = StatusCaptureDelegate(cancelsBody: request.httpMethod == "GET")
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            defer { session.finishTasksAndInvalidate() }
            let task = session.dataTask(with: request)

            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    delegate.install(continuation)
                    task.resume()
                }
            } onCancel: {
                task.cancel()
            }
        }
    }
}

/// Captures the HTTP status from the response headers and resumes a single continuation exactly once.
private final class StatusCaptureDelegate: NSObject, URLSessionDataDelegate, Sendable {
    private struct State {
        var continuation: CheckedContinuation<Int, Error>?
        var status: Int?
        var result: Result<Int, Error>?
    }

    private let cancelsBody: Bool
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(cancelsBody: Bool) {
        self.cancelsBody = cancelsBody
    }

    func install(_ continuation: CheckedContinuation<Int, Error>) {
        let ready = state.withLock { state -> Result<Int, Error>? in
            if let result = state.result { return result }
            state.continuation = continuation
            return nil
        }
        if let ready { continuation.resume(with: ready) }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse {
            state.withLock { $0.status = http.statusCode }
        }
        completionHandler(cancelsBody ? .cancel : .allow)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let (continuation, result) = state.withLock { state -> (CheckedContinuation<Int, Error>?, Result<Int, Error>) in
            // A GET body cancelled after the headers still counts as a successful status read.
            let result: Result<Int, Error>
            if let status = state.status {
                result = .success(status)
            } else {
                result = .failure(error ?? URLError(.badServerResponse))
            }
            state.result = result
            let continuation = state.continuation
            state.continuation = nil
            return (continuation, result)
        }
        continuation?.resume(with: result)
    }
}
