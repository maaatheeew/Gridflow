import AppKit
import SwiftUI

enum AppTheme {
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let contentBackground = Color(nsColor: .underPageBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let elevatedSurface = Color(nsColor: .textBackgroundColor)

    static let separator = Color(nsColor: .separatorColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    static let quaternaryText = Color(nsColor: .quaternaryLabelColor)
    static let selectedText = Color(nsColor: .alternateSelectedControlTextColor)

    static let remindersRed = Color(nsColor: .systemRed)
    static let remindersOrange = Color(nsColor: .systemOrange)
    static let remindersYellow = Color(nsColor: .systemYellow)
    static let remindersGreen = Color(nsColor: .systemGreen)
    static let remindersBlue = Color(nsColor: .systemBlue)

    static let primaryAccent = remindersBlue
    static let secondaryAccent = remindersYellow

    static let cardFill = surface.opacity(0.94)
    static let rowFill = elevatedSurface.opacity(0.78)
    static let subtleFill = separator.opacity(0.08)
    static let hoverFill = primaryAccent.opacity(0.12)
    static let hoverOutline = primaryAccent.opacity(0.24)
    static let border = separator.opacity(0.78)
    static let mutedBorder = separator.opacity(0.55)
    static let sidebarFooterBackground = windowBackground
    static let toggleTrack = separator.opacity(0.16)
    static let toggleKnob = surface

    static func quadrantAccent(_ quadrant: TaskQuadrant) -> Color {
        switch quadrant {
        case .importantUrgent:
            remindersRed
        case .importantNotUrgent:
            remindersGreen
        case .notImportantUrgent:
            remindersOrange
        case .notImportantNotUrgent:
            remindersBlue
        }
    }
}

enum AppFont {
    static let hero = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let quadrantTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let header = Font.system(.title, design: .rounded).weight(.bold)
    static let section = Font.system(.title2, design: .rounded).weight(.bold)
    static let cardTitle = Font.system(.title3, design: .rounded).weight(.bold)
    static let body = Font.system(.body, design: .rounded)
    static let bodyMedium = Font.system(.body, design: .rounded).weight(.medium)
    static let bodySemibold = Font.system(.body, design: .rounded).weight(.semibold)
    static let subheadline = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let footnote = Font.system(.footnote, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let captionSemibold = Font.system(.caption, design: .rounded).weight(.semibold)
    static let caption2Semibold = Font.system(.caption2, design: .rounded).weight(.semibold)
}
