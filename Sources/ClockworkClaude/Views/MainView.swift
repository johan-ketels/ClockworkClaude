import SwiftUI

struct MainView: View {
    @Environment(JobStore.self) private var jobStore
    @Environment(LaunchdService.self) private var launchdService
    @Environment(CommandScanner.self) private var commandScanner
    @State private var selectedJob: Job?
    @State private var showingNewJobForm = false
    @State private var editingJob: Job?
    @State private var statusTimer: Timer?
    @State private var showInfo = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().background(Theme.border)
            HStack(spacing: 0) {
                sidebarContent
                    .frame(width: 320)
                Divider().background(Theme.border)
                detail
            }
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingNewJobForm) {
            JobFormView(job: .makeDefault(), isNew: true)
                .environment(jobStore)
                .environment(launchdService)
                .environment(commandScanner)
                .frame(minWidth: 650, minHeight: 700)
        }
        .sheet(item: $editingJob) { job in
            JobFormView(job: job, isNew: false)
                .environment(jobStore)
                .environment(launchdService)
                .environment(commandScanner)
                .frame(minWidth: 650, minHeight: 700)
        }
        .onAppear { startStatusPolling() }
        .onDisappear { stopStatusPolling() }
    }

    // MARK: - Unified Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            // Sidebar portion
            HStack {
                Group {
                    if let url = Bundle.main.url(forResource: "logo", withExtension: "png"),
                       let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .frame(width: 28, height: 28)
                    }
                }
                VStack(alignment: .leading, spacing: -2) {
                    Text("Clockwork")
                        .font(.custom("Timepiece", size: 18))
                        .foregroundStyle(Theme.textPrimary)
                    Text("  Claude")
                        .font(.custom("Timepiece", size: 18))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Text("\(jobStore.jobs.count) jobs")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.textMuted)
                Text("\u{00B7}")
                    .foregroundStyle(Theme.textMuted)
                Text("\(jobStore.activeCount) active")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.active)
            }
            .padding(.horizontal, Theme.paddingLarge)
            .frame(width: 320)

            // Detail portion
            HStack(alignment: .center) {
                if let job = selectedJob, jobStore.jobs.contains(where: { $0.id == job.id }) {
                    selectedJobHeader(job)
                } else {
                    allRunsHeader
                }
            }
            .padding(.horizontal, Theme.paddingLarge)
        }
        .padding(.vertical, Theme.paddingMedium)
        .background(Theme.surface)
    }

    @ViewBuilder
    private func selectedJobHeader(_ job: Job) -> some View {
        HStack(spacing: Theme.paddingSmall) {
            Text(job.name)
                .font(Theme.monoHeading)
                .foregroundStyle(Theme.textPrimary)
            modelBadge(for: job)
            statusBadge(for: job)
        }

        Text(job.scheduleSummary)
            .font(Theme.monoSmall)
            .foregroundStyle(Theme.textMuted)
            .padding(.leading, Theme.paddingSmall)

        Spacer()

        HStack(spacing: Theme.paddingSmall) {
            Button(action: { showInfo.toggle() }) {
                Image(systemName: "info.circle")
                    .font(Theme.monoSmall)
            }
            .buttonStyle(.bordered)
            .help("Job details")
            .popover(isPresented: $showInfo, arrowEdge: .bottom) {
                infoPopover(for: job)
            }

            Button(action: { runNow(job) }) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                    Text("Run Now")
                }
                .font(Theme.monoSmall)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.active)

            Button(action: { toggleJob(job) }) {
                HStack(spacing: 4) {
                    Image(systemName: job.enabled ? "pause.fill" : "play.fill")
                    Text(job.enabled ? "Disable" : "Enable")
                }
                .font(Theme.monoSmall)
            }
            .buttonStyle(.bordered)

            Button(action: { editingJob = job }) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                    Text("Edit")
                }
                .font(Theme.monoSmall)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var allRunsHeader: some View {
        HStack(spacing: Theme.paddingSmall) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(Theme.sonnet)
            Text("All Runs")
                .font(Theme.monoHeading)
                .foregroundStyle(Theme.textPrimary)
        }
        Spacer()
    }

    // MARK: - Sidebar Content

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: Theme.paddingSmall) {
                    ForEach(jobStore.jobs) { job in
                        JobCardView(
                            job: job,
                            status: launchdService.cachedStatus(for: job),
                            isSelected: selectedJob?.id == job.id,
                            onSelect: { selectedJob = job },
                            onEdit: { editingJob = job },
                            onToggle: { toggleJob(job) },
                            onDelete: { deleteJob(job) }
                        )
                    }
                }
                .padding(Theme.paddingMedium)
            }
            .background(Theme.background)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedJob = nil
            }

            Divider().background(Theme.border)

            HStack {
                Spacer()
                Button(action: { showingNewJobForm = true }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(Theme.sonnet)
                }
                .buttonStyle(.plain)
                .help("Create new job")
            }
            .padding(.horizontal, Theme.paddingLarge)
            .padding(.vertical, Theme.paddingSmall)
            .background(Theme.surface)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let job = selectedJob, jobStore.jobs.contains(where: { $0.id == job.id }) {
            JobDetailView(
                job: job,
                status: launchdService.cachedStatus(for: job),
                allJobs: jobStore.jobs,
                showHeader: false,
                onEdit: { editingJob = job },
                onRunNow: { runNow(job) },
                onToggle: { toggleJob(job) }
            )
        } else {
            JobDetailView(
                job: nil,
                status: JobStatus(),
                allJobs: jobStore.jobs,
                showHeader: false,
                onEdit: {},
                onRunNow: {},
                onToggle: {}
            )
        }
    }

    // MARK: - Badge Helpers

    private func modelBadge(for job: Job) -> some View {
        Text(job.model.shortName)
            .font(.system(.caption2, design: .monospaced).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.modelColor(job.model)))
    }

    private func statusBadge(for job: Job) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(job.enabled ? Theme.active : Theme.inactive)
                .frame(width: 6, height: 6)
                .shadow(color: job.enabled ? Theme.active.opacity(0.6) : .clear, radius: 4)
            Text(job.enabled ? "Active" : "Inactive")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(job.enabled ? Theme.active : Theme.inactive)
        }
    }

    // MARK: - Info Popover

    private func infoPopover(for job: Job) -> some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                sectionLabel("Configuration")
                configRow("Model", job.model.displayName)
                configRow("Permissions", job.permissionPreset.displayName)
                configRow("Max turns", "\(job.maxTurns)")
                configRow("Output format", job.outputFormat.displayName)
                configRow("Directory", job.directory)
                if !job.appendSystemPrompt.isEmpty {
                    configRow("System prompt", job.appendSystemPrompt)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                sectionLabel("Prompt")
                Text(job.prompt)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(Theme.paddingSmall)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .fill(Color(hex: 0x1C1C1A))
                    )
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                sectionLabel("CLI Command")
                Text(job.cliCommand)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(Theme.paddingSmall)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .fill(Color(hex: 0x1C1C1A))
                    )
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                sectionLabel("Installation")
                let cmds = """
                launchctl load \(job.plistPath)
                launchctl unload \(job.plistPath)
                launchctl start \(job.launchdLabel)
                """
                Text(cmds)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(Theme.paddingSmall)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .fill(Color(hex: 0x1C1C1A))
                    )
            }
        }
        .padding(Theme.paddingLarge)
        .frame(width: 500)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.monoSmall.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
    }

    private func configRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
        }
    }

    // MARK: - Actions

    private func toggleJob(_ job: Job) {
        guard var updated = jobStore.jobs.first(where: { $0.id == job.id }) else { return }
        updated.enabled.toggle()
        jobStore.update(updated)
        launchdService.toggle(updated)
        if selectedJob?.id == job.id {
            selectedJob = updated
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            launchdService.refreshStatus(for: jobStore.jobs)
        }
    }

    private func deleteJob(_ job: Job) {
        launchdService.uninstall(job)
        jobStore.delete(job)
        if selectedJob?.id == job.id {
            selectedJob = nil
        }
    }

    private func runNow(_ job: Job) {
        let status = launchdService.status(label: job.launchdLabel)
        if !status.isLoaded {
            launchdService.install(job)
        }
        launchdService.runNow(job)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            launchdService.refreshStatus(for: jobStore.jobs)
        }
    }

    private func startStatusPolling() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            launchdService.refreshStatus(for: jobStore.jobs)
        }
    }

    private func stopStatusPolling() {
        statusTimer?.invalidate()
        statusTimer = nil
    }
}
