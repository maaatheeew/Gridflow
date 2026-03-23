import SwiftUI

struct StatsCardView: View {
    @Environment(\.locale) private var locale
    let stats: DailyCompletionStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l("stats.today"))
                    .font(AppFont.cardTitle)
                Spacer()
                Text("\(stats.completedTotal)")
                    .font(AppFont.header)
                    .foregroundStyle(AppTheme.secondaryAccent)
            }

            HStack(alignment: .top, spacing: 16) {
                ForEach(TaskQuadrant.allCases) { quadrant in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(l(quadrant.titleKey))
                            .font(AppFont.captionSemibold)
                            .foregroundStyle(quadrant.accentColor)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        Text("\(stats.byQuadrant[quadrant, default: 0])")
                            .font(AppFont.section)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(cardFillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    private func l(_ key: String) -> String {
        AppLocalizer.string(key, locale: locale)
    }

    private var cardFillColor: Color {
        AppTheme.cardFill
    }

    private var cardBorderColor: Color {
        AppTheme.border
    }
}
