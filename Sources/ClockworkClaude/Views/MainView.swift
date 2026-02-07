import SwiftUI

struct MainView: View {
    @Environment(JobStore.self) private var jobStore
    @Environment(LaunchdService.self) private var launchdService
    @Environment(CommandScanner.self) private var commandScanner
    @State private var selectedJob: Job?
    @State private var showingNewJobForm = false
    @State private var editingJob: Job?
    @State private var statusTimer: Timer?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
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

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gearshape.2")
                    .font(.title3)
                    .foregroundStyle(Theme.sonnet)
                Text("Clockwork Claude")
                    .font(Theme.monoLarge)
                    .foregroundStyle(Theme.textPrimary)
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
            .padding(.vertical, Theme.paddingMedium)
            .background(Theme.surface)

            Divider().background(Theme.border)

            // Job list
            ScrollView {
                LazyVStack(spacing: Theme.paddingSmall) {
                    ForEach(jobStore.jobs) { job in
                        JobCardView(
                            job: job,
                            status: launchdService.cachedStatus(for: job),
                            isSelected: selectedJob?.id == job.id,
                            onSelect: { selectedJob = job },
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

            // Footer
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
        .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 450)
    }

    @ViewBuilder
    private var detail: some View {
        if let job = selectedJob, jobStore.jobs.contains(where: { $0.id == job.id }) {
            JobDetailView(
                job: job,
                status: launchdService.cachedStatus(for: job),
                allJobs: jobStore.jobs,
                onEdit: { editingJob = job },
                onRunNow: { runNow(job) },
                onToggle: { toggleJob(job) }
            )
        } else {
            JobDetailView(
                job: nil,
                status: JobStatus(),
                allJobs: jobStore.jobs,
                onEdit: {},
                onRunNow: {},
                onToggle: {}
            )
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
        // Ensure it's loaded first
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
