import SwiftUI

struct JobCardView: View {
    let job: Job
    let status: JobStatus
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            // Top row: name + actions + status
            HStack(spacing: Theme.paddingSmall) {
                Text(job.name)
                    .font(Theme.monoBody.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Edit job")

                Button(action: onToggle) {
                    Image(systemName: job.enabled ? "pause.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(job.enabled ? Theme.warning : Theme.active)
                }
                .buttonStyle(.plain)
                .help(job.enabled ? "Disable" : "Enable")

                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(Theme.error)
                }
                .buttonStyle(.plain)
                .help("Delete job")

                statusBadge
            }

            // Prompt preview
            Text(job.prompt)
                .font(Theme.monoSmall)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)

            // Bottom row: schedule + model + directory
            HStack(spacing: Theme.paddingMedium) {
                Label(job.scheduleSummary, systemImage: "clock")
                Label(job.model.shortName, systemImage: "cpu")
                if !job.directory.isEmpty {
                    let dirName = (job.directory as NSString).lastPathComponent
                    Label(dirName, systemImage: "folder")
                        .lineLimit(1)
                }
            }
            .font(Theme.monoSmall)
            .foregroundStyle(Theme.textMuted)
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
