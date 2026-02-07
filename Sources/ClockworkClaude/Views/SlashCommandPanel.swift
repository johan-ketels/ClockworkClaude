import SwiftUI

struct SlashCommandPanel: View {
    @Environment(CommandScanner.self) private var scanner
    let directory: String
    let onSelect: (SlashCommand) -> Void

    @State private var selectedIndex: Int? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Theme.warning)
                    .font(.caption)
                Text("Available commands")
                    .font(Theme.monoSmall.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)

                if !scanner.commands.isEmpty {
                    Text("(\(scanner.commands.count))")
                        .font(Theme.monoSmall)
                        .foregroundStyle(Theme.textMuted)
                }

                Spacer()
                Button(action: { scanner.scan(directory: directory) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                        Text("Scan")
                            .font(Theme.monoSmall)
                    }
                    .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .disabled(scanner.isScanning)
            }

            if scanner.commands.isEmpty {
                Text("No commands found. Add .md files to .claude/commands/")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.textMuted)
                    .italic()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        FlowLayout(spacing: 4) {
                            ForEach(Array(scanner.commands.enumerated()), id: \.element.id) { index, cmd in
                                Button(action: { onSelect(cmd) }) {
                                    Text(cmd.displayName)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(selectedIndex == index ? .white : Theme.sonnet)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                                .fill(selectedIndex == index ? Theme.sonnet : Theme.sonnet.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                                        .stroke(Theme.sonnet.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("\(cmd.source) command: \(cmd.filePath)")
                                .id(index)
                            }
                        }
                    }
                    .frame(maxHeight: 80)
                    .onChange(of: selectedIndex) { _, newIndex in
                        if let idx = newIndex {
                            withAnimation {
                                proxy.scrollTo(idx, anchor: .center)
                            }
                        }
                    }
                }
                .focusable()
                .focused($isFocused)
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.return) {
                    if let idx = selectedIndex, idx < scanner.commands.count {
                        onSelect(scanner.commands[idx])
                    }
                    return .handled
                }
                .onKeyPress(.escape) {
                    selectedIndex = nil
                    isFocused = false
                    return .handled
                }
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
        .onChange(of: directory) { _, newValue in
            selectedIndex = nil
            scanner.scan(directory: newValue)
        }
        .onAppear {
            if !directory.isEmpty {
                scanner.scan(directory: directory)
            }
        }
    }

    private func moveSelection(by offset: Int) {
        let count = scanner.commands.count
        guard count > 0 else { return }

        if let current = selectedIndex {
            let next = current + offset
            if next >= 0 && next < count {
                selectedIndex = next
            }
        } else {
            selectedIndex = offset > 0 ? 0 : count - 1
        }
    }
}
