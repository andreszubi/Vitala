import SwiftUI

/// The user's profile photo, or their initials on the brand gradient.
struct AvatarView: View {
    var size: CGFloat = 48
    @EnvironmentObject private var profileStore: ProfileStore

    private var initials: String {
        let parts = (profileStore.profile?.displayName ?? "").split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        let value = (first + last).uppercased()
        return value.isEmpty ? "V" : value
    }

    var body: some View {
        Group {
            if let photo = profileStore.avatar {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initials)
                    .font(size > 64 ? VitalaFont.title(28) : VitalaFont.headline(18))
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .padding(size * 0.14)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VitalaColor.primaryGradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(VitalaColor.hairline, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// Avatar that opens Profile & Settings. Shown in the header of every tab.
struct ProfileButton: View {
    var size: CGFloat = 44

    var body: some View {
        NavigationLink {
            ProfileView()
        } label: {
            AvatarView(size: size)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Profile and settings")
        .accessibilityIdentifier("profile.button")
    }
}
