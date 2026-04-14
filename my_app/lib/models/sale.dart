import 'sale_stage.dart';

class Sale {
  final int id;
  final String propertyAddress;
  final String? askingPrice;
  final String? agreedPrice;
  final String tenure;
  final String tenureDisplay;
  final String status;
  final String statusDisplay;
  final String buyerName;
  final String agentName;
  final String agentContact;
  final String sellerConveyancerName;
  final String sellerConveyancerContact;
  final String buyerConveyancerName;
  final String buyerConveyancerContact;
  final String buyerPosition;
  final String buyerPositionDisplay;
  final int chainLength;
  final String? targetExchangeDate;
  final String? targetCompletionDate;
  final String? instructedAt;
  final String notificationFrequency;
  final String notificationFrequencyDisplay;
  final List<SaleStage> stages;
  final int? daysSinceInstruction;
  final int? daysToTargetExchange;
  final int? daysToTargetCompletion;
  final String? currentStageName;
  final int? currentStageNumber;
  final int totalTasks;
  final int completedTasks;
  final int yourTurnCount;
  final String createdAt;

  Sale({
    required this.id,
    required this.propertyAddress,
    this.askingPrice,
    this.agreedPrice,
    required this.tenure,
    this.tenureDisplay = '',
    required this.status,
    this.statusDisplay = '',
    this.buyerName = '',
    this.agentName = '',
    this.agentContact = '',
    this.sellerConveyancerName = '',
    this.sellerConveyancerContact = '',
    this.buyerConveyancerName = '',
    this.buyerConveyancerContact = '',
    this.buyerPosition = '',
    this.buyerPositionDisplay = '',
    this.chainLength = 0,
    this.targetExchangeDate,
    this.targetCompletionDate,
    this.instructedAt,
    this.notificationFrequency = 'daily_digest',
    this.notificationFrequencyDisplay = '',
    this.stages = const [],
    this.daysSinceInstruction,
    this.daysToTargetExchange,
    this.daysToTargetCompletion,
    this.currentStageName,
    this.currentStageNumber,
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.yourTurnCount = 0,
    this.createdAt = '',
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'],
      propertyAddress: json['property_address'] ?? '',
      askingPrice: json['asking_price']?.toString(),
      agreedPrice: json['agreed_price']?.toString(),
      tenure: json['tenure'] ?? '',
      tenureDisplay: json['tenure_display'] ?? '',
      status: json['status'] ?? '',
      statusDisplay: json['status_display'] ?? '',
      buyerName: json['buyer_name'] ?? '',
      agentName: json['agent_name'] ?? '',
      agentContact: json['agent_contact'] ?? '',
      sellerConveyancerName: json['seller_conveyancer_name'] ?? '',
      sellerConveyancerContact: json['seller_conveyancer_contact'] ?? '',
      buyerConveyancerName: json['buyer_conveyancer_name'] ?? '',
      buyerConveyancerContact: json['buyer_conveyancer_contact'] ?? '',
      buyerPosition: json['buyer_position'] ?? '',
      buyerPositionDisplay: json['buyer_position_display'] ?? '',
      chainLength: json['chain_length'] ?? 0,
      targetExchangeDate: json['target_exchange_date'],
      targetCompletionDate: json['target_completion_date'],
      instructedAt: json['instructed_at'],
      notificationFrequency: json['notification_frequency'] ?? 'daily_digest',
      notificationFrequencyDisplay: json['notification_frequency_display'] ?? '',
      stages: json['stages'] != null
          ? (json['stages'] as List).map((s) => SaleStage.fromJson(s)).toList()
          : [],
      daysSinceInstruction: json['days_since_instruction'],
      daysToTargetExchange: json['days_to_target_exchange'],
      daysToTargetCompletion: json['days_to_target_completion'],
      currentStageName: json['current_stage_name'],
      currentStageNumber: json['current_stage_number'],
      totalTasks: json['total_tasks'] ?? 0,
      completedTasks: json['completed_tasks'] ?? 0,
      yourTurnCount: json['your_turn_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isInstructed => instructedAt != null;
  double get progressPercent =>
      totalTasks > 0 ? completedTasks / totalTasks : 0.0;
}
