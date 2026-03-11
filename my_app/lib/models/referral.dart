class Referral {
  final int id;
  final String referredUserEmail;
  final String referredUserName;
  final bool rewardGranted;
  final String createdAt;

  Referral({
    required this.id,
    required this.referredUserEmail,
    required this.referredUserName,
    required this.rewardGranted,
    required this.createdAt,
  });

  factory Referral.fromJson(Map<String, dynamic> json) {
    return Referral(
      id: json['id'],
      referredUserEmail: json['referred_user_email'] ?? '',
      referredUserName: json['referred_user_name'] ?? '',
      rewardGranted: json['reward_granted'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ReferralInfo {
  final String referralCode;
  final int totalReferrals;
  final int rewardsEarned;
  final List<Referral> referrals;

  ReferralInfo({
    required this.referralCode,
    required this.totalReferrals,
    required this.rewardsEarned,
    required this.referrals,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    return ReferralInfo(
      referralCode: json['referral_code'] ?? '',
      totalReferrals: json['total_referrals'] ?? 0,
      rewardsEarned: json['rewards_earned'] ?? 0,
      referrals: (json['referrals'] as List? ?? [])
          .map((r) => Referral.fromJson(r))
          .toList(),
    );
  }
}
