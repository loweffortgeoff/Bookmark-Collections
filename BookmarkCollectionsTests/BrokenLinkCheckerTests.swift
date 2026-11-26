import SwiftData
import XCTest
@testable import BookmarkCollections

private actor RequestLog {
    private(set) var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
        requests.append(request)
    }

    var count: Int { requests.count }
}

private actor ProgressRecorder {
    private(set) var values: [BrokenLinkSweepProgress] = []

    func record(_ progress: BrokenLinkSweepProgress) {
        values.append(progress)
    }
}

private actor InFlightCounter {
    private var current = 0
    private(set) var maximum = 0

    func begin() {
        current += 1
        maximum = max(maximum, current)
    }

    func end() {
        current -= 1
    }
}

@MainActor
final class BrokenLinkCheckerTests: XCTestCase {
    private var container: ModelContainer?

    private func insertBookmark(_ urlString: String, kind: Bookmark.Kind = .link, deleted: Bool = false) throws -> Bookmark {
        let container = try container ?? ModelContainerFactory.make(inMemory: true, cloudKit: false)
        self.container = container
        let bookmark = Bookmark(urlString: urlString, normalizedURLString: urlString)
        bookmark.kind = kind
        bookmark.domain = URL(string: urlString)?.host() ?? ""
        if deleted { bookmark.deletedAt = Date() }
        container.mainContext.insert(bookmark)
        try container.mainContext.save()
        return bookmark
    }

    private func makeTargets(_ urlStrings: [String]) throws -> [LinkCheckTarget] {
        BrokenLinkChecker.targets(from: try urlStrings.map { try insertBookmark($0) })
    }

    private func checker(
        online: Bool = true,
        internetReachable: Bool = true,
        _ perform: @escaping @Sendable (URLRequest) async throws -> Int
    ) -> BrokenLinkChecker {
        BrokenLinkChecker(performRequest: perform, isOnline: { online }, isInternetReachable: { internetReachable })
    }

    // MARK: - Targets

    func testTargetsSelectsOnlyActiveLinkBookmarks() throws {
        let active = try insertBookmark("https://active.example/a")
        _ = try insertBookmark("https://image.example/b", kind: .image)
        _ = try insertBookmark("https://text.example/c", kind: .text)
        _ = try insertBookmark("https://deleted.example/d", deleted: true)
        let allBookmarks = try XCTUnwrap(container).mainContext.fetch(FetchDescriptor<Bookmark>())

        let targets = BrokenLinkChecker.targets(from: allBookmarks)

        XCTAssertEqual(allBookmarks.count, 4)
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.id, active.persistentModelID)
        XCTAssertEqual(targets.first?.url, URL(string: "https://active.example/a"))
        XCTAssertEqual(targets.first?.domain, "active.example")
    }

    // MARK: - Classification

    func testFlags404And410AndDNSFailureAsBroken() async throws {
        let targets = try makeTargets([
            "https://a.example/404",
            "https://b.example/410",
            "https://c.example/dns",
            "https://d.example/lookup",
            "https://e.example/ok",
            "https://f.example/ok",
        ])
        let checker = checker { request in
            switch request.url?.path {
            case "/404": return 404
            case "/410": return 410
            case "/dns": throw URLError(.cannotFindHost)
            case "/lookup": throw URLError(.dnsLookupFailed)
            default: return 200
            }
        }

        let result = await checker.check(targets) { _ in }

        XCTAssertFalse(result.abortedOffline)
        XCTAssertEqual(result.totalChecked, 6)
        XCTAssertEqual(result.uncertainCount, 0)
        let reasons = Dictionary(uniqueKeysWithValues: result.findings.map { ($0.url.path, $0.reason) })
        XCTAssertEqual(reasons, [
            "/404": .notFound,
            "/410": .gone,
            "/dns": .hostNotFound,
            "/lookup": .hostNotFound,
        ])
    }

    func testHEAD404Or410IsConfirmedWithGETBeforeFlagging() async throws {
        let targets = try makeTargets([
            "https://a.example/head404-get200",
            "https://b.example/head410-get206",
            "https://c.example/head404-get404",
        ])
        let log = RequestLog()
        let checker = checker { request in
            await log.append(request)
            let path = request.url?.path ?? ""
            if request.httpMethod == "HEAD" {
                return path.hasPrefix("/head410") ? 410 : 404
            }
            if path.hasSuffix("get200") { return 200 }
            if path.hasSuffix("get206") { return 206 }
            return 404
        }

        let result = await checker.check(targets) { _ in }

        let requests = await log.requests
        XCTAssertEqual(requests.count, 6, "Each HEAD 404/410 gets one confirming GET.")
        XCTAssertTrue(requests.filter { $0.httpMethod == "GET" }.allSatisfy {
            $0.value(forHTTPHeaderField: "Range") == "bytes=0-0"
        })
        XCTAssertEqual(result.findings.map(\.url.path), ["/head404-get404"])
        XCTAssertEqual(result.findings.first?.reason, .notFound)
    }

    func testReviewScreenSaysMovedInsteadOfAllClearAfterMovingFindings() {
        XCTAssertEqual(BrokenLinkCheckView.reviewScreen(remainingFindings: 3, movedCount: 0), .findings)
        XCTAssertEqual(BrokenLinkCheckView.reviewScreen(remainingFindings: 1, movedCount: 2), .findings)
        XCTAssertEqual(BrokenLinkCheckView.reviewScreen(remainingFindings: 0, movedCount: 4), .moved(4))
        XCTAssertEqual(BrokenLinkCheckView.reviewScreen(remainingFindings: 0, movedCount: 0), .allClear)
    }

    func testGivesBenefitOfTheDoubtTo401_403_429_5xx_TimeoutAndTLSErrors() async throws {
        let targets = try makeTargets((0..<9).map { "https://host\($0).example/\($0)" })
        let checker = checker { request in
            switch request.url?.path {
            case "/0": return 401
            case "/1": return 403
            case "/2": return 429
            case "/3": return 500
            case "/4": return 502
            case "/5": return 503
            case "/6": throw URLError(.timedOut)
            case "/7": throw URLError(.secureConnectionFailed)
            default: throw URLError(.serverCertificateUntrusted)
            }
        }

        let result = await checker.check(targets) { _ in }

        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertFalse(result.abortedOffline)
        XCTAssertEqual(result.totalChecked, 9)
        XCTAssertEqual(result.uncertainCount, 9)
    }

    func testFallsBackFromHEADToGETWithRangeHeaderOn405And501() async throws {
        let targets = try makeTargets([
            "https://a.example/head405-get200",
            "https://b.example/head501-get206",
            "https://c.example/head405-get404",
            "https://d.example/head200",
        ])
        let log = RequestLog()
        let checker = checker { request in
            await log.append(request)
            let path = request.url?.path ?? ""
            if request.httpMethod == "HEAD" {
                if path.hasPrefix("/head405") { return 405 }
                if path.hasPrefix("/head501") { return 501 }
                return 200
            }
            if path.hasSuffix("get200") { return 200 }
            if path.hasSuffix("get206") { return 206 }
            return 404
        }

        let result = await checker.check(targets) { _ in }

        let requests = await log.requests
        XCTAssertEqual(requests.count, 7)
        for target in targets {
            let own = requests.filter { $0.url == target.url }
            XCTAssertEqual(own.first?.httpMethod, "HEAD")
            if own.count == 2 {
                XCTAssertEqual(own[1].httpMethod, "GET")
                XCTAssertEqual(own[1].value(forHTTPHeaderField: "Range"), "bytes=0-0")
            }
        }
        XCTAssertEqual(result.findings.count, 1)
        XCTAssertEqual(result.findings.first?.url.path, "/head405-get404")
        XCTAssertEqual(result.findings.first?.reason, .notFound)
        XCTAssertEqual(result.uncertainCount, 0)
        XCTAssertEqual(result.totalChecked, 4)
    }

    // MARK: - Offline handling

    func testAbortsImmediatelyWhenOfflineWithoutFlaggingLinks() async throws {
        let targets = try makeTargets((0..<4).map { "https://host\($0).example/\($0)" })
        let log = RequestLog()

        let offlineCheck = checker(online: false) { request in
            await log.append(request)
            return 404
        }
        let preflight = await offlineCheck.check(targets) { _ in }
        let preflightRequestCount = await log.count
        XCTAssertTrue(preflight.abortedOffline)
        XCTAssertTrue(preflight.findings.isEmpty)
        XCTAssertEqual(preflightRequestCount, 0)

        for code in [URLError.Code.notConnectedToInternet, .dataNotAllowed] {
            let transportOffline = checker { request in
                if request.url?.path == "/0" { return 404 }
                throw URLError(code)
            }
            let result = await transportOffline.check(targets) { _ in }
            XCTAssertTrue(result.abortedOffline, "\(code)")
            XCTAssertTrue(result.findings.isEmpty, "\(code)")
        }
    }

    func testSingleConnectionResetIsUncertainNotOffline() async throws {
        let targets = try makeTargets((0..<4).map { "https://host\($0).example/\($0)" })
        let checker = checker { request in
            if request.url?.path == "/1" { throw URLError(.networkConnectionLost) }
            return 200
        }

        let result = await checker.check(targets) { _ in }

        XCTAssertFalse(result.abortedOffline)
        XCTAssertEqual(result.uncertainCount, 1)
        XCTAssertEqual(result.totalChecked, 4)
    }

    func testCaptivePortalOrBrokenDNSStormAbortsAsOfflineInsteadOfFlaggingLibrary() async throws {
        let targets = try makeTargets((0..<8).map { "https://host\($0).example/\($0)" })
        let checker = checker(internetReachable: false) { _ in throw URLError(.cannotFindHost) }

        let result = await checker.check(targets) { _ in }

        XCTAssertTrue(result.abortedOffline)
        XCTAssertTrue(result.findings.isEmpty)
    }

    func testDeadDomainsFirstAreStillReportedWhenInternetProbeSucceeds() async throws {
        let dead = (0..<5).map { "https://dead\($0).example/x" }
        let live = (0..<3).map { "https://live\($0).example/x" }
        let targets = try makeTargets(dead + live)
        let checker = checker(internetReachable: true) { request in
            if request.url?.host()?.hasPrefix("dead") == true { throw URLError(.cannotFindHost) }
            return 200
        }

        let result = await checker.check(targets, maxConcurrency: 1) { _ in }

        XCTAssertFalse(result.abortedOffline)
        XCTAssertEqual(result.findings.count, 5)
        XCTAssertTrue(result.findings.allSatisfy { $0.reason == .hostNotFound })
    }

    func testDNSBreakingAfterOneSuccessAbortsWhenInternetProbeFails() async throws {
        let targets = try makeTargets((0..<7).map { "https://host\($0).example/\($0)" })
        let checker = checker(internetReachable: false) { request in
            if request.url?.path == "/0" { return 200 }
            throw URLError(.cannotFindHost)
        }

        let result = await checker.check(targets, maxConcurrency: 1) { _ in }

        XCTAssertTrue(result.abortedOffline)
        XCTAssertTrue(result.findings.isEmpty)
    }

    func testSmallLibraryDNSFailuresAreConfirmedByInternetProbe() async throws {
        let targets = try makeTargets(["https://a.example/1", "https://b.example/2"])
        let checker = checker(internetReachable: false) { _ in throw URLError(.cannotFindHost) }

        let result = await checker.check(targets) { _ in }

        XCTAssertTrue(result.abortedOffline)
        XCTAssertTrue(result.findings.isEmpty)
    }

    func testLiveBookmarkLookupReturnsNilForDeletedRow() throws {
        let kept = try insertBookmark("https://kept.example/a")
        let removed = try insertBookmark("https://removed.example/b")
        let removedID = removed.persistentModelID
        let context = try XCTUnwrap(container).mainContext
        context.delete(removed)
        try context.save()

        XCTAssertNil(BrokenLinkChecker.liveBookmark(with: removedID, in: context))
        XCTAssertEqual(BrokenLinkChecker.liveBookmark(with: kept.persistentModelID, in: context)?.urlString, "https://kept.example/a")
    }

    // MARK: - Cancellation and concurrency

    func testCancellationStopsSweepCleanly() async throws {
        let targets = try makeTargets((0..<5).map { "https://host\($0).example/\($0)" })
        let log = RequestLog()
        let checker = checker { request in
            await log.append(request)
            try await Task.sleep(for: .seconds(30))
            return 200
        }

        let clock = ContinuousClock()
        let started = clock.now
        let sweep = Task { await checker.check(targets, maxConcurrency: 2) { _ in } }
        while await log.count == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        sweep.cancel()
        let result = await sweep.value

        XCTAssertTrue(result.wasCancelled)
        XCTAssertFalse(result.abortedOffline)
        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertLessThan(clock.now - started, .seconds(5))
    }

    func testBoundedConcurrencyNeverExceedsLimit() async throws {
        let targets = try makeTargets((0..<20).map { "https://host\($0).example/\($0)" })
        let counter = InFlightCounter()
        let recorder = ProgressRecorder()
        let checker = checker { _ in
            await counter.begin()
            try await Task.sleep(for: .milliseconds(10))
            await counter.end()
            return 200
        }

        let result = await checker.check(targets, maxConcurrency: 4) { progress in
            await recorder.record(progress)
        }

        let maximum = await counter.maximum
        let progress = await recorder.values
        XCTAssertLessThanOrEqual(maximum, 4)
        XCTAssertGreaterThan(maximum, 1)
        XCTAssertEqual(result.totalChecked, 20)
        XCTAssertEqual(progress.last, BrokenLinkSweepProgress(checked: 20, total: 20))
        XCTAssertEqual(progress.map(\.checked), progress.map(\.checked).sorted())
    }
}
