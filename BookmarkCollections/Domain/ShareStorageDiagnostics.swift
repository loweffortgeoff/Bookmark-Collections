import Foundation

enum ShareStorageDiagnostics {
    static func recoveryMessage(for _: Error) -> String {
        "Tucked could not open its shared library. Open Tucked, then try sharing again."
    }
}
