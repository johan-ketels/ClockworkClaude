import SwiftUI

struct JobFormView: View {
    @Environment(JobStore.self) private var jobStore
    @Environment(LaunchdService.self) private var launchdService
    @Environment(CommandScanner.self) private var scanner
    @Environment(\.dismiss) private var dismiss

    @State var job: Job
    let isNew: Bool

    @AppStorage("lastWorkingDirectory") private var lastWorkingDirectory: String = ""
    @State private var showAdvanced = false
    @State private var nameError: String?
    @State private var showDirectoryPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNew ? "New Job" : "Edit Job")
                    .font(Theme.monoHeading)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.paddingLarge)
            .background(Theme.surface)

            Divider().background(Theme.border)

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.paddingLarge) {
                    // Name and Model
                    HStack(spacing: Theme.paddingMedium) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Job name")
                                .font(Theme.monoSmall)
                                .foregroundStyle(Theme.textSecondary)
                            TextField("daily-review", text: $job.name)
                                .font(Theme.monoBody)
                                .textFieldStyle(ThemedTextFieldStyle())
                                .onChange(of: job.name) { _, newValue in
                                    validateName(newValue)
                                }
                            if let error = nameError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(Theme.error)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model")
                                .font(Theme.monoSmall)
                                .foregroundStyle(Theme.textSecondary)
                            Picker("", selection: $job.model) {
                                ForEach(ClaudeModel.allCases) { model in
                                    HStack {
                                        Circle()
                                            .fill(Theme.modelColor(model))
                                            .frame(width: 8, height: 8)
                                        Text(model.displayName)
                                    }
                                    .tag(model)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 160)
                        }
                    }

                    // Working directory
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Working directory")
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.textSecondary)
                        HStack {
                            TextField("/Users/you/project", text: $job.directory)
                                .font(Theme.monoBody)
                                .textFieldStyle(ThemedTextFieldStyle())
                            Button("Browse...") {
                                pickDirectory()
                            }
                        }
                    }

                    // Slash commands panel
                    if !job.directory.isEmpty {
                        SlashCommandPanel(directory: job.directory) { command in
                            job.prompt = command.displayName
                        }
                    }

                    // Prompt
                    PromptEditor(prompt: $job.prompt)

                    // Schedule
                    ScheduleEditor(
                        scheduleType: $job.scheduleType,
                        intervalValue: $job.intervalValue,
                        intervalUnit: $job.intervalUnit,
                        intervalAlignment: $job.intervalAlignment,
                        calendarWeekday: $job.calendarWeekday,
                        calendarHour: $job.calendarHour,
                        calendarMinute: $job.calendarMinute
                    )

                    // Permissions
                    PermissionEditor(
                        permissionPreset: $job.permissionPreset,
                        customTools: $job.customTools
                    )

                    // Advanced section
                    advancedSection
                }
                .padding(Theme.paddingLarge)
            }
            .background(Theme.background)

            Divider().background(Theme.border)

            // Footer buttons
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button(isNew ? "Create Job" : "Save") {
                    saveJob()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.sonnet)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(Theme.paddingLarge)
            .background(Theme.surface)
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .onAppear {
            if isNew && job.directory.isEmpty && !lastWorkingDirectory.isEmpty {
                job.directory = lastWorkingDirectory
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            Button(action: { withAnimation { showAdvanced.toggle() } }) {
                HStack {
                    Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                        .font(.caption)
                    Text("Advanced")
                        .font(Theme.monoBody.weight(.semibold))
                    if hasAdvancedModifications {
                        Text("modified")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Theme.warning.opacity(0.15))
                            )
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(alignment: .leading, spacing: Theme.paddingMedium) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System prompt")
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.textSecondary)
                        TextEditor(text: $job.appendSystemPrompt)
                            .font(Theme.monoBody)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(4)
                            .frame(minHeight: 60, maxHeight: 120)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                    .fill(Theme.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                            )
                        Text("Appended to Claude's system prompt via --append-system-prompt")
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                    }

                    HStack(spacing: Theme.paddingLarge) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max turns")
                                .font(Theme.monoSmall)
                                .foregroundStyle(Theme.textSecondary)
                            TextField("", value: $job.maxTurns, format: .number)
                                .font(Theme.monoBody)
                                .textFieldStyle(ThemedTextFieldStyle())
                                .frame(width: 80)
                            Text("Limits the number of agentic turns")
                                .font(.caption)
                                .foregroundStyle(Theme.textMuted)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output format")
                                .font(Theme.monoSmall)
                                .foregroundStyle(Theme.textSecondary)
                            Picker("", selection: $job.outputFormat) {
                                ForEach(OutputFormat.allCases, id: \.self) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)
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
            }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !job.name.isEmpty && !job.prompt.isEmpty && !job.directory.isEmpty && nameError == nil
    }

    private var hasAdvancedModifications: Bool {
        job.maxTurns != 10 || job.outputFormat != .text || !job.appendSystemPrompt.isEmpty
    }

    private func validateName(_ name: String) {
        let sanitized = name.replacingOccurrences(of: " ", with: "-").lowercased()
        if sanitized != name {
            job.name = sanitized
        }

        if name.isEmpty {
            nameError = nil
            return
        }

        let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if name.unicodeScalars.contains(where: { !validChars.contains($0) }) {
            nameError = "Only letters, numbers, hyphens and underscores"
            return
        }

        if isNew, jobStore.jobs.contains(where: { $0.name == name }) {
            nameError = "Name already in use"
            return
        }

        nameError = nil
    }

    // MARK: - Actions

    private func saveJob() {
        lastWorkingDirectory = job.directory
        if isNew {
            jobStore.add(job)
            if job.enabled {
                launchdService.install(job)
            }
        } else {
            // Unload old, update, reinstall if enabled
            launchdService.unload(job)
            jobStore.update(job)
            if job.enabled {
                launchdService.install(job)
            }
        }
        dismiss()
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select working directory for the Claude job"

        if panel.runModal() == .OK, let url = panel.url {
            job.directory = url.path
        }
    }
}
