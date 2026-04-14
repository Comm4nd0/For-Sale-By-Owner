class SaleTask {
  final int id;
  final String title;
  final String description;
  final String currentOwner;
  final String currentOwnerDisplay;
  final String status;
  final String statusDisplay;
  final String? awaitingSince;
  final String awaitingReason;
  final String? dueDate;
  final String? completedAt;
  final String notes;
  final bool isSeed;
  final int order;
  final int daysAwaiting;
  final String stageName;
  final int stageNumber;
  final List<TaskOwnershipHistoryEntry> ownershipHistory;

  SaleTask({
    required this.id,
    required this.title,
    this.description = '',
    required this.currentOwner,
    this.currentOwnerDisplay = '',
    required this.status,
    this.statusDisplay = '',
    this.awaitingSince,
    this.awaitingReason = '',
    this.dueDate,
    this.completedAt,
    this.notes = '',
    this.isSeed = true,
    this.order = 0,
    this.daysAwaiting = 0,
    this.stageName = '',
    this.stageNumber = 0,
    this.ownershipHistory = const [],
  });

  factory SaleTask.fromJson(Map<String, dynamic> json) {
    return SaleTask(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      currentOwner: json['current_owner'] ?? '',
      currentOwnerDisplay: json['current_owner_display'] ?? '',
      status: json['status'] ?? 'not_started',
      statusDisplay: json['status_display'] ?? '',
      awaitingSince: json['awaiting_since'],
      awaitingReason: json['awaiting_reason'] ?? '',
      dueDate: json['due_date'],
      completedAt: json['completed_at'],
      notes: json['notes'] ?? '',
      isSeed: json['is_seed'] ?? true,
      order: json['order'] ?? 0,
      daysAwaiting: json['days_awaiting'] ?? 0,
      stageName: json['stage_name'] ?? '',
      stageNumber: json['stage_number'] ?? 0,
      ownershipHistory: json['ownership_history'] != null
          ? (json['ownership_history'] as List)
              .map((h) => TaskOwnershipHistoryEntry.fromJson(h))
              .toList()
          : [],
    );
  }

  bool get isDone => status == 'done';
  bool get isYourTurn => currentOwner == 'seller';
}

class TaskOwnershipHistoryEntry {
  final int id;
  final String fromOwner;
  final String fromOwnerDisplay;
  final String toOwner;
  final String toOwnerDisplay;
  final String transferredAt;
  final String reason;

  TaskOwnershipHistoryEntry({
    required this.id,
    required this.fromOwner,
    this.fromOwnerDisplay = '',
    required this.toOwner,
    this.toOwnerDisplay = '',
    required this.transferredAt,
    this.reason = '',
  });

  factory TaskOwnershipHistoryEntry.fromJson(Map<String, dynamic> json) {
    return TaskOwnershipHistoryEntry(
      id: json['id'],
      fromOwner: json['from_owner'] ?? '',
      fromOwnerDisplay: json['from_owner_display'] ?? '',
      toOwner: json['to_owner'] ?? '',
      toOwnerDisplay: json['to_owner_display'] ?? '',
      transferredAt: json['transferred_at'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}
