import SwiftData
import SwiftUI
import UIKit

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
            host(
                ShareStoreFailureView(
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

private struct ShareStoreFailureView: View {
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Couldn’t Open Bookmark Storage", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text("The bookmark was not saved. Check storage access and try again.")
            } actions: {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
                Button("Cancel", action: onCancel)
            }
            .navigationTitle("Save Bookmark")
        }
    }
}
