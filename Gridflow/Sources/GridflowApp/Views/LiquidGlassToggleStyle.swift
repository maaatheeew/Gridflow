import SwiftUI

struct LiquidGlassToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        LiquidGlassToggleBody(configuration: configuration)
    }
}

private struct LiquidGlassToggleBody: View {
    let configuration: ToggleStyle.Configuration

    var body: some View {
        HStack(spacing: 10) {
            configuration.label
            Spacer(minLength: 8)

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    configuration.isOn.toggle()
                }
            } label: {
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule(style: .continuous)
                        .fill(trackBaseColor)
                        .frame(width: 50, height: 28)
                        .overlay {
                            Capsule(style: .continuous)
                                .fill(configuration.isOn ? AppTheme.primaryAccent.opacity(0.18) : .clear)
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(trackBorderColor, lineWidth: 1)
                        }

                    Circle()
                        .fill(knobColor)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Circle()
                                .stroke(AppTheme.mutedBorder, lineWidth: 0.6)
                        }
                        .padding(3)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var trackBaseColor: Color {
        AppTheme.toggleTrack
    }

    private var trackBorderColor: Color {
        AppTheme.border
    }

    private var knobColor: Color {
        AppTheme.toggleKnob
    }
}
