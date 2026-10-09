import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Use the system copy/import route so iCloud and third-party providers materialize
/// a readable copy. Some Windows-created TXT files are reported only as public.data.
struct TextDocumentPicker: UIViewControllerRepresentable {
    let selected: (URL) -> Void
    let cancelled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(selected: selected, cancelled: cancelled) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Validate the .txt extension ourselves after selection. A text-only filter
        // can leave otherwise valid TXT files disabled in a provider's file browser.
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        controller.allowsMultipleSelection = false
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let selected: (URL) -> Void
        private let cancelled: () -> Void
        private var completed = false
        init(selected: @escaping (URL) -> Void, cancelled: @escaping () -> Void) {
            self.selected = selected; self.cancelled = cancelled
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !completed else { return }
            completed = true
            if let url = urls.first { selected(url) } else { cancelled() }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            guard !completed else { return }
            completed = true
            cancelled()
        }
    }
}
