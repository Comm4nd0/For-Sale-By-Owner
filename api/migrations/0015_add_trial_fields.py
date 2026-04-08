"""Add trial_period_days to SubscriptionTier and trial_end to ServiceProviderSubscription."""

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0014_fix_stripe_subscription_id_default'),
    ]

    operations = [
        migrations.AddField(
            model_name='subscriptiontier',
            name='trial_period_days',
            field=models.PositiveIntegerField(
                default=0,
                help_text='Number of days free trial for new subscribers. 0 = no trial.',
            ),
        ),
        migrations.AddField(
            model_name='serviceprovidersubscription',
            name='trial_end',
            field=models.DateTimeField(
                blank=True,
                null=True,
                help_text='When the trial period ends (from Stripe)',
            ),
        ),
    ]
