import SwiftUI

struct AgentStatusRow: View {
    let status: AgentStatus
    @AppStorage("appLanguage") private var langID = AppLanguage.english.rawValue

    private var lang: AppLanguage { AppLanguage(rawValue: langID) ?? .english }
    private var loc: Loc { Loc(lang: lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(status.provider.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(loc.statusTitle(status))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            if let message = status.message, case .error = status.availability {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let instruction = loc.statusInstruction(status) {
                Text(instruction)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusColor: Color {
        switch status.availability {
        case .available:
            return .green
        case .loading:
            return .secondary
        case .missingAuth, .accessDenied, .sessionExpired, .notInstalled, .notLoggedIn:
            return .orange
        case .error:
            return .red
        }
    }
}
