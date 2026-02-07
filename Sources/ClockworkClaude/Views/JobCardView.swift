import SwiftUI

struct JobCardView: View {
    let job: Job
    let status: JobStatus
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            // Top row: name + model badge + status
            HStack {
                Text(job.name)
                    .font(Theme.monoBody.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                modelBadge
                statusBadge
            }

            // Prompt preview
            Text(job.prompt)
                .font(Theme.monoSmall)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)

            // Bottom row: schedule + directory + actions
            HStack {
                Label(job.scheduleSummary, systemImage: "clock")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.textMuted)

                Spacer()

                if !job.directory.isEmpty {
                    let dirName = (job.directory as NSString).lastPathComponent
                    Label(dirName, systemImage: "folder")
                        .font(Theme.monoSmall)
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                // Toggle
                Button(action: onToggle) {
                    Image(systemName: job.enabled ? "pause.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(job.enabled ? Theme.warning : Theme.active)
                }
                .buttonStyle(.plain)
                .help(job.enabled ? "Disable" : "Enable")

                // Delete
                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(Theme.error)
                }
                .buttonStyle(.plain)
                .help("Delete job")
            }
        }
        .padding(Theme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(isSelected ? Theme.surfaceHover : Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(isSelected ? Theme.sonnet.opacity(0.5) : Theme.border, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .alert("Delete Job", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Delete '\(job.name)'? This will unload the launchd job and remove the plist.")
        }
    }

    private var modelBadge: some View {
        Text(job.model.shortName)
            .font(.system(.caption2, design: .monospaced).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Theme.modelColor(job.model))
            )
    }

    private var statusBadge: some View {
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
