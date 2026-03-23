import Foundation
import SwiftUI

enum TaskQuadrant: Int, CaseIterable, Identifiable, Codable {
    case importantUrgent = 0
    case importantNotUrgent = 1
    case notImportantUrgent = 2
    case notImportantNotUrgent = 3

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .importantUrgent: "quadrant.important_urgent"
        case .importantNotUrgent: "quadrant.important"
        case .notImportantUrgent: "quadrant.urgent"
        case .notImportantNotUrgent: "quadrant.neither"
        }
    }

    var subtitleKey: String {
        switch self {
        case .importantUrgent: "quadrant.subtitle.important_urgent"
        case .importantNotUrgent: "quadrant.subtitle.important"
        case .notImportantUrgent: "quadrant.subtitle.urgent"
        case .notImportantNotUrgent: "quadrant.subtitle.neither"
        }
    }

    var accentColor: Color {
        AppTheme.quadrantAccent(self)
    }

    var shortCode: String {
        switch self {
        case .importantUrgent: "Q1"
        case .importantNotUrgent: "Q2"
        case .notImportantUrgent: "Q3"
        case .notImportantNotUrgent: "Q4"
        }
    }
}

enum TaskStatus: String, CaseIterable, Identifiable, Codable {
    case active
    case completed

    var id: String { rawValue }
}

enum TaskPriority: Int, CaseIterable, Identifiable, Codable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .low: "priority.low"
        case .medium: "priority.medium"
        case .high: "priority.high"
        }
    }
}

enum SmartList: String, CaseIterable, Identifiable {
    case all
    case today
    case planned
    case done

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .all: "smart.all"
        case .today: "smart.today"
        case .planned: "smart.planned"
        case .done: "smart.done"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "tray.full"
        case .today: "bolt.fill"
        case .planned: "calendar"
        case .done: "checkmark"
        }
    }
}

enum TaskSortMode: String, CaseIterable, Identifiable {
    case dueDate
    case createdAt
    case priority

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .dueDate: "sort.due_date"
        case .createdAt: "sort.created_at"
        case .priority: "sort.priority"
        }
    }
}

enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system: "settings.theme.system"
        case .light: "settings.theme.light"
        case .dark: "settings.theme.dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case ru

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system: "settings.language.system"
        case .en: "settings.language.en"
        case .ru: "settings.language.ru"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .en:
            Locale(identifier: "en")
        case .ru:
            Locale(identifier: "ru")
        }
    }
}
