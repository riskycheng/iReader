import SwiftUI
import UIKit
import UniformTypeIdentifiers

// 文档选择器协调器
class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    private let parent: UIDocumentPickerRepresentable
    
    init(parent: UIDocumentPickerRepresentable) {
        self.parent = parent
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        parent.didPickDocuments(urls)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        parent.didCancel()
    }
}

// UIDocumentPicker的SwiftUI包装器
struct UIDocumentPickerRepresentable: UIViewControllerRepresentable {
    var documentTypes: [UTType]
    var asCopy: Bool
    var allowsMultipleSelection: Bool
    var onPick: ([URL]) -> Void
    var onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: documentTypes, asCopy: asCopy)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> DocumentPickerCoordinator {
        DocumentPickerCoordinator(parent: self)
    }
    
    func didPickDocuments(_ urls: [URL]) {
        onPick(urls)
    }
    
    func didCancel() {
        onCancel()
    }
}

// 文件导入视图
struct FileImportView: View {
    @State private var isShowingDocumentPicker = false
    @State private var documentPickerType: DocumentPickerType = .local
    @ObservedObject var fileService = BookFileService.shared
    
    enum DocumentPickerType {
        case local
        case iCloud
    }
    
    var body: some View {
        EmptyView()
            .sheet(isPresented: $isShowingDocumentPicker) {
                if documentPickerType == .local {
                    UIDocumentPickerRepresentable(
                        documentTypes: [.epub, .pdf, .text],
                        asCopy: true,
                        allowsMultipleSelection: true,
                        onPick: { urls in
                            fileService.processImportedFiles(urls: urls)
                            isShowingDocumentPicker = false
                        },
                        onCancel: {
                            isShowingDocumentPicker = false
                        }
                    )
                } else {
                    UIDocumentPickerRepresentable(
                        documentTypes: [.epub, .pdf, .text],
                        asCopy: true,
                        allowsMultipleSelection: true,
                        onPick: { urls in
                            fileService.processImportedFiles(urls: urls)
                            isShowingDocumentPicker = false
                        },
                        onCancel: {
                            isShowingDocumentPicker = false
                        }
                    )
                }
            }
    }
    
    func showLocalFilePicker() {
        documentPickerType = .local
        isShowingDocumentPicker = true
    }
    
    func showICloudPicker() {
        documentPickerType = .iCloud
        isShowingDocumentPicker = true
    }
}
