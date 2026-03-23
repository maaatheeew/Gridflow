import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(spacing: 6) {
                Text(AppMetadata.displayName)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                Text(AppMetadata.aboutTagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Version \(AppMetadata.marketingVersion)")
                    .font(.headline)

                Text(AppMetadata.copyrightLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(minWidth: 320)
    }
}
