"""Listing overhaul: relax required address fields, add ~80 new Property fields,
extend PropertyDocument document_type choices.

Corresponds to plan `compressed-kindling-crayon.md`, §1. All new fields are
nullable/blank so existing rows are unaffected. This supports the multi-phase
listing flow where Phase 1 captures only title/type/price/postcode/bedrooms/photos
and Phase 2 adds the richer details.
"""

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0015_add_trial_fields'),
    ]

    operations = [
        # ── Relax existing required fields for Phase 1 minimum ─────
        migrations.AlterField(
            model_name='property',
            name='address_line_1',
            field=models.CharField(blank=True, default='', max_length=200),
        ),
        migrations.AlterField(
            model_name='property',
            name='city',
            field=models.CharField(blank=True, default='', max_length=100),
        ),

        # ── Brief description + what3words ─────────────────────────
        migrations.AddField(
            model_name='property',
            name='brief_description',
            field=models.CharField(blank=True, max_length=300),
        ),
        migrations.AddField(
            model_name='property',
            name='what3words',
            field=models.CharField(
                blank=True,
                max_length=100,
                help_text='Optional what3words address, e.g. index.home.raft',
            ),
        ),

        # ── Floor area (sqm complements existing square_feet) ─────
        migrations.AddField(
            model_name='property',
            name='floor_area_sqm',
            field=models.DecimalField(
                null=True, blank=True, max_digits=6, decimal_places=2,
            ),
        ),

        # ── Tenure & costs ─────────────────────────────────────────
        migrations.AddField(
            model_name='property',
            name='tenure',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('freehold', 'Freehold'),
                    ('leasehold', 'Leasehold'),
                    ('share_of_freehold', 'Share of Freehold'),
                    ('commonhold', 'Commonhold'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='lease_years_remaining',
            field=models.PositiveIntegerField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='ground_rent_amount',
            field=models.DecimalField(null=True, blank=True, max_digits=8, decimal_places=2),
        ),
        migrations.AddField(
            model_name='property',
            name='ground_rent_review_terms',
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='service_charge_amount',
            field=models.DecimalField(null=True, blank=True, max_digits=8, decimal_places=2),
        ),
        migrations.AddField(
            model_name='property',
            name='service_charge_frequency',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('monthly', 'Monthly'),
                    ('quarterly', 'Quarterly'),
                    ('annual', 'Annual'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='managing_agent_details',
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='council_tax_band',
            field=models.CharField(
                blank=True, max_length=1,
                choices=[
                    ('A', 'A'), ('B', 'B'), ('C', 'C'), ('D', 'D'),
                    ('E', 'E'), ('F', 'F'), ('G', 'G'), ('H', 'H'),
                ],
            ),
        ),

        # ── Construction & build ───────────────────────────────────
        migrations.AddField(
            model_name='property',
            name='year_built',
            field=models.PositiveIntegerField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='construction_type',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('standard', 'Standard brick'),
                    ('timber', 'Timber frame'),
                    ('concrete', 'Concrete'),
                    ('steel', 'Steel frame'),
                    ('cob', 'Cob'),
                    ('other', 'Other'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='non_standard_construction',
            field=models.BooleanField(default=False),
        ),

        # ── Utilities & services ───────────────────────────────────
        migrations.AddField(
            model_name='property',
            name='electricity_supply',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('mains', 'Mains'),
                    ('off_grid', 'Off-grid'),
                    ('solar', 'Solar'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='water_supply',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('mains', 'Mains'),
                    ('private', 'Private'),
                    ('shared', 'Shared'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='sewerage',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('mains', 'Mains'),
                    ('septic', 'Septic tank'),
                    ('cesspit', 'Cesspit'),
                    ('treatment_plant', 'Treatment plant'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='heating_type',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('gas_central', 'Gas central'),
                    ('electric', 'Electric'),
                    ('oil', 'Oil'),
                    ('lpg', 'LPG'),
                    ('heat_pump', 'Heat pump'),
                    ('none', 'None'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='broadband_speed',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('standard', 'Standard'),
                    ('superfast', 'Superfast'),
                    ('ultrafast', 'Ultrafast'),
                    ('full_fibre', 'Full fibre'),
                    ('unknown', 'Unknown'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='broadband_provider',
            field=models.CharField(blank=True, max_length=100),
        ),
        migrations.AddField(
            model_name='property',
            name='broadband_monthly_cost',
            field=models.DecimalField(null=True, blank=True, max_digits=6, decimal_places=2),
        ),
        migrations.AddField(
            model_name='property',
            name='mobile_signal',
            field=models.JSONField(
                null=True, blank=True,
                help_text='Map of network -> indoor/outdoor rating',
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='parking_type',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('garage', 'Garage'),
                    ('driveway', 'Driveway'),
                    ('allocated', 'Allocated'),
                    ('permit', 'Permit'),
                    ('on_street', 'On-street'),
                    ('none', 'None'),
                ],
            ),
        ),

        # ── Rights, restrictions & risks ───────────────────────────
        migrations.AddField(
            model_name='property',
            name='restrictive_covenants',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='property',
            name='restrictive_covenants_details',
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='rights_of_way',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='property',
            name='rights_of_way_details',
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='listed_building',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('none', 'None'),
                    ('grade_1', 'Grade I'),
                    ('grade_2_star', 'Grade II*'),
                    ('grade_2', 'Grade II'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='conservation_area',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='property',
            name='flood_risk',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('none', 'None'),
                    ('river', 'River'),
                    ('surface_water', 'Surface water'),
                    ('groundwater', 'Groundwater'),
                    ('multiple', 'Multiple'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='coastal_erosion_risk',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='property',
            name='mining_area',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('none', 'None'),
                    ('coal', 'Coal'),
                    ('tin', 'Tin'),
                    ('other', 'Other'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='japanese_knotweed',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('none', 'Never'),
                    ('present', 'Present'),
                    ('treated', 'Treated'),
                    ('unsure', 'Unsure'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='accessibility_features',
            field=models.TextField(blank=True),
        ),

        # ── Building safety ────────────────────────────────────────
        migrations.AddField(
            model_name='property',
            name='cladding_type',
            field=models.CharField(blank=True, max_length=100),
        ),
        migrations.AddField(
            model_name='property',
            name='ews1_available',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='property',
            name='building_safety_notes',
            field=models.TextField(blank=True),
        ),

        # ── Works history ──────────────────────────────────────────
        migrations.AddField(
            model_name='property',
            name='extensions_year',
            field=models.PositiveIntegerField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='loft_conversion_year',
            field=models.PositiveIntegerField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='rewiring_year',
            field=models.PositiveIntegerField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='reroof_year',
            field=models.PositiveIntegerField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='new_boiler_year',
            field=models.PositiveIntegerField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='new_windows_year',
            field=models.PositiveIntegerField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='damp_proofing_year',
            field=models.PositiveIntegerField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='works_notes',
            field=models.TextField(
                blank=True,
                help_text='Free text for permissions, guarantees, details',
            ),
        ),

        # ── Warranties ─────────────────────────────────────────────
        migrations.AddField(
            model_name='property',
            name='nhbc_years_remaining',
            field=models.PositiveIntegerField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='solar_panels',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('none', 'None'),
                    ('owned', 'Owned'),
                    ('leased', 'Leased'),
                ],
            ),
        ),

        # ── Running costs ──────────────────────────────────────────
        migrations.AddField(
            model_name='property',
            name='annual_gas_bill',
            field=models.DecimalField(null=True, blank=True, max_digits=8, decimal_places=2),
        ),
        migrations.AddField(
            model_name='property',
            name='annual_electricity_bill',
            field=models.DecimalField(null=True, blank=True, max_digits=8, decimal_places=2),
        ),
        migrations.AddField(
            model_name='property',
            name='annual_water_bill',
            field=models.DecimalField(null=True, blank=True, max_digits=8, decimal_places=2),
        ),

        # ── Environmental & location ───────────────────────────────
        migrations.AddField(
            model_name='property',
            name='radon_risk',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('unknown', 'Unknown'),
                    ('none', 'None'),
                    ('low', 'Low'),
                    ('medium', 'Medium'),
                    ('high', 'High'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='noise_sources',
            field=models.CharField(blank=True, max_length=255),
        ),
        migrations.AddField(
            model_name='property',
            name='nearest_station_name',
            field=models.CharField(blank=True, max_length=200),
        ),
        migrations.AddField(
            model_name='property',
            name='nearest_station_distance_km',
            field=models.DecimalField(null=True, blank=True, max_digits=5, decimal_places=2),
        ),
        migrations.AddField(
            model_name='property',
            name='nearby_schools',
            field=models.TextField(blank=True),
        ),

        # ── Outside space ──────────────────────────────────────────
        migrations.AddField(
            model_name='property',
            name='garden_size_sqm',
            field=models.DecimalField(null=True, blank=True, max_digits=6, decimal_places=2),
        ),
        migrations.AddField(
            model_name='property',
            name='garden_orientation',
            field=models.CharField(
                blank=True, max_length=10,
                choices=[
                    ('none', 'No garden'),
                    ('n', 'North'),
                    ('ne', 'North-East'),
                    ('e', 'East'),
                    ('se', 'South-East'),
                    ('s', 'South'),
                    ('sw', 'South-West'),
                    ('w', 'West'),
                    ('nw', 'North-West'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='outbuildings',
            field=models.TextField(blank=True),
        ),

        # ── Chain & availability ───────────────────────────────────
        migrations.AddField(
            model_name='property',
            name='chain_status',
            field=models.CharField(
                blank=True, max_length=20,
                choices=[
                    ('no_chain', 'No chain'),
                    ('in_chain', 'In chain'),
                    ('part_exchange', 'Part exchange'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='property',
            name='earliest_completion_date',
            field=models.DateField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='reason_for_sale',
            field=models.TextField(blank=True),
        ),

        # ── Fixtures & fittings ────────────────────────────────────
        migrations.AddField(
            model_name='property',
            name='fixtures_included',
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='fixtures_excluded',
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name='property',
            name='fixtures_negotiable',
            field=models.TextField(blank=True),
        ),

        # ── Extras worth highlighting ──────────────────────────────
        migrations.AddField(
            model_name='property',
            name='smart_home',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='property',
            name='ev_charging',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='property',
            name='solar_battery_storage',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='property',
            name='rainwater_harvesting',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='property',
            name='home_office',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='property',
            name='pet_friendly_features',
            field=models.BooleanField(default=False),
        ),

        # ── Extend PropertyDocument document_type choices ──────────
        migrations.AlterField(
            model_name='propertydocument',
            name='document_type',
            field=models.CharField(
                max_length=20,
                choices=[
                    ('epc', 'EPC Certificate'),
                    ('title_deeds', 'Title Deeds'),
                    ('searches', 'Searches'),
                    ('ta6', 'TA6 Property Information'),
                    ('ta10', 'TA10 Fittings & Contents'),
                    ('floorplan', 'Floorplan'),
                    ('survey', 'Survey Report'),
                    ('gas_safety', 'Gas Safety Certificate'),
                    ('eicr', 'EICR / Electrical Certificate'),
                    ('fensa', 'FENSA / CERTASS Certificate'),
                    ('building_regs', 'Building Regulations Sign-off'),
                    ('planning', 'Planning Permission'),
                    ('ews1', 'EWS1 Form'),
                    ('other', 'Other'),
                ],
            ),
        ),
    ]
