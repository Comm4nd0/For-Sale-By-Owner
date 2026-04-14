"""
Seed data constants and sale initialisation for the Sale Tracker.

Contains the 10 conveyancing stages, default tasks per stage,
pre-instruction document checklist, and prompt templates.
"""

from django.utils import timezone


# ── Stages (0-9) ───────────────────────────────────────────────

STAGES = [
    {'stage_number': 0, 'name': 'Pre-Instruction'},
    {'stage_number': 1, 'name': 'Pre-Offer'},
    {'stage_number': 2, 'name': 'Instruction & Onboarding'},
    {'stage_number': 3, 'name': 'Draft Contract Pack'},
    {'stage_number': 4, 'name': "Buyer's Due Diligence"},
    {'stage_number': 5, 'name': 'Pre-Exchange'},
    {'stage_number': 6, 'name': 'Exchange of Contracts'},
    {'stage_number': 7, 'name': 'Between Exchange and Completion'},
    {'stage_number': 8, 'name': 'Completion Day'},
    {'stage_number': 9, 'name': 'Post-Completion'},
]


# ── Tasks by stage ─────────────────────────────────────────────
# Each: (title, default_owner, description)

TASKS_BY_STAGE = {
    1: [
        ('List property on FSBO platform', 'seller',
         'Create listing, photos, description.'),
        ('Commission EPC', 'seller',
         'Legally required before marketing if not already valid (10-year validity).'),
        ('Conduct viewings', 'seller',
         'Schedule and host viewings.'),
        ('Receive offer', 'seller',
         'Record offer details.'),
        ('Negotiate / accept / decline', 'seller',
         'Decide and respond.'),
        ('Issue Memorandum of Sale', 'estate_agent',
         'If using an agent; otherwise seller issues directly to both conveyancers.'),
    ],
    2: [
        ('Choose seller conveyancer', 'seller',
         'Research and select.'),
        ('Sign client care letter', 'seller',
         'Conveyancer sends; seller signs and returns.'),
        ('Provide ID and proof of address', 'seller',
         'AML check.'),
        ('Provide source-of-funds evidence (if applicable)', 'seller',
         'If buying onward.'),
        ('Conveyancer obtains official copies from Land Registry', 'seller_conveyancer',
         'Standard.'),
        ('Complete TA6 Property Information Form', 'seller',
         'Conveyancer provides; seller fills in.'),
        ('Complete TA10 Fittings & Contents Form', 'seller',
         'Conveyancer provides; seller fills in.'),
        ('Complete TA7 Leasehold Information Form', 'seller',
         'Leasehold only.'),
        ('Conveyancer requests LPE1 leasehold pack', 'seller_conveyancer',
         'Leasehold only; 4\u20136 week wait typical.'),
    ],
    3: [
        ('Draft contract prepared', 'seller_conveyancer',
         'Conveyancer drafts.'),
        ("Contract pack sent to buyer's conveyancer", 'seller_conveyancer',
         'Includes contract, official copies, TA6/TA10, supporting certs.'),
    ],
    4: [
        ("Buyer's conveyancer raises enquiries", 'buyer_conveyancer',
         'Initial round.'),
        ("Buyer's conveyancer orders searches", 'buyer_conveyancer',
         'Local authority, environmental, water & drainage, chancel, regional.'),
        ("Buyer's mortgage application progresses", 'buyer',
         "Buyer's responsibility."),
        ('Lender instructs valuation', 'lender',
         "Lender's surveyor."),
        ('Buyer commissions own survey', 'buyer',
         'Level 2 or Level 3.'),
        ('Survey/valuation outcome reviewed', 'buyer',
         'May trigger renegotiation.'),
        ('Seller answers enquiries', 'seller',
         'Conveyancer relays; seller responds; conveyancer returns answers.'),
        ('Mortgage offer issued', 'lender',
         'To buyer.'),
    ],
    5: [
        ('All enquiries resolved', 'seller_conveyancer',
         'Final clearance.'),
        ('Searches returned and reviewed', 'buyer_conveyancer',
         'Indemnity policies arranged if needed.'),
        ('Report on Title sent to buyer', 'buyer_conveyancer',
         'Buyer reads and approves.'),
        ('Contracts signed (seller side)', 'seller',
         'Sign and return to conveyancer.'),
        ('Contracts signed (buyer side)', 'buyer',
         'Buyer signs.'),
        ('TR1 transfer deed signed', 'seller',
         'Sign and return.'),
        ('Buyer pays deposit to their conveyancer', 'buyer',
         'Usually 10%.'),
        ('Completion date agreed across chain', 'seller_conveyancer',
         'All parties.'),
    ],
    6: [
        ('Exchange contracts', 'seller_conveyancer',
         'Legally binding from this point.'),
    ],
    7: [
        ('Completion statement prepared', 'seller_conveyancer',
         'Mortgage redemption, fees.'),
        ('Pre-completion searches (OS1 + bankruptcy)', 'buyer_conveyancer',
         'Standard.'),
        ("Buyer's lender releases funds", 'lender',
         "To buyer's conveyancer."),
        ('Pack and arrange removals', 'seller',
         'Logistics.'),
        ('Read meters, cancel/transfer utilities and council tax', 'seller',
         'On or near completion day.'),
    ],
    8: [
        ("Buyer's conveyancer sends funds", 'buyer_conveyancer',
         "To seller's conveyancer."),
        ("Seller's conveyancer confirms receipt", 'seller_conveyancer',
         'Triggers key release.'),
        ('Keys released to buyer', 'estate_agent',
         'Or directly by seller if no agent.'),
        ('Mortgage redeemed', 'seller_conveyancer',
         'From sale proceeds.'),
        ('Agent fee paid', 'seller_conveyancer',
         'If applicable.'),
        ('Net proceeds sent to seller', 'seller_conveyancer',
         "To seller's bank."),
    ],
    9: [
        ('SDLT paid by buyer', 'buyer_conveyancer',
         "Buyer's responsibility."),
        ('Transfer registered at Land Registry', 'buyer_conveyancer',
         'Standard.'),
        ("Closing letter from seller's conveyancer", 'seller_conveyancer',
         'Final paperwork.'),
        ('Leasehold apportionments settled', 'seller_conveyancer',
         'Leasehold only.'),
    ],
}


# ── Document checklist ─────────────────────────────────────────
# Each: (title, category, source, required_tier, helper_text)

DOCUMENT_CHECKLIST = [
    # Always required
    ('Photo ID', 'identity', 'seller_provides', 'always',
     'Passport or UK driving licence. Required for AML checks.'),
    ('Proof of address', 'identity', 'seller_provides', 'always',
     'Utility bill or bank statement dated within the last 3 months. Council tax bill also acceptable.'),
    ('EPC (Energy Performance Certificate)', 'property', 'seller_provides', 'always',
     'Legally required before marketing. Check validity at gov.uk/find-energy-certificate. 10-year validity. Commission a new one if expired.'),
    ('Existing mortgage details', 'financial', 'seller_provides', 'always',
     'Lender name, account number. Conveyancer needs this to request redemption figure.'),
    ('TA6 Property Information Form (draft)', 'form', 'seller_provides', 'always',
     'Standard Law Society form. Download from your conveyancer or Law Society site and complete in advance to save time.'),
    ('TA10 Fittings & Contents Form (draft)', 'form', 'seller_provides', 'always',
     'What stays, what goes. Complete in advance.'),

    # If applicable
    ('FENSA / CERTASS certificates', 'certificate', 'seller_provides', 'if_applicable',
     'For replacement windows or external doors fitted since April 2002. Search fensa.org.uk by postcode.'),
    ('Building Regulations completion certificates', 'certificate', 'seller_provides', 'if_applicable',
     'For any extensions, loft conversions, removed walls, structural work. Issued by your local authority building control.'),
    ('Planning permission decisions', 'certificate', 'seller_provides', 'if_applicable',
     "For extensions or material changes. Check your council's planning portal if you can't find the original."),
    ('Gas Safe certificate', 'certificate', 'seller_provides', 'if_applicable',
     'Most recent boiler service. Gas Safe engineer provides.'),
    ('EICR (Electrical Installation Condition Report)', 'certificate', 'seller_provides', 'if_applicable',
     'The electrical safety report. Valid 5 years from issue date. Check expiry.'),
    ('Part P certificate', 'certificate', 'seller_provides', 'if_applicable',
     'For notifiable electrical work since 2005. Issued by a Part P registered electrician.'),
    ('Boiler installation certificate and warranty', 'certificate', 'seller_provides', 'if_applicable',
     'Original installation paperwork.'),
    ('Damp proof course guarantee', 'guarantee', 'seller_provides', 'if_applicable',
     'If treatment was carried out.'),
    ('Roof guarantee', 'guarantee', 'seller_provides', 'if_applicable',
     'If re-roofed within guarantee period.'),
    ('Solar PV documentation', 'certificate', 'seller_provides', 'if_applicable',
     'MCS certificate, FIT/SEG paperwork, DNO approval. All three matter.'),
    ('NHBC or equivalent new-build warranty', 'guarantee', 'seller_provides', 'if_applicable',
     'If property is under 10 years old.'),
    ('Party wall agreements', 'legal', 'seller_provides', 'if_applicable',
     'If any work was done affecting a shared wall.'),
    ('Septic tank or cesspit compliance', 'certificate', 'seller_provides', 'if_applicable',
     'If off-mains drainage. Must comply with 2020 General Binding Rules.'),
    ('Asbestos survey', 'certificate', 'seller_provides', 'if_applicable',
     'If ever commissioned.'),
    ('Japanese knotweed management plan', 'certificate', 'seller_provides', 'if_applicable',
     'If present on property.'),
    ('Conservation area or listed building consents', 'legal', 'seller_provides', 'if_applicable',
     'For any work requiring consent.'),
    ('Indemnity policies from previous purchase', 'legal', 'seller_provides', 'if_applicable',
     'If you bought with any in place.'),

    # Leasehold only
    ('Lease document', 'legal', 'seller_provides', 'leasehold_only',
     'Your copy of the lease. If lost, conveyancer can obtain from Land Registry.'),
    ('Share certificate', 'legal', 'seller_provides', 'leasehold_only',
     'If share-of-freehold.'),
    ('Recent service charge and ground rent statements', 'financial', 'seller_provides', 'leasehold_only',
     'Last two years if available.'),
    ('Building insurance schedule', 'legal', 'seller_provides', 'leasehold_only',
     'Usually arranged by managing agent.'),
    ('Managing agent contact details', 'legal', 'seller_provides', 'leasehold_only',
     'Conveyancer needs to request LPE1 pack.'),
    ('LPE1 leasehold information pack', 'form', 'conveyancer_obtains', 'leasehold_only',
     'Conveyancer orders from managing agent. \u00a3300\u2013\u00a3800 cost, 4\u20136 weeks typical wait. You authorise and pay.'),

    # Situational
    ('Probate / grant of representation', 'legal', 'seller_provides', 'situational',
     'If selling inherited property.'),
    ('Decree absolute and consent order', 'legal', 'seller_provides', 'situational',
     'If selling post-divorce.'),
    ('Power of attorney', 'legal', 'seller_provides', 'situational',
     "If selling on someone else's behalf."),
    ('Statutory declaration', 'legal', 'seller_provides', 'situational',
     'For unregistered alterations or to address title defects.'),
]


# ── Prompt templates ───────────────────────────────────────────
# Keyed by (counterparty_type, level)
# Variables: {property_address}, {target_completion}, {counterparty_name},
#            {seller_name}, {items_list}, {oldest_days}

PROMPT_TEMPLATES = {
    # ── Seller Conveyancer ──
    ('seller_conveyancer', '1'): {
        'subject': 'Update request \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'Could you give me a brief update on the following items, which I '
            'believe are currently with your office:\n\n'
            '{items_list}\n\n'
            'The earliest of these has been outstanding for {oldest_days} days. '
            'Our target completion is {target_completion}.\n\n'
            'A line on expected timing or any blockers would be helpful.\n\n'
            '{seller_name}'
        ),
    },
    ('seller_conveyancer', '2'): {
        'subject': 'Follow-up \u2014 {property_address} \u2014 items awaiting your action',
        'body': (
            '{counterparty_name},\n\n'
            'Following up on my earlier message. The items below remain outstanding:\n\n'
            '{items_list}\n\n'
            'The earliest is now {oldest_days} days old. Our target completion '
            'date is {target_completion} and I want to keep that on track.\n\n'
            'Please let me know:\n'
            '1. Where each item currently stands.\n'
            '2. Expected dates for next steps.\n'
            '3. Anything you need from me to progress them.\n\n'
            '{seller_name}'
        ),
    },
    ('seller_conveyancer', 'escalation'): {
        'subject': 'Escalation \u2014 outstanding items on {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'I have previously requested updates on the items below without '
            'substantive response:\n\n'
            '{items_list}\n\n'
            'The earliest has been outstanding for {oldest_days} days. Our '
            'target completion is {target_completion} and the current pace '
            'puts that at risk.\n\n'
            'I would like:\n'
            '1. A response within 2 working days with a clear status on each item.\n'
            '2. A named individual responsible for progressing the file.\n'
            '3. Confirmation of your firm\'s complaints procedure should this '
            'pattern continue.\n\n'
            'I would prefer to resolve this directly rather than through a '
            'formal complaint to the firm or to the SRA, but I will take that '
            'step if needed.\n\n'
            '{seller_name}'
        ),
    },

    # ── Buyer Conveyancer ──
    ('buyer_conveyancer', '1'): {
        'subject': 'Status check \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'Could you confirm the status of the following on the purchase of '
            '{property_address}:\n\n'
            '{items_list}\n\n'
            'Earliest item has been outstanding {oldest_days} days. Target '
            'completion {target_completion}.\n\n'
            '{seller_name} (seller)'
        ),
    },
    ('buyer_conveyancer', '2'): {
        'subject': 'Follow-up \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'Following up on outstanding items on {property_address}:\n\n'
            '{items_list}\n\n'
            'Earliest is {oldest_days} days old. To meet the target completion '
            'of {target_completion}, these need to progress.\n\n'
            'Please confirm timing on each.\n\n'
            '{seller_name} (seller)'
        ),
    },
    ('buyer_conveyancer', 'escalation'): {
        'subject': 'Escalation \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'Despite previous follow-ups, the items below remain unresolved:\n\n'
            '{items_list}\n\n'
            'The earliest is now {oldest_days} days outstanding. The target '
            'completion of {target_completion} is at risk.\n\n'
            'Please respond within 2 working days with substantive updates. I '
            'am also raising this with my own conveyancer and the estate agent '
            'to coordinate next steps. Should there be no progress, I will '
            'suggest the buyer escalates within your firm.\n\n'
            '{seller_name} (seller)'
        ),
    },

    # ── Estate Agent ──
    ('estate_agent', '1'): {
        'subject': 'Chain update \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'Could you give me an update on the chain position and any movement '
            'on the items below:\n\n'
            '{items_list}\n\n'
            'Target completion is {target_completion}.\n\n'
            '{seller_name}'
        ),
    },
    ('estate_agent', '2'): {
        'subject': 'Follow-up on chain \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            "I haven't had an update for {oldest_days} days. Please confirm:\n\n"
            '1. Current status of the chain.\n'
            "2. Where the buyer's progress stands on {items_list}.\n"
            "3. Any blockers you're aware of.\n\n"
            '{seller_name}'
        ),
    },
    ('estate_agent', 'escalation'): {
        'subject': 'Escalation \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'I have asked for updates on the chain and on the items below '
            'without satisfactory response:\n\n'
            '{items_list}\n\n'
            'It has now been {oldest_days} days. Target completion is '
            '{target_completion}.\n\n'
            'I expect a substantive update within 2 working days. If your firm\'s '
            'service level remains inadequate, I will raise this with your branch '
            'manager and consider the terms of our agency agreement.\n\n'
            '{seller_name}'
        ),
    },

    # ── Freeholder / Managing Agent ──
    ('freeholder_or_managing_agent', '1'): {
        'subject': 'LPE1 / leasehold pack request \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'My conveyancer has requested the LPE1 leasehold information pack '
            'for {property_address}. Could you confirm:\n\n'
            '1. Receipt of the request.\n'
            '2. Expected timeframe for the pack.\n'
            '3. Outstanding payment if any.\n\n'
            '{seller_name}'
        ),
    },
    ('freeholder_or_managing_agent', '2'): {
        'subject': 'Follow-up \u2014 LPE1 for {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'The LPE1 request has been outstanding {oldest_days} days. Sale '
            'progress depends on receipt of the pack and target completion is '
            '{target_completion}.\n\n'
            'Please confirm where it currently stands and an expected delivery '
            'date.\n\n'
            '{seller_name}'
        ),
    },
    ('freeholder_or_managing_agent', 'escalation'): {
        'subject': 'Escalation \u2014 LPE1 for {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'The LPE1 pack remains outstanding {oldest_days} days after request, '
            'despite previous follow-ups. This is delaying my sale and the target '
            'completion of {target_completion}.\n\n'
            'Please provide the pack within 5 working days. If this is not '
            'possible, I will raise the matter with the freeholder directly and, '
            'if applicable, consider the First-tier Tribunal (Property Chamber) '
            'route for unreasonable delay or charges.\n\n'
            '{seller_name}'
        ),
    },

    # ── Lender ──
    ('lender', '1'): {
        'subject': 'Mortgage redemption \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'Could you confirm receipt of the redemption request for the mortgage '
            'on {property_address} and expected timing for the redemption '
            'statement.\n\n'
            '{seller_name}'
        ),
    },
    ('lender', '2'): {
        'subject': 'Follow-up \u2014 redemption statement \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'Following up on the redemption request, outstanding {oldest_days} '
            'days. Target completion {target_completion}.\n\n'
            'Please confirm status and timing.\n\n'
            '{seller_name}'
        ),
    },
    ('lender', 'escalation'): {
        'subject': 'Escalation \u2014 redemption statement \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'Despite previous requests, I have not received the redemption '
            'statement for {property_address}, now {oldest_days} days '
            'outstanding. Target completion is {target_completion}.\n\n'
            'Please provide the statement within 2 working days. If this is not '
            'resolved, I will raise a formal complaint and refer the matter to '
            'the Financial Ombudsman Service.\n\n'
            '{seller_name}'
        ),
    },

    # ── Surveyor ──
    ('surveyor', '1'): {
        'subject': 'Survey access / report \u2014 {property_address}',
        'body': (
            '{counterparty_name},\n\n'
            'Could you confirm the status of the survey for {property_address} '
            '\u2014 scheduled date, or report delivery date if completed.\n\n'
            '{seller_name}'
        ),
    },
    ('surveyor', '2'): {
        'subject': 'Follow-up \u2014 {property_address} survey',
        'body': (
            '{counterparty_name},\n\n'
            'Following up on the survey, outstanding {oldest_days} days. '
            'Target completion is {target_completion} so timing matters.\n\n'
            'Please confirm where things stand.\n\n'
            '{seller_name}'
        ),
    },
    ('surveyor', 'escalation'): {
        'subject': 'Escalation \u2014 {property_address} survey',
        'body': (
            '{counterparty_name},\n\n'
            'The survey remains outstanding {oldest_days} days after request. '
            'Target completion is {target_completion} and the delay is '
            'material.\n\n'
            'Please respond within 2 working days with a clear timeline. If not, '
            'I will raise the matter with your professional body (RICS) and '
            'consider alternative arrangements.\n\n'
            '{seller_name}'
        ),
    },
}


# ── Sale seeding function ──────────────────────────────────────

def seed_sale(sale):
    """
    Populate a new Sale with stages, tasks, and document checklist items.
    Called automatically when a Sale is created via the API.
    """
    from .models import Stage, Task, Document

    # Create stages
    stages = {}
    for stage_data in STAGES:
        stage = Stage.objects.create(
            sale=sale,
            stage_number=stage_data['stage_number'],
            name=stage_data['name'],
        )
        stages[stage_data['stage_number']] = stage

    # Set Stage 0 to in_progress
    stage_0 = stages[0]
    stage_0.status = 'in_progress'
    stage_0.started_at = timezone.now()
    stage_0.save()

    # Create tasks for each stage
    for stage_number, task_list in TASKS_BY_STAGE.items():
        stage = stages[stage_number]
        for order, (title, owner, description) in enumerate(task_list):
            # Skip leasehold-only tasks for freehold sales
            if not sale.is_leasehold and 'leasehold' in title.lower():
                continue
            if not sale.is_leasehold and 'LPE1' in title:
                continue
            Task.objects.create(
                stage=stage,
                title=title,
                description=description,
                current_owner=owner,
                order=order,
                is_seed=True,
            )

    # Create document checklist items
    for title, category, source, required_tier, helper_text in DOCUMENT_CHECKLIST:
        # Skip leasehold-only documents for freehold sales
        if required_tier == 'leasehold_only' and not sale.is_leasehold:
            continue
        Document.objects.create(
            sale=sale,
            title=title,
            category=category,
            source=source,
            required_tier=required_tier,
            status='missing',
            helper_text=helper_text,
            is_seed=True,
        )
