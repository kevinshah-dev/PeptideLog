import SwiftUI

struct AppPanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(AppTheme.textPrimary)
            .background(AppTheme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.divider)
            }
    }
}

struct SectionHeading: View {
    let title: String
    var actionTitle: String? = nil
    var systemImage: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: systemImage ?? "plus")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            }
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    var tint: Color = AppTheme.accent

    var body: some View {
        AppPanel(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
    }
}

struct DisclaimerBanner: View {
    var compact = false

    var body: some View {
        AppPanel(padding: compact ? 12 : 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(AppTheme.accent)
                    .font(.title3)

                Text(MedicalDisclaimer.copy)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct SeverityDots: View {
    let severity: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= severity ? severityColor : AppTheme.divider)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel("Severity \(severity) of 5")
    }

    private var severityColor: Color {
        switch severity {
        case 1...2: AppTheme.accent
        case 3: AppTheme.warning
        default: AppTheme.danger
        }
    }
}

struct BrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.elevatedStrong)

            MolecularMark()
                .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .padding(13)

            Image(systemName: "syringe.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .rotationEffect(.degrees(-42))
        }
        .frame(width: 58, height: 58)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.divider)
        }
    }
}

private struct MolecularMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let a = CGPoint(x: rect.minX + rect.width * 0.2, y: rect.midY)
        let b = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.25)
        let c = CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.midY)
        let d = CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.2)

        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.move(to: b)
        path.addLine(to: d)
        path.move(to: a)
        path.addEllipse(in: CGRect(x: a.x - 4, y: a.y - 4, width: 8, height: 8))
        path.addEllipse(in: CGRect(x: b.x - 4, y: b.y - 4, width: 8, height: 8))
        path.addEllipse(in: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8))
        path.addEllipse(in: CGRect(x: d.x - 4, y: d.y - 4, width: 8, height: 8))
        return path
    }
}
