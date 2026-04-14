class SaleContactLog {
  final int id;
  final String date;
  final String channel;
  final String channelDisplay;
  final String counterparty;
  final String summary;
  final String? followUpDate;
  final int? relatedTask;

  SaleContactLog({
    required this.id,
    required this.date,
    required this.channel,
    this.channelDisplay = '',
    required this.counterparty,
    required this.summary,
    this.followUpDate,
    this.relatedTask,
  });

  factory SaleContactLog.fromJson(Map<String, dynamic> json) {
    return SaleContactLog(
      id: json['id'],
      date: json['date'] ?? '',
      channel: json['channel'] ?? '',
      channelDisplay: json['channel_display'] ?? '',
      counterparty: json['counterparty'] ?? '',
      summary: json['summary'] ?? '',
      followUpDate: json['follow_up_date'],
      relatedTask: json['related_task'],
    );
  }
}
