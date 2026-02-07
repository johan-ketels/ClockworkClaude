import SwiftUI

struct JobListView: View {
    @Environment(JobStore.self) private var jobStore
    @Environment(LaunchdService.self) private var launchdService
    @Binding var selectedJob: Job?
    let onEdit: (Job) -> Void
    let onToggle: (Job) -> Void
    let onDelete: (Job) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.paddingSmall) {
                ForEach(jobStore.jobs) { job in
                    JobCardView(
                        job: job,
                        status: launchdService.cachedStatus(for: job),
                        isSelected: selectedJob?.id == job.id,
                        onSelect: { selectedJob = job },
                        onEdit: { onEdit(job) },
                        onToggle: { onToggle(job) },
                        onDelete: { onDelete(job) }
                    )
                }
            }
            .padding(Theme.paddingMedium)
        }
    }
}
