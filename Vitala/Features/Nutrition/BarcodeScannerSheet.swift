import SwiftUI
import VisionKit

/// Scans a food barcode with the camera (VisionKit's on-device scanner), or
/// lets the person type the number. Calls `onCode` once with the digits.
/// Present inside a `NavigationStack`.
struct BarcodeScannerSheet: View {
    let onCode: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var typing = false
    @State private var typed = ""
    @FocusState private var fieldFocused: Bool

    private var scannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        Group {
            if scannerAvailable && !typing {
                scanner
            } else {
                manualEntry
            }
        }
        .navigationTitle("Scan barcode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    // MARK: Camera

    private var scanner: some View {
        ZStack(alignment: .bottom) {
            DataScannerRepresentable { code in
                Haptics.success()
                finish(code)
            }
            .ignoresSafeArea()
            .accessibilityLabel("Camera viewfinder")
            .accessibilityHint("Point the camera at a barcode on the package")

            VStack(spacing: VitalaSpacing.sm) {
                Text("Point at the barcode on the package")
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(.black.opacity(0.55)))
                Button {
                    typing = true
                } label: {
                    Label("Type the number instead", systemImage: "keyboard")
                        .font(VitalaFont.bodyMedium(15))
                        .padding(.horizontal, 6)
                        .frame(minHeight: 32)
                }
                .buttonBorderShape(.capsule)
                .glassButtonStyle()
                .foregroundStyle(.white)
            }
            .padding(.bottom, VitalaSpacing.xl)
        }
    }

    // MARK: Manual entry

    private var manualEntry: some View {
        Form {
            if !scannerAvailable {
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "camera")
                            .accessibilityHidden(true)
                        Text(unavailableReason)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(VitalaColor.textSecondary)
                    if DataScannerViewController.isSupported {
                        Button("Allow camera in Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }
            }
            Section {
                FormTextField(label: "Barcode", text: $typed, prompt: "Digits", keyboard: .numberPad)
                    .focused($fieldFocused)
                    .onSubmit(submitTyped)
            } footer: {
                Text("The 8 to 14 digits printed under the barcode.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            Section {
                Button("Look up") { submitTyped() }
                    .disabled(!Barcode.isValid(typed))
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .keyboardDoneButton()
        .onAppear { fieldFocused = true }
    }

    private var unavailableReason: String {
        DataScannerViewController.isSupported
            ? "Camera access is off for Vitala, so you can type the number instead."
            : "This device can't scan barcodes with the camera, so you can type the number instead."
    }

    private func submitTyped() {
        guard Barcode.isValid(typed) else { return }
        finish(Barcode.digits(typed))
    }

    private func finish(_ code: String) {
        onCode(code)
        dismiss()
    }
}

/// VisionKit's live scanner, limited to retail food barcodes.
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var reported = false

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !reported else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue,
                   Barcode.isValid(value) {
                    reported = true
                    dataScanner.stopScanning()
                    onCode(Barcode.digits(value))
                    return
                }
            }
        }
    }
}
