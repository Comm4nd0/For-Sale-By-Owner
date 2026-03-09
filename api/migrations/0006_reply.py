from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('api', '0005_propertyfeature_pricehistory_property_features_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='Reply',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('message', models.TextField()),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('author', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='replies', to=settings.AUTH_USER_MODEL)),
                ('enquiry', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='replies', to='api.enquiry')),
                ('viewing_request', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='replies', to='api.viewingrequest')),
            ],
            options={
                'verbose_name_plural': 'Replies',
                'ordering': ['created_at'],
            },
        ),
        migrations.AddConstraint(
            model_name='reply',
            constraint=models.CheckConstraint(
                check=models.Q(
                    ('enquiry__isnull', False),
                    ('viewing_request__isnull', True),
                ) | models.Q(
                    ('enquiry__isnull', True),
                    ('viewing_request__isnull', False),
                ),
                name='reply_exactly_one_parent',
            ),
        ),
    ]
