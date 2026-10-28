import PhotosUI
import SwiftUI

/// Picks a profile photo with the system photo picker. The picker runs out of
/// process, so Vitala never needs access to the photo library.
struct ProfilePhotoPicker<Label: View>: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @State private var item: PhotosPickerItem?
    @State private var failed = false
    @ViewBuilder let label: (_ hasPhoto: Bool) -> Label

    var body: some View {
        let hasPhoto = profileStore.avatar != nil
        PhotosPicker(selection: $item, matching: .images) {
            label(hasPhoto)
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task {
                let data = try? await newItem.loadTransferable(type: Data.self)
                if let data, profileStore.setAvatar(imageData: data) {
                    Haptics.success()
                } else {
                    failed = true
                }
                item = nil
            }
        }
        .alert("Couldn't use that photo", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try choosing a different image.")
        }
    }
}
