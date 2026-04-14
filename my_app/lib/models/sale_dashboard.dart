class SaleDashboard {
  final List<DashboardItem> yourTurn;
  final Map<String, List<DashboardItem>> awaitingOthers;
  final HeadlineNumbers headlineNumbers;
  final List<ExpiringDocument> expiringDocuments;
  final ReadinessData? readiness;

  SaleDashboard({
    required this.yourTurn,
    required this.awaitingOthers,
    required this.headlineNumbers,
    required this.expiringDocuments,
    this.readiness,
  });

  factory SaleDashboard.fromJson(Map<String, dynamic> json) {
    // Parse awaiting_others
    final awaitingMap = <String, List<DashboardItem>>{};
    if (json['awaiting_others'] != null) {
      (json['awaiting_others'] as Map<String, dynamic>).forEach((key, value) {
        awaitingMap[key] = (value as List)
            .map((i) => DashboardItem.fromJson(i))
            .toList();
      });
    }

    return SaleDashboard(
      yourTurn: json['your_turn'] != null
          ? (json['your_turn'] as List)
              .map((i) => DashboardItem.fromJson(i))
              .toList()
          : [],
      awaitingOthers: awaitingMap,
      headlineNumbers: HeadlineNumbers.fromJson(
        json['headline_numbers'] ?? {},
      ),
      expiringDocuments: json['expiring_documents'] != null
          ? (json['expiring_documents'] as List)
              .map((d) => ExpiringDocument.fromJson(d))
              .toList()
          : [],
      readiness: json['readiness'] != null
          ? ReadinessData.fromJson(json['readiness'])
          : null,
    );
  }
}

class DashboardItem {
  final int id;
  final String title;
  final String currentOwner;
  final String currentOwnerDisplay;
  final String status;
  final int daysAwaiting;
  final String? awaitingSince;
  final String? stageName;
  final int? stageNumber;
  final String type;

  DashboardItem({
    required this.id,
    required this.title,
    required this.currentOwner,
    this.currentOwnerDisplay = '',
    required this.status,
    this.daysAwaiting = 0,
    this.awaitingSince,
    this.stageName,
    this.stageNumber,
    this.type = 'task',
  });

  factory DashboardItem.fromJson(Map<String, dynamic> json) {
    return DashboardItem(
      id: json['id'],
      title: json['title'] ?? '',
      currentOwner: json['current_owner'] ?? '',
      currentOwnerDisplay: json['current_owner_display'] ?? '',
      status: json['status'] ?? '',
      daysAwaiting: json['days_awaiting'] ?? 0,
      awaitingSince: json['awaiting_since'],
      stageName: json['stage_name'],
      stageNumber: json['stage_number'],
      type: json['type'] ?? 'task',
    );
  }
}

class HeadlineNumbers {
  final int totalTasks;
  final int completedTasks;
  final int? currentStageNumber;
  final String? currentStageName;
  final int? daysSinceInstruction;
  final int? daysToTargetExchange;
  final int? daysToTargetCompletion;

  HeadlineNumbers({
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.currentStageNumber,
    this.currentStageName,
    this.daysSinceInstruction,
    this.daysToTargetExchange,
    this.daysToTargetCompletion,
  });

  factory HeadlineNumbers.fromJson(Map<String, dynamic> json) {
    return HeadlineNumbers(
      totalTasks: json['total_tasks'] ?? 0,
      completedTasks: json['completed_tasks'] ?? 0,
      currentStageNumber: json['current_stage_number'],
      currentStageName: json['current_stage_name'],
      daysSinceInstruction: json['days_since_instruction'],
      daysToTargetExchange: json['days_to_target_exchange'],
      daysToTargetCompletion: json['days_to_target_completion'],
    );
  }
}

class ExpiringDocument {
  final int id;
  final String title;
  final String expiryDate;
  final String category;

  ExpiringDocument({
    required this.id,
    required this.title,
    required this.expiryDate,
    this.category = '',
  });

  factory ExpiringDocument.fromJson(Map<String, dynamic> json) {
    return ExpiringDocument(
      id: json['id'],
      title: json['title'] ?? '',
      expiryDate: json['expiry_date'] ?? '',
      category: json['category'] ?? '',
    );
  }
}

class ReadinessData {
  final bool ready;
  final List<Map<String, dynamic>> missingAlways;
  final List<Map<String, dynamic>> missingIfApplicable;
  final List<String> warnings;
  final int totalDocuments;
  final int documentsReady;

  ReadinessData({
    required this.ready,
    this.missingAlways = const [],
    this.missingIfApplicable = const [],
    this.warnings = const [],
    this.totalDocuments = 0,
    this.documentsReady = 0,
  });

  factory ReadinessData.fromJson(Map<String, dynamic> json) {
    return ReadinessData(
      ready: json['ready'] ?? false,
      missingAlways: json['missing_always'] != null
          ? (json['missing_always'] as List)
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
          : [],
      missingIfApplicable: json['missing_if_applicable'] != null
          ? (json['missing_if_applicable'] as List)
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
          : [],
      warnings: json['warnings'] != null
          ? (json['warnings'] as List).map((w) => w.toString()).toList()
          : [],
      totalDocuments: json['total_documents'] ?? 0,
      documentsReady: json['documents_ready'] ?? 0,
    );
  }

  double get readinessPercent =>
      totalDocuments > 0 ? documentsReady / totalDocuments : 0.0;
}
