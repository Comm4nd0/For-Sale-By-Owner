"""Change stripe_subscription_id default from '' to None to avoid unique constraint
violations when creating free-tier subscriptions."""

from django.db import migrations, models


def fix_empty_stripe_ids(apps, schema_editor):
    """Convert empty-string stripe_subscription_id values to NULL."""
    ServiceProviderSubscription = apps.get_model('api', 'ServiceProviderSubscription')
    ServiceProviderSubscription.objects.filter(stripe_subscription_id='').update(
        stripe_subscription_id=None
    )


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0013_forumcategory_user_two_fa_enabled_user_two_fa_secret_and_more'),
    ]

    operations = [
        # First fix existing data
        migrations.RunPython(fix_empty_stripe_ids, migrations.RunPython.noop),
        # Then alter the field default
        migrations.AlterField(
            model_name='serviceprovidersubscription',
            name='stripe_subscription_id',
            field=models.CharField(
                blank=True, default=None, help_text='Stripe Subscription ID',
                max_length=100, null=True, unique=True,
            ),
        ),
    ]
