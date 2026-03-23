import Foundation
import SwiftUI

enum AppMetadata {
    static let displayName = "Gridflow"
    static let defaultMarketingVersion = "1.0.0"
    static let marketingVersion = bundleString(for: "CFBundleShortVersionString") ?? defaultMarketingVersion
    static let copyrightLine = bundleString(for: "NSHumanReadableCopyright") ?? "\u{00A9} Matthew Avgul"
    static let defaultProjectName = "Tasks"
    static let storageFolderName = "Gridflow"
    static let storageFileName = "storage.json"
    static let aboutWindowID = "about-gridflow"

    static var aboutWindowTitle: String {
        "About \(displayName)"
    }

    private static func bundleString(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}

enum AppResources {
    static let bundle: Bundle = {
        let candidateURLs: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("Gridflow_GridflowApp.bundle"),
            Bundle.main.bundleURL.appendingPathComponent("Gridflow_GridflowApp.bundle"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Gridflow_GridflowApp.bundle"),
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .appendingPathComponent("Gridflow_GridflowApp.bundle"),
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .appendingPathComponent("../Resources/Gridflow_GridflowApp.bundle")
        ]

        for candidateURL in candidateURLs.compactMap({ $0?.standardizedFileURL }) {
            if let bundle = Bundle(url: candidateURL) {
                return bundle
            }
        }

        return Bundle.module
    }()
}

enum AppLocalizer {
    static func string(_ key: String, locale: Locale) -> String {
        bundle(for: locale).localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        let pattern = string(key, locale: locale)
        return String(format: pattern, locale: locale, arguments: arguments)
    }

    private static func bundle(for locale: Locale) -> Bundle {
        let languageCode = languageCode(for: locale)

        guard
            let path = AppResources.bundle.path(forResource: languageCode, ofType: "lproj"),
            let languageBundle = Bundle(path: path)
        else {
            return AppResources.bundle
        }

        return languageBundle
    }

    private static func languageCode(for locale: Locale) -> String {
        let identifier = locale.identifier.lowercased()
        if identifier.hasPrefix("ru") {
            return "ru"
        }
        return "en"
    }
}

extension Notification.Name {
    static let newTaskCommand = Notification.Name("newTaskCommand")
    static let undoCommand = Notification.Name("undoCommand")
}

struct DailyCompletionStats {
    var completedTotal: Int
    var byQuadrant: [TaskQuadrant: Int]

    static func make(from tasks: [TaskItem], day: Date = .now) -> DailyCompletionStats {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return DailyCompletionStats(completedTotal: 0, byQuadrant: [:])
        }

        let completedToday = tasks.filter {
            guard $0.status == .completed, let completedAt = $0.completedAt else { return false }
            return completedAt >= start && completedAt < end
        }

        let grouped = Dictionary(grouping: completedToday, by: { $0.completedFromQuadrant ?? $0.quadrant })
            .mapValues(\.count)

        return DailyCompletionStats(completedTotal: completedToday.count, byQuadrant: grouped)
    }
}
