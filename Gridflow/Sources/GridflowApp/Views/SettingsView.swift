import SwiftUI

struct SettingsView: View {
    private enum Layout {
        static let pickerWidth: CGFloat = 190
    }

    @Environment(\.locale) private var locale
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    let onImportJSON: () -> Void
    let onExportJSON: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(l("settings.title"))
                    .font(AppFont.hero)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Button(l("common.done")) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 18) {
                settingsSection {
                    settingsPickerRow(title: l("settings.theme"), selection: $settings.themeMode) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(l(mode.titleKey)).tag(mode)
                        }
                    }

                    settingsDivider

                    settingsPickerRow(title: l("settings.language"), selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(l(language.titleKey)).tag(language)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(l("io.menu"))
                        .font(AppFont.bodySemibold)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 4)

                    settingsSection {
                        settingsActionRow(
                            title: l("io.import_json"),
                            systemImage: "square.and.arrow.down",
                            action: onImportJSON
                        )

                        settingsDivider

                        settingsActionRow(
                            title: l("io.export_json"),
                            systemImage: "square.and.arrow.up",
                            action: onExportJSON
                        )
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 560, height: 380)
    }

    private func l(_ key: String) -> String {
        AppLocalizer.string(key, locale: locale)
    }

    private func settingsSection<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var settingsDivider: some View {
        Divider()
            .overlay(AppTheme.mutedBorder)
            .padding(.horizontal, 18)
    }

    private func settingsPickerRow<SelectionValue: Hashable, Content: View>(
        title: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(AppFont.bodySemibold)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            settingsPickerControl(selection: selection) {
                content()
            }
            .frame(width: Layout.pickerWidth)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func settingsPickerControl<SelectionValue: Hashable, Content: View>(
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Picker("", selection: selection) {
            content()
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.large)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func settingsActionRow(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.primaryAccent)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
