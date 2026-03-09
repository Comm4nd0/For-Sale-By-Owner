import 'subscription_tier.dart';

class ProviderSubscription {
  final int id;
  final SubscriptionTier tier;
  final String billingCycle;
  final String status;
  final String? currentPeriodStart;
  final String? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final String startedAt;

  ProviderSubscription({
    required this.id,
    required this.tier,
    required this.billingCycle,
    required this.status,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    required this.startedAt,
  });

  factory ProviderSubscription.fromJson(Map<String, dynamic> json) {
    return ProviderSubscription(
      id: json['id'] ?? 0,
      tier: SubscriptionTier.fromJson(json['tier'] ?? {}),
      billingCycle: json['billing_cycle'] ?? 'monthly',
      status: json['status'] ?? 'active',
      currentPeriodStart: json['current_period_start'],
      currentPeriodEnd: json['current_period_end'],
      cancelAtPeriodEnd: json['cancel_at_period_end'] ?? false,
      startedAt: json['started_at'] ?? '',
    );
  }

  bool get isActive => status == 'active';
}
