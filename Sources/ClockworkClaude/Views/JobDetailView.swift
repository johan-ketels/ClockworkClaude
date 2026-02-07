import SwiftUI

struct JobDetailView: View {
    let job: Job?
    let status: JobStatus
    let allJobs: [Job]
    var showHeader: Bool = true
    let onEdit: () -> Void
    let onRunNow: () -> Void
    let onToggle: () -> Void

    @Environment(LaunchdService.self) private var launchdService

    private var allJobNames: [String] { allJobs.map(\.name) }

    @State private var historyService = HistoryService()
    @State private var logWatcher = LogWatcher()
    @State private var selection: RunSelection = .live
    @State private var showingStderr = false
    @State private var showInfo = false
    @State private var now = Date()
    @State private var countdownTimer: Timer?

    private var isAllJobsMode: Bool { job == nil }

    enum RunSelection: Hashable {
        case live
        case historical(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showHeader {
                header
                Divider().background(Theme.border)
            }

            HSplitView {
                runList
                    .frame(minWidth: 240, idealWidth: 300)
                outputPanel
                    .frame(minWidth: 400)
            }
        }
        .background(Theme.background)
        .onAppear {
            loadCurrentHistory()
            startWatching()
            if let job {
                if status.pid != nil {
                    logWatcher.watch(path: job.stdoutLogPath)
                    selection = .live
                } else {
                    selection = historyService.records.first.map { .historical($0.id) } ?? .live
                }
            }
            startCountdown()
        }
        .onDisappear {
            historyService.stopWatching()
            logWatcher.stop()
            countdownTimer?.invalidate()
        }
        .onChange(of: job?.id) { _, _ in
            loadCurrentHistory()
            startWatching()
            if let job {
                if status.pid != nil {
                    logWatcher.watch(path: job.stdoutLogPath)
                    selection = .live
                } else {
                    selection = historyService.records.first.map { .historical($0.id) } ?? .live
                }
            } else {
                logWatcher.stop()
                selection = historyService.records.first.map { .historical($0.id) } ?? .live
            }
            showingStderr = false
        }
        .onChange(of: status.pid) { oldPid, newPid in
            guard let job else { return }
            if newPid != nil {
                logWatcher.watch(path: job.stdoutLogPath)
                selection = .live
            } else if oldPid != nil {
                loadCurrentHistory()
                selection = historyService.records.first.map { .historical($0.id) } ?? .live
            }
        }
        .popover(isPresented: $showInfo, arrowEdge: .bottom) {
            if let job {
                infoPopover(for: job)
            }
        }
    }

    private func loadCurrentHistory() {
        if let job {
            historyService.loadHistory(for: job.name)
        } else {
            historyService.loadAllHistory(jobNames: allJobNames)
        }
    }

    private func startWatching() {
        if let job {
            historyService.watchHistory(for: job.name)
        } else {
            historyService.watchAllHistory(jobNames: allJobNames)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            if let job {
                // Filtered mode header
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

                    Button(action: onRunNow) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                            Text("Run Now")
                        }
                        .font(Theme.monoSmall)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.active)

                    Button(action: onToggle) {
                        HStack(spacing: 4) {
                            Image(systemName: job.enabled ? "pause.fill" : "play.fill")
                            Text(job.enabled ? "Disable" : "Enable")
                        }
                        .font(Theme.monoSmall)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(Theme.monoSmall)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // All-jobs mode header
                HStack(spacing: Theme.paddingSmall) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(Theme.sonnet)
                    Text("All Runs")
                        .font(Theme.monoHeading)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Button(action: { loadCurrentHistory() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(Theme.monoSmall)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, Theme.paddingLarge)
        .padding(.vertical, Theme.paddingMedium)
        .background(Theme.surface)
    }

    // MARK: - Run List (left column)

    private var runList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Theme.sonnet)
                    .font(.caption)
                Text(job.map { "Runs — \($0.name)" } ?? "All Runs")
                    .font(Theme.monoSmall.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text("(\(historyService.records.count))")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.textMuted)
                Spacer()
                Button(action: { loadCurrentHistory() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .padding(.horizontal, Theme.paddingMedium)
            .padding(.vertical, Theme.paddingSmall)

            Divider().background(Theme.border)

            ScrollView {
                LazyVStack(spacing: 0) {
                    if let job {
                        // Filtered mode: show next run + live row
                        if job.enabled && job.scheduleType != .once {
                            nextRunRow(for: job)
                            Divider().background(Theme.border).padding(.horizontal, Theme.paddingSmall)
                        }

                        if status.pid != nil {
                            liveRow(for: job)
                            Divider().background(Theme.border).padding(.horizontal, Theme.paddingSmall)
                        }
                    } else {
                        // All-jobs mode: show upcoming runs for all active scheduled jobs
                        let scheduled = upcomingJobs
                        if !scheduled.isEmpty {
                            ForEach(scheduled, id: \.0.id) { scheduledJob, _ in
                                nextRunRow(for: scheduledJob)
                                Divider().background(Theme.border).padding(.horizontal, Theme.paddingSmall)
                            }
                        }
                    }

                    // Historical entries
                    ForEach(historyService.records) { record in
                        historyRow(record)
                        Divider().background(Theme.border.opacity(0.5)).padding(.horizontal, Theme.paddingMedium)
                    }
                }
            }
        }
        .background(Theme.surface)
    }

    // MARK: - Upcoming Jobs

    private var upcomingJobs: [(Job, Date)] {
        allJobs
            .filter { $0.enabled && $0.scheduleType != .once }
            .compactMap { j in nextRunDate(for: j).map { (j, $0) } }
            .sorted { $0.1 < $1.1 }
    }

    // MARK: - Next Run Row

    private func nextRunRow(for job: Job) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Theme.paddingSmall) {
                Image(systemName: "timer")
                    .font(.caption2)
                    .foregroundStyle(Theme.warning)
                if isAllJobsMode {
                    Text(job.name)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    modelBadge(for: job)
                } else {
                    Text("Next run")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Text(countdownText(for: job))
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(Theme.warning)
            }
            if let next = nextRunDate(for: job) {
                Text(nextRunTimestamp(next))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 14)
            }
            Text(job.scheduleSummary)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.textMuted)
                .padding(.leading, 14)
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingSmall)
        .background(Theme.warning.opacity(0.05))
    }

    // MARK: - Live Row

    private func liveRow(for job: Job) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Theme.paddingSmall) {
                Circle()
                    .fill(status.pid != nil ? Theme.active : Theme.textMuted)
                    .frame(width: 6, height: 6)
                    .shadow(color: status.pid != nil ? Theme.active.opacity(0.6) : .clear, radius: 4)

                Text("Live")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if status.pid != nil {
                    Text("running")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.active)
                } else if let exitCode = status.lastExitCode {
                    exitBadge(exitCode)
                }
            }

            // Second line: PID or last status info
            if let pid = status.pid {
                Text("PID \(pid)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textMuted)
            } else {
                Text(logWatcher.logContent.isEmpty ? "Waiting for output..." : "Last run output")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingSmall)
        .background(selection == .live ? Theme.sonnet.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selection = .live
            showingStderr = false
            logWatcher.watch(path: job.stdoutLogPath)
        }
    }

    // MARK: - History Row

    private func historyRow(_ record: RunRecord) -> some View {
        let matchedJob = allJobs.first(where: { $0.name == record.jobName })

        return VStack(alignment: .leading, spacing: 2) {
            // Line 1: status dot + job name + model badge + exit badge
            HStack(spacing: Theme.paddingSmall) {
                Circle()
                    .fill(statusColor(record))
                    .frame(width: 6, height: 6)

                Text(record.jobName)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if let matchedJob {
                    modelBadge(for: matchedJob)
                }

                Spacer()

                if let exitCode = record.exitCode {
                    exitBadge(exitCode)
                }
            }

            // Line 2: timestamp
            Text(record.displayTimestamp)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 10)

            // Line 3: duration + output preview
            HStack(spacing: Theme.paddingMedium) {
                HStack(spacing: 4) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textMuted)
                    Text(record.displayDuration)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textMuted)
                }

                Text(record.outputPreview)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }
            .padding(.leading, 10)
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingSmall)
        .background(selection == .historical(record.id) ? Theme.sonnet.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selection = .historical(record.id)
        }
    }

    // MARK: - Output Panel (right column)

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(Theme.sonnet)
                    .font(.caption)
                Text(outputTitle)
                    .font(Theme.monoSmall.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)

                // Show duration for selected historical run
                if case .historical(let id) = selection,
                   let record = historyService.records.first(where: { $0.id == id }),
                   record.duration != nil {
                    Text(record.displayDuration)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Theme.surface)
                        )
                }

                Spacer()

                if !isAllJobsMode || selection != .live {
                    HStack(spacing: 2) {
                        tabButton("stdout", isActive: !showingStderr, color: Theme.sonnet) {
                            showingStderr = false
                            if case .live = selection, let job {
                                logWatcher.watch(path: job.stdoutLogPath)
                            }
                        }
                        tabButton("stderr", isActive: showingStderr, color: Theme.error) {
                            showingStderr = true
                            if case .live = selection, let job {
                                logWatcher.watch(path: job.stderrLogPath)
                            }
                        }
                    }
                }

                Button(action: copyOutput) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Copy output")
            }
            .padding(.horizontal, Theme.paddingMedium)
            .padding(.vertical, Theme.paddingSmall)

            Divider().background(Theme.border)

            ScrollViewReader { proxy in
                ScrollView {
                    let text = currentOutput
                    Text(text)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(text == emptyPlaceholder ? Theme.textMuted : Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.paddingSmall)
                        .textSelection(.enabled)
                        .id("outputBottom")
                }
                .onChange(of: logWatcher.logContent) { _, _ in
                    if case .live = selection {
                        withAnimation {
                            proxy.scrollTo("outputBottom", anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(hex: 0x1C1C1A))
        }
        .background(Theme.surface)
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

    // MARK: - Countdown

    private func startCountdown() {
        now = Date()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            now = Date()
        }
    }

    private func countdownText(for job: Job) -> String {
        let jobStatus = launchdService.cachedStatus(for: job)
        if jobStatus.pid != nil { return "running..." }
        guard let next = nextRunDate(for: job) else { return "—" }
        let remaining = next.timeIntervalSince(now)
        if remaining <= 0 { return "any moment..." }

        let total = Int(remaining)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if h > 0 {
            return String(format: "in %dh %02dm", h, m)
        } else if m > 0 {
            return String(format: "in %dm %02ds", m, s)
        } else {
            return "in \(s)s"
        }
    }

    private func nextRunDate(for job: Job) -> Date? {
        guard job.enabled else { return nil }

        switch job.scheduleType {
        case .once:
            return nil

        case .interval:
            if job.intervalAlignment == .fromLoad {
                let seconds = job.intervalUnit == .hours
                    ? job.intervalValue * 3600
                    : job.intervalValue * 60
                if let lastRun = historyService.records.first?.timestamp {
                    return lastRun.addingTimeInterval(TimeInterval(seconds))
                }
                return nil
            } else {
                // On the hour — find next matching hour
                let hours = onTheHourTimes(every: job.intervalValue)
                let cal = Calendar.current
                let currentHour = cal.component(.hour, from: now)
                let currentMinute = cal.component(.minute, from: now)

                for hour in hours {
                    if hour > currentHour || (hour == currentHour && currentMinute == 0) {
                        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: now)
                    }
                }
                // Wrap to tomorrow's first hour
                if let firstHour = hours.first,
                   let tomorrow = cal.date(byAdding: .day, value: 1, to: now) {
                    return cal.date(bySettingHour: firstHour, minute: 0, second: 0, of: tomorrow)
                }
                return nil
            }

        case .calendar:
            var components = DateComponents()
            components.hour = job.calendarHour
            components.minute = job.calendarMinute
            if job.calendarWeekday >= 0 {
                components.weekday = job.calendarWeekday + 1 // Calendar: 1=Sun
            }
            return Calendar.current.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
        }
    }

    private func onTheHourTimes(every hours: Int) -> [Int] {
        guard hours > 0 && hours <= 24 else { return [0] }
        var times: [Int] = []
        var h = 0
        while h < 24 {
            times.append(h)
            h += hours
        }
        return times
    }

    private func nextRunTimestamp(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fmt.string(from: date)
    }

    // MARK: - Helpers

    private func exitBadge(_ exitCode: Int) -> some View {
        Text(exitCode == 0 ? "Complete" : "Failed (\(exitCode))")
            .font(.system(.caption2, design: .monospaced).weight(.medium))
            .foregroundStyle(exitCode == 0 ? Theme.active : Theme.error)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                Capsule().fill((exitCode == 0 ? Theme.active : Theme.error).opacity(0.12))
            )
    }

    private func tabButton(_ label: String, isActive: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(isActive ? .white : Theme.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isActive ? color : Color.clear)
                )
        }
        .buttonStyle(.plain)
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

    private let emptyPlaceholder = "No output yet."

    private var outputTitle: String {
        switch selection {
        case .live:
            return "Live Output"
        case .historical(let id):
            if let record = historyService.records.first(where: { $0.id == id }) {
                let prefix = isAllJobsMode ? "\(record.jobName) — " : ""
                return "\(prefix)\(record.displayTimestamp)"
            }
            return "Output"
        }
    }

    private var currentOutput: String {
        switch selection {
        case .live:
            if isAllJobsMode { return emptyPlaceholder }
            let content = logWatcher.logContent
            return content.isEmpty ? emptyPlaceholder : content
        case .historical(let id):
            guard let record = historyService.records.first(where: { $0.id == id }) else {
                return "Record not found."
            }
            if showingStderr {
                let err = record.errorOutput ?? ""
                return err.isEmpty ? "No stderr output." : err
            }
            return record.output.isEmpty ? "No output." : record.output
        }
    }

    private func copyOutput() {
        let text: String
        switch selection {
        case .live:
            text = logWatcher.logContent
        case .historical(let id):
            guard let record = historyService.records.first(where: { $0.id == id }) else { return }
            text = showingStderr ? (record.errorOutput ?? "") : record.output
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func statusColor(_ record: RunRecord) -> Color {
        guard let exitCode = record.exitCode else { return Theme.textMuted }
        return exitCode == 0 ? Theme.active : Theme.error
    }

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
}
