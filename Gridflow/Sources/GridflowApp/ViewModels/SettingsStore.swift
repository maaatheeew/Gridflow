import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: Keys.themeMode) }
    }

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedTheme = defaults.string(forKey: Keys.themeMode)
        self.themeMode = ThemeMode(rawValue: storedTheme ?? "") ?? .system

        let storedLanguage = defaults.string(forKey: Keys.language)
        self.language = AppLanguage(rawValue: storedLanguage ?? "") ?? .system
    }

    var locale: Locale {
        language.locale
    }

    private enum Keys {
        static let themeMode = "themeMode"
        static let language = "language"
    }
}
