import Combine
import SwiftData
import SwiftUI
import OSLog

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private let shareStorageLogger = Logger(
    subsystem: "com.loweffortapps.BookmarkCollections",
    category: "ShareStorage"
)

#if os(iOS)
@MainActor
final class ShareViewController: UIViewController {
    private var container: ModelContainer?
    private var hostedController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 420, height: 520)
        configureCapture()
    }

    private func configureCapture() {
        removeHostedController()
        do {
            let container = try ModelContainerFactory.make(inMemory: false, cloudKit: true)
            self.container = container
            let model = ShareCaptureModel(
                context: container.mainContext,
                metadataProvider: LinkPresentationMetadataProvider()
            ) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
            host(
                ShareCaptureView(
                    model: model,
                    providers: inputProviders,
                    onCancel: { [weak self] in self?.cancelRequest() }
                )
            )
        } catch {
            shareStorageLogger.error("""
                Could not open shared storage: \(ShareStorageDiagnostics.logSummary(for: error), privacy: .public) \
                detail: \(String(reflecting: error), privacy: .private)
                """)
            host(
                ShareStoreFailureView(
                    message: ShareStorageDiagnostics.recoveryMessage(for: error),
                    onRetry: { [weak self] in self?.configureCapture() },
                    onCancel: { [weak self] in self?.cancelRequest() }
                )
            )
        }
    }

    private var inputProviders: [NSItemProvider] {
        (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []
    }

    private func cancelRequest() {
        let error = NSError(
            domain: "BookmarkShareExtension",
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: "Bookmark capture was cancelled."]
        )
        extensionContext?.cancelRequest(withError: error)
    }

    private func host<Content: View>(_ content: Content) {
        let controller = UIHostingController(rootView: content)
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        hostedController = controller
    }

    private func removeHostedController() {
        guard let hostedController else { return }
        hostedController.willMove(toParent: nil)
        hostedController.view.removeFromSuperview()
        hostedController.removeFromParent()
        self.hostedController = nil
        container = nil
    }
}
#endif

#if os(macOS)
@MainActor
final class ShareViewController: NSViewController {
    private var container: ModelContainer?
    private var hostedController: NSViewController?
    private var stateObservation: AnyCancellable?
    private var needsAttention = false

    override func loadView() {
        view = NSView()
        preferredContentSize = NSSize(width: 360, height: 200)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCapture()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // The save can fail before ShareKit shows the window, so the window
        // may not exist yet when the failure is first seen.
        bringToFrontIfNeeded()
    }

    /// Safari stays the active app, and ShareKit logs that the service window
    /// "may order beneath the active application's windows". A failure message
    /// hidden there looks like a silent failure, so raise the window.
    private func markNeedsAttention() {
        needsAttention = true
        bringToFrontIfNeeded()
    }

    private func bringToFrontIfNeeded() {
        guard needsAttention, let window = view.window else { return }
        shareStorageLogger.notice("Raising the failure window")
        NSApp.activate()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
    }

    private func configureCapture() {
        removeHostedController()
        do {
            let container = try ModelContainerFactory.make(
                inMemory: false,
                cloudKit: true
            )
            self.container = container
            let model = ShareCaptureModel(
                context: container.mainContext
            ) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
            stateObservation = model.$state.sink { [weak self] state in
                if state.isFailure { self?.markNeedsAttention() }
            }
            host(
                MacQuickSaveView(
                    model: model,
                    providers: inputProviders,
                    onCancel: { [weak self] in self?.cancelRequest() }
                )
            )
        } catch {
            shareStorageLogger.error("""
                Could not open shared storage: \(ShareStorageDiagnostics.logSummary(for: error), privacy: .public) \
                detail: \(String(reflecting: error), privacy: .private)
                """)
            host(
                ShareStoreFailureView(
                    message: ShareStorageDiagnostics.recoveryMessage(for: error),
                    onRetry: { [weak self] in self?.configureCapture() },
                    onCancel: { [weak self] in self?.cancelRequest() }
                )
            )
            markNeedsAttention()
        }
    }

    private var inputProviders: [NSItemProvider] {
        (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []
    }

    private func cancelRequest() {
        let error = NSError(
            domain: "BookmarkShareExtension",
            code: NSUserCancelledError,
            userInfo: [
                NSLocalizedDescriptionKey: "Bookmark capture was cancelled."
            ]
        )
        extensionContext?.cancelRequest(withError: error)
    }

    private func host<Content: View>(_ content: Content) {
        let controller = NSHostingController(rootView: content)
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostedController = controller
    }

    private func removeHostedController() {
        stateObservation = nil
        guard let hostedController else { return }
        hostedController.view.removeFromSuperview()
        hostedController.removeFromParent()
        self.hostedController = nil
        container = nil
    }
}
#endif

private struct ShareStoreFailureView: View {
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Couldn’t Open Bookmark Storage", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
                Button("Cancel", action: onCancel)
            }
            .navigationTitle("Save Bookmark")
        }
    }
}
