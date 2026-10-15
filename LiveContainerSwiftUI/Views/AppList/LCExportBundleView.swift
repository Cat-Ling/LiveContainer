import SwiftUI
import UniformTypeIdentifiers

struct DocumentExportPicker: UIViewControllerRepresentable {
    var fileURL: URL
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onDismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onDismiss()
        }
    }
}

struct LCExportBundleView: View {
    @ObservedObject var model: LCAppModel
    @Environment(\.dismiss) private var dismiss

    @State private var includeAppBundle: Bool = true
    @State private var includeData: Bool = true
    @State private var includeTweaks: Bool = true
    @State private var selectedContainerFolderNames: Set<String> = []

    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0.0
    @State private var statusMessage: String = ""
    @State private var progressObserver: NSKeyValueObservation?

    @State private var exportedFileURL: URL?
    @State private var showShareSheet: Bool = false
    @State private var showDocumentPicker: Bool = false

    @State private var errorMessage: String?
    @State private var showErrorAlert: Bool = false

    init(model: LCAppModel) {
        self.model = model
        let initialContainerFolders = Set(model.uiContainers.map { $0.folderName })
        self._selectedContainerFolderNames = State(initialValue: initialContainerFolders)
    }

    private var canExport: Bool {
        !isExporting && (includeAppBundle || (includeData && !selectedContainerFolderNames.isEmpty))
    }

    var body: some View {
        NavigationView {
            Form {
                // App summary header
                Section {
                    HStack(spacing: 14) {
                        if let icon = model.appInfo.iconIsDarkIcon(false) {
                            IconImageView(icon: icon)
                                .frame(width: 58, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        } else {
                            Image(systemName: "app.fill")
                                .resizable()
                                .frame(width: 58, height: 58)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.displayName)
                                .font(.headline)
                            Text(model.bundleIdentifier)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("v\(model.version)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let exportedFileURL {
                    // Ready state
                    Section {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.green)
                            Text(exportedFileURL.lastPathComponent)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            Text("lc.bundle.compressing".loc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                        Button {
                            showDocumentPicker = true
                        } label: {
                            Label("Save to Files...", systemImage: "folder.badge.plus")
                        }

                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share...", systemImage: "square.and.arrow.up")
                        }
                    }
                } else {
                    // Export Options
                    Section(header: Text("lc.bundle.contentOptions".loc)) {
                        Toggle(isOn: $includeAppBundle) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("lc.bundle.includeApp".loc)
                                Text("lc.bundle.includeAppDesc".loc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(isExporting)

                        Toggle(isOn: $includeData) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("lc.bundle.includeData".loc)
                                Text("lc.bundle.includeDataDesc".loc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(isExporting)

                        if includeData && model.uiContainers.count > 1 {
                            ForEach(model.uiContainers, id: \.folderName) { container in
                                HStack {
                                    Image(systemName: selectedContainerFolderNames.contains(container.folderName) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedContainerFolderNames.contains(container.folderName) ? .accentColor : .secondary)
                                    Text(container.name.isEmpty ? container.folderName : container.name)
                                    Spacer()
                                    if container.folderName == model.uiDefaultDataFolder {
                                        Text("Default")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    guard !isExporting else { return }
                                    if selectedContainerFolderNames.contains(container.folderName) {
                                        if selectedContainerFolderNames.count > 1 {
                                            selectedContainerFolderNames.remove(container.folderName)
                                        }
                                    } else {
                                        selectedContainerFolderNames.insert(container.folderName)
                                    }
                                }
                            }
                        }

                        if let tweakFolder = model.uiTweakFolder, !tweakFolder.isEmpty {
                            Toggle(isOn: $includeTweaks) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("lc.bundle.includeTweaks".loc)
                                    Text(tweakFolder)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .disabled(isExporting)
                        }
                    }

                    // Progress Indicator
                    if isExporting {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                ProgressView(value: exportProgress, total: 1.0)
                                HStack {
                                    Text(statusMessage)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(exportProgress * 100))%")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Action section
                    Section {
                        Button {
                            Task { await startExport() }
                        } label: {
                            HStack {
                                Spacer()
                                if isExporting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Label("lc.bundle.exportAction".loc, systemImage: "shippingbox")
                                        .font(.body.weight(.semibold))
                                }
                                Spacer()
                            }
                        }
                        .disabled(!canExport)
                    }
                }
            }
            .navigationTitle("lc.bundle.exportTitle".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(exportedFileURL != nil ? "lc.common.ok".loc : "lc.common.cancel".loc) {
                        cleanupExportedFile()
                        dismiss()
                    }
                    .disabled(isExporting)
                }
            }
            .alert("lc.common.error".loc, isPresented: $showErrorAlert) {
                Button("lc.common.ok".loc, role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showShareSheet) {
                if let exportedFileURL {
                    ActivityViewController(activityItems: [exportedFileURL])
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                if let exportedFileURL {
                    DocumentExportPicker(fileURL: exportedFileURL) {
                        showDocumentPicker = false
                    }
                }
            }
        }
    }

    private func startExport() async {
        guard canExport else { return }
        isExporting = true
        exportProgress = 0.0
        statusMessage = "lc.bundle.exporting".loc

        let progress = Progress.discreteProgress(totalUnitCount: 100)
        progressObserver = progress.observe(\.fractionCompleted) { p, _ in
            DispatchQueue.main.async {
                self.exportProgress = p.fractionCompleted
                if p.fractionCompleted > 0.0 {
                    self.statusMessage = "lc.bundle.compressing".loc
                }
            }
        }

        let selectedContainers = model.uiContainers.filter {
            selectedContainerFolderNames.contains($0.folderName)
        }

        let options = LCBundleExportOptions(
            includeAppBundle: includeAppBundle,
            includeData: includeData,
            selectedContainers: selectedContainers,
            includeTweaks: includeTweaks
        )

        do {
            let outputURL = try await LCAppBundleService.exportBundle(
                app: model,
                options: options,
                progress: progress
            )
            await MainActor.run {
                self.exportedFileURL = outputURL
                self.isExporting = false
            }
        } catch {
            await MainActor.run {
                self.isExporting = false
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true
            }
        }
    }

    private func cleanupExportedFile() {
        guard let exportedFileURL else { return }
        try? FileManager.default.removeItem(at: exportedFileURL.deletingLastPathComponent())
        self.exportedFileURL = nil
    }
}
