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

    override func loadView() {
        // A plain NSView() has a zero frame, and ShareKit does not size the
        // view from preferredContentSize. A failed share dimmed Safari and drew
        // nothing: the log showed view={{0, 0}, {0, 0}} in a full-screen window.
        // The template's nib view has a fixed size, so give this one a frame.
        let size = NSSize(width: 360, height: 200)
        view = NSView(frame: NSRect(origin: .zero, size: size))
        preferredContentSize = size
        // TEMP experiment: a solid red layer shows whether anything the
        // extension draws reaches Safari. Remove once the cause is known.
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.systemRed.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCapture()
    }

    // TEMP experiment: time the end of the view against the dim in Safari.
    override func viewWillDisappear() {
        super.viewWillDisappear()
        shareStorageLogger.notice("Share view will disappear")
    }

    deinit {
        shareStorageLogger.notice("Share view controller deinit")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // A failed share once dimmed Safari and drew nothing. Record what
        // ShareKit gave us, so a repeat shows the size and visibility.
        if let window = view.window {
            shareStorageLogger.notice("""
                Share view appeared. view=\(NSStringFromRect(self.view.frame), privacy: .public) \
                window=\(NSStringFromRect(window.frame), privacy: .public) \
                visible=\(window.isVisible) appActive=\(NSApp.isActive)
                """)
        }
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
                MacShareFailureView(
                    title: "Couldn’t Open Bookmark Storage",
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
        guard let hostedController else { return }
        hostedController.view.removeFromSuperview()
        hostedController.removeFromParent()
        self.hostedController = nil
        container = nil
    }
}
#endif

#if os(iOS)
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
#endif
