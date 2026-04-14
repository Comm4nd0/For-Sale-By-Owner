from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0016_listing_overhaul'),
    ]

    operations = [
        migrations.DeleteModel(
            name='ConveyancingStep',
        ),
        migrations.DeleteModel(
            name='ConveyancingCase',
        ),
    ]
