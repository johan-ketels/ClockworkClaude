import SwiftUI

struct PermissionEditor: View {
    @Binding var permissionPreset: PermissionPreset
    @Binding var customTools: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            // Section header
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Theme.sonnet)
                Text("Permissions")
                    .font(Theme.monoBody.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            // Preset picker
            HStack(spacing: 4) {
                ForEach(PermissionPreset.allCases, id: \.self) { preset in
                    Button(action: { permissionPreset = preset }) {
                        HStack(spacing: 4) {
                            if preset == .yolo {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.warning)
                            }
                            Text(preset.displayName)
                                .font(Theme.monoSmall)
                        }
                        .foregroundStyle(permissionPreset == preset ? .white : Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .fill(presetColor(preset))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // YOLO warning
            if permissionPreset == .yolo {
                HStack(spacing: Theme.paddingSmall) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.warning)
                    Text("YOLO mode skips ALL permission checks. Claude will have unrestricted access to your system.")
                        .font(Theme.monoSmall)
                        .foregroundStyle(Theme.warning)
                }
                .padding(Theme.paddingMedium)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .fill(Theme.warning.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .stroke(Theme.warning.opacity(0.3), lineWidth: 1)
                        )
                )
            }

            // Tool display
            if permissionPreset == .custom {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allowed tools (comma-separated):")
                        .font(Theme.monoSmall)
                        .foregroundStyle(Theme.textMuted)
                    TextField("Read,Write,Edit,Bash(git *)", text: $customTools)
                        .font(Theme.monoBody)
                        .textFieldStyle(ThemedTextFieldStyle())
                }
            } else if let tools = permissionPreset.tools {
                toolBadges(tools)
            }
        }
        .padding(Theme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Theme.border, lineWidth: 1)
                )
        )
    }

    private func presetColor(_ preset: PermissionPreset) -> Color {
        guard permissionPreset == preset else { return Theme.surface }
        switch preset {
        case .yolo: return Theme.warning.opacity(0.8)
        default: return Theme.sonnet
        }
    }

    private func toolBadges(_ tools: String) -> some View {
        let toolList = tools.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return FlowLayout(spacing: 4) {
            ForEach(toolList, id: \.self) { tool in
                Text(tool)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.borderLight)
                    )
            }
        }
    }
}

// Simple flow layout for tool badges
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
