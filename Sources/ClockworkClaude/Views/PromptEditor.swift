import SwiftUI

struct PromptEditor: View {
    @Binding var prompt: String
    @Environment(CommandScanner.self) private var scanner
    @State private var showAutocomplete = false
    @State private var autocompleteQuery = ""
    @State private var selectedIndex = 0
    @State private var commandSource: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Prompt")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let source = commandSource {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                        Text(source)
                            .font(Theme.monoSmall)
                    }
                    .foregroundStyle(Theme.sonnet)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.sonnet.opacity(0.1))
                    )
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $prompt)
                    .font(Theme.monoBody)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(4)
                    .frame(minHeight: 100, maxHeight: 200)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .fill(Theme.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                    )
                    .onChange(of: prompt) { _, newValue in
                        checkForSlashCommand(newValue)
                    }

                if prompt.isEmpty {
                    Text("Enter your prompt or type / for commands...")
                        .font(Theme.monoBody)
                        .foregroundStyle(Theme.textMuted)
                        .padding(8)
                        .allowsHitTesting(false)
                }

                // Autocomplete popup
                if showAutocomplete {
                    autocompletePopup
                        .offset(y: 80)
                }
            }
        }
    }

    private var autocompletePopup: some View {
        let filtered = scanner.filteredCommands(for: autocompleteQuery)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, cmd in
                HStack {
                    Text(cmd.displayName)
                        .font(Theme.monoSmall.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(cmd.source)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.horizontal, Theme.paddingSmall)
                .padding(.vertical, 4)
                .background(index == selectedIndex ? Theme.sonnet.opacity(0.2) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectCommand(cmd)
                }
            }
        }
        .frame(maxWidth: 300)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Theme.border, lineWidth: 1)
                )
        )
    }

    private func checkForSlashCommand(_ text: String) {
        // Check if the text starts with or contains a / at the beginning
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") && !trimmed.contains(" ") {
            autocompleteQuery = trimmed
            selectedIndex = 0
            showAutocomplete = !scanner.filteredCommands(for: trimmed).isEmpty
        } else {
            showAutocomplete = false
        }
    }

    private func selectCommand(_ command: SlashCommand) {
        prompt = command.content
        commandSource = command.filePath
        showAutocomplete = false
    }

    func insertCommand(_ command: SlashCommand) {
        selectCommand(command)
    }
}
