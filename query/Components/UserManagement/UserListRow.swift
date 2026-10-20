import SwiftUI

/// A user in the Users & Permissions sidebar: name, host (MySQL), and badges for superuser and
/// accounts that can't sign in.
struct UserListRow: View {
    let user: DatabaseUser

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(verbatim: user.name)
                HStack(spacing: Theme.Spacing.xs) {
                    if let host = user.host {
                        Text(verbatim: "@\(host)")
                    }
                    if user.options.contains(.superuser) {
                        Text(L10n.userBadgeSuperuser)
                    }
                    if !user.options.contains(.login) {
                        Text(L10n.userBadgeNoLogin)
                    }
                }
                .font(Theme.Typography.footer)
                .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: user.options.contains(.superuser) ? "person.badge.key.fill" : "person.fill")
                .foregroundStyle(user.options.contains(.login) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.Users.user(user.id))
    }
}

#Preview {
    List {
        UserListRow(user: DatabaseUser(name: "postgres", host: nil, options: Set(UserOption.allCases)))
        UserListRow(user: DatabaseUser(name: "query_reader", host: "%", options: []))
    }
    .frame(width: 260, height: 160)
}
