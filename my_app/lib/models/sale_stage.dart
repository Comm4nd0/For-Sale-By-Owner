import 'sale_task.dart';

class SaleStage {
  final int id;
  final int stageNumber;
  final String name;
  final String status;
  final String statusDisplay;
  final String? startedAt;
  final String? completedAt;
  final List<SaleTask> tasks;
  final int taskCount;
  final int completedTaskCount;

  SaleStage({
    required this.id,
    required this.stageNumber,
    required this.name,
    required this.status,
    this.statusDisplay = '',
    this.startedAt,
    this.completedAt,
    this.tasks = const [],
    this.taskCount = 0,
    this.completedTaskCount = 0,
  });

  factory SaleStage.fromJson(Map<String, dynamic> json) {
    return SaleStage(
      id: json['id'],
      stageNumber: json['stage_number'] ?? 0,
      name: json['name'] ?? '',
      status: json['status'] ?? 'not_started',
      statusDisplay: json['status_display'] ?? '',
      startedAt: json['started_at'],
      completedAt: json['completed_at'],
      tasks: json['tasks'] != null
          ? (json['tasks'] as List).map((t) => SaleTask.fromJson(t)).toList()
          : [],
      taskCount: json['task_count'] ?? 0,
      completedTaskCount: json['completed_task_count'] ?? 0,
    );
  }

  bool get isDone => status == 'done';
  bool get isInProgress => status == 'in_progress';
}
