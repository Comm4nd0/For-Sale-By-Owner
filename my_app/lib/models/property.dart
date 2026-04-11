import 'property_image.dart';
import 'property_feature.dart';
import 'property_floorplan.dart';
import 'price_history.dart';

/// Property model — extended as part of the Phase 1/Phase 2 listing overhaul.
///
/// Phase 1 fields (title, property_type, price, postcode, bedrooms) remain
/// required to publish. Everything else is optional/nullable and is filled
/// in through the Phase 2 "Complete your listing" screen.
class Property {
  // ── Phase 1 core ─────────────────────────────────────────────
  final int id;
  final int ownerId;
  final String title;
  final String slug;
  final String description;
  final String briefDescription;
  final String propertyType;
  final String propertyTypeDisplay;
  final String status;
  final String statusDisplay;
  final double price;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String county;
  final String postcode;
  final int bedrooms;
  final int bathrooms;
  final int receptionRooms;
  final int? squareFeet;
  final double? floorAreaSqm;
  final String epcRating;
  final String epcRatingDisplay;
  final List<PropertyImage> images;
  final List<PropertyFeature> features;
  final List<PropertyFloorplan> floorplans;
  final List<PriceHistory> priceHistory;
  final String? primaryImageUrl;
  final String ownerName;
  final bool ownerIsVerified;
  final bool isSaved;
  final double? latitude;
  final double? longitude;
  final String whatThreeWords;
  final String? videoUrl;
  final String? videoThumbnail;
  final int imageCount;
  final int? viewCount;
  final int? messageCount;
  final int? offerCount;
  final int? listingQualityScore;
  final String createdAt;
  final String updatedAt;

  // ── Tenure & costs ───────────────────────────────────────────
  final String tenure;
  final int? leaseYearsRemaining;
  final double? groundRentAmount;
  final String groundRentReviewTerms;
  final double? serviceChargeAmount;
  final String serviceChargeFrequency;
  final String managingAgentDetails;
  final String councilTaxBand;

  // ── Construction & build ─────────────────────────────────────
  final int? yearBuilt;
  final String constructionType;
  final bool nonStandardConstruction;

  // ── Utilities & services ─────────────────────────────────────
  final String electricitySupply;
  final String waterSupply;
  final String sewerage;
  final String heatingType;
  final String broadbandSpeed;
  final String broadbandProvider;
  final double? broadbandMonthlyCost;
  final Map<String, dynamic>? mobileSignal;
  final String parkingType;

  // ── Rights, restrictions, risks ──────────────────────────────
  final bool restrictiveCovenants;
  final String restrictiveCovenantsDetails;
  final bool rightsOfWay;
  final String rightsOfWayDetails;
  final String listedBuilding;
  final bool conservationArea;
  final String floodRisk;
  final bool coastalErosionRisk;
  final String miningArea;
  final String japaneseKnotweed;
  final String accessibilityFeatures;

  // ── Building safety ──────────────────────────────────────────
  final String claddingType;
  final bool ews1Available;
  final String buildingSafetyNotes;

  // ── Works history ────────────────────────────────────────────
  final int? extensionsYear;
  final int? loftConversionYear;
  final int? rewiringYear;
  final int? reroofYear;
  final int? newBoilerYear;
  final int? newWindowsYear;
  final int? dampProofingYear;
  final String worksNotes;

  // ── Warranties & running costs ───────────────────────────────
  final int? nhbcYearsRemaining;
  final String solarPanels;
  final double? annualGasBill;
  final double? annualElectricityBill;
  final double? annualWaterBill;

  // ── Environmental & location ─────────────────────────────────
  final String radonRisk;
  final String noiseSources;
  final String nearestStationName;
  final double? nearestStationDistanceKm;
  final String nearbySchools;

  // ── Outside space ────────────────────────────────────────────
  final double? gardenSizeSqm;
  final String gardenOrientation;
  final String outbuildings;

  // ── Chain & availability ─────────────────────────────────────
  final String chainStatus;
  final String? earliestCompletionDate;
  final String reasonForSale;

  // ── Fixtures & fittings ──────────────────────────────────────
  final String fixturesIncluded;
  final String fixturesExcluded;
  final String fixturesNegotiable;

  // ── Extras worth highlighting ────────────────────────────────
  final bool smartHome;
  final bool evCharging;
  final bool solarBatteryStorage;
  final bool rainwaterHarvesting;
  final bool homeOffice;
  final bool petFriendlyFeatures;

  Property({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.slug,
    required this.description,
    this.briefDescription = '',
    required this.propertyType,
    required this.propertyTypeDisplay,
    required this.status,
    required this.statusDisplay,
    required this.price,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.county,
    required this.postcode,
    required this.bedrooms,
    required this.bathrooms,
    required this.receptionRooms,
    this.squareFeet,
    this.floorAreaSqm,
    required this.epcRating,
    required this.epcRatingDisplay,
    required this.images,
    required this.features,
    required this.floorplans,
    required this.priceHistory,
    this.primaryImageUrl,
    required this.ownerName,
    required this.ownerIsVerified,
    required this.isSaved,
    this.latitude,
    this.longitude,
    this.whatThreeWords = '',
    this.videoUrl,
    this.videoThumbnail,
    required this.imageCount,
    this.viewCount,
    this.messageCount,
    this.offerCount,
    this.listingQualityScore,
    required this.createdAt,
    required this.updatedAt,
    this.tenure = '',
    this.leaseYearsRemaining,
    this.groundRentAmount,
    this.groundRentReviewTerms = '',
    this.serviceChargeAmount,
    this.serviceChargeFrequency = '',
    this.managingAgentDetails = '',
    this.councilTaxBand = '',
    this.yearBuilt,
    this.constructionType = '',
    this.nonStandardConstruction = false,
    this.electricitySupply = '',
    this.waterSupply = '',
    this.sewerage = '',
    this.heatingType = '',
    this.broadbandSpeed = '',
    this.broadbandProvider = '',
    this.broadbandMonthlyCost,
    this.mobileSignal,
    this.parkingType = '',
    this.restrictiveCovenants = false,
    this.restrictiveCovenantsDetails = '',
    this.rightsOfWay = false,
    this.rightsOfWayDetails = '',
    this.listedBuilding = '',
    this.conservationArea = false,
    this.floodRisk = '',
    this.coastalErosionRisk = false,
    this.miningArea = '',
    this.japaneseKnotweed = '',
    this.accessibilityFeatures = '',
    this.claddingType = '',
    this.ews1Available = false,
    this.buildingSafetyNotes = '',
    this.extensionsYear,
    this.loftConversionYear,
    this.rewiringYear,
    this.reroofYear,
    this.newBoilerYear,
    this.newWindowsYear,
    this.dampProofingYear,
    this.worksNotes = '',
    this.nhbcYearsRemaining,
    this.solarPanels = '',
    this.annualGasBill,
    this.annualElectricityBill,
    this.annualWaterBill,
    this.radonRisk = '',
    this.noiseSources = '',
    this.nearestStationName = '',
    this.nearestStationDistanceKm,
    this.nearbySchools = '',
    this.gardenSizeSqm,
    this.gardenOrientation = '',
    this.outbuildings = '',
    this.chainStatus = '',
    this.earliestCompletionDate,
    this.reasonForSale = '',
    this.fixturesIncluded = '',
    this.fixturesExcluded = '',
    this.fixturesNegotiable = '',
    this.smartHome = false,
    this.evCharging = false,
    this.solarBatteryStorage = false,
    this.rainwaterHarvesting = false,
    this.homeOffice = false,
    this.petFriendlyFeatures = false,
  });

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _i(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String _s(dynamic v) => v?.toString() ?? '';

  static bool _b(dynamic v) => v == true;

  factory Property.fromJson(Map<String, dynamic> json) {
    int? qualityScore;
    final quality = json['listing_quality'];
    if (quality is Map && quality['score'] is num) {
      qualityScore = (quality['score'] as num).toInt();
    }

    return Property(
      id: json['id'],
      ownerId: json['owner'] ?? 0,
      title: _s(json['title']),
      slug: _s(json['slug']),
      description: _s(json['description']),
      briefDescription: _s(json['brief_description']),
      propertyType: _s(json['property_type']),
      propertyTypeDisplay: _s(json['property_type_display']),
      status: _s(json['status']),
      statusDisplay: _s(json['status_display']),
      price: _d(json['price']) ?? 0,
      addressLine1: _s(json['address_line_1']),
      addressLine2: _s(json['address_line_2']),
      city: _s(json['city']),
      county: _s(json['county']),
      postcode: _s(json['postcode']),
      bedrooms: _i(json['bedrooms']) ?? 0,
      bathrooms: _i(json['bathrooms']) ?? 0,
      receptionRooms: _i(json['reception_rooms']) ?? 0,
      squareFeet: _i(json['square_feet']),
      floorAreaSqm: _d(json['floor_area_sqm']),
      epcRating: _s(json['epc_rating']),
      epcRatingDisplay: _s(json['epc_rating_display']),
      images: (json['images'] as List? ?? [])
          .map((img) => PropertyImage.fromJson(img))
          .toList(),
      features: (json['feature_list'] as List? ?? [])
          .map((f) => PropertyFeature.fromJson(f))
          .toList(),
      floorplans: (json['floorplans'] as List? ?? [])
          .map((f) => PropertyFloorplan.fromJson(f))
          .toList(),
      priceHistory: (json['price_history'] as List? ?? [])
          .map((p) => PriceHistory.fromJson(p))
          .toList(),
      primaryImageUrl: json['primary_image'],
      ownerName: _s(json['owner_name']),
      ownerIsVerified: _b(json['owner_is_verified']),
      isSaved: _b(json['is_saved']),
      latitude: _d(json['latitude']),
      longitude: _d(json['longitude']),
      whatThreeWords: _s(json['what3words']),
      videoUrl: json['video_url'],
      videoThumbnail: json['video_thumbnail'],
      imageCount: _i(json['image_count']) ?? 0,
      viewCount: _i(json['view_count']),
      messageCount: _i(json['message_count']),
      offerCount: _i(json['offer_count']),
      listingQualityScore: qualityScore,
      createdAt: _s(json['created_at']),
      updatedAt: _s(json['updated_at']),
      tenure: _s(json['tenure']),
      leaseYearsRemaining: _i(json['lease_years_remaining']),
      groundRentAmount: _d(json['ground_rent_amount']),
      groundRentReviewTerms: _s(json['ground_rent_review_terms']),
      serviceChargeAmount: _d(json['service_charge_amount']),
      serviceChargeFrequency: _s(json['service_charge_frequency']),
      managingAgentDetails: _s(json['managing_agent_details']),
      councilTaxBand: _s(json['council_tax_band']),
      yearBuilt: _i(json['year_built']),
      constructionType: _s(json['construction_type']),
      nonStandardConstruction: _b(json['non_standard_construction']),
      electricitySupply: _s(json['electricity_supply']),
      waterSupply: _s(json['water_supply']),
      sewerage: _s(json['sewerage']),
      heatingType: _s(json['heating_type']),
      broadbandSpeed: _s(json['broadband_speed']),
      broadbandProvider: _s(json['broadband_provider']),
      broadbandMonthlyCost: _d(json['broadband_monthly_cost']),
      mobileSignal: json['mobile_signal'] is Map
          ? Map<String, dynamic>.from(json['mobile_signal'] as Map)
          : null,
      parkingType: _s(json['parking_type']),
      restrictiveCovenants: _b(json['restrictive_covenants']),
      restrictiveCovenantsDetails: _s(json['restrictive_covenants_details']),
      rightsOfWay: _b(json['rights_of_way']),
      rightsOfWayDetails: _s(json['rights_of_way_details']),
      listedBuilding: _s(json['listed_building']),
      conservationArea: _b(json['conservation_area']),
      floodRisk: _s(json['flood_risk']),
      coastalErosionRisk: _b(json['coastal_erosion_risk']),
      miningArea: _s(json['mining_area']),
      japaneseKnotweed: _s(json['japanese_knotweed']),
      accessibilityFeatures: _s(json['accessibility_features']),
      claddingType: _s(json['cladding_type']),
      ews1Available: _b(json['ews1_available']),
      buildingSafetyNotes: _s(json['building_safety_notes']),
      extensionsYear: _i(json['extensions_year']),
      loftConversionYear: _i(json['loft_conversion_year']),
      rewiringYear: _i(json['rewiring_year']),
      reroofYear: _i(json['reroof_year']),
      newBoilerYear: _i(json['new_boiler_year']),
      newWindowsYear: _i(json['new_windows_year']),
      dampProofingYear: _i(json['damp_proofing_year']),
      worksNotes: _s(json['works_notes']),
      nhbcYearsRemaining: _i(json['nhbc_years_remaining']),
      solarPanels: _s(json['solar_panels']),
      annualGasBill: _d(json['annual_gas_bill']),
      annualElectricityBill: _d(json['annual_electricity_bill']),
      annualWaterBill: _d(json['annual_water_bill']),
      radonRisk: _s(json['radon_risk']),
      noiseSources: _s(json['noise_sources']),
      nearestStationName: _s(json['nearest_station_name']),
      nearestStationDistanceKm: _d(json['nearest_station_distance_km']),
      nearbySchools: _s(json['nearby_schools']),
      gardenSizeSqm: _d(json['garden_size_sqm']),
      gardenOrientation: _s(json['garden_orientation']),
      outbuildings: _s(json['outbuildings']),
      chainStatus: _s(json['chain_status']),
      earliestCompletionDate: json['earliest_completion_date'],
      reasonForSale: _s(json['reason_for_sale']),
      fixturesIncluded: _s(json['fixtures_included']),
      fixturesExcluded: _s(json['fixtures_excluded']),
      fixturesNegotiable: _s(json['fixtures_negotiable']),
      smartHome: _b(json['smart_home']),
      evCharging: _b(json['ev_charging']),
      solarBatteryStorage: _b(json['solar_battery_storage']),
      rainwaterHarvesting: _b(json['rainwater_harvesting']),
      homeOffice: _b(json['home_office']),
      petFriendlyFeatures: _b(json['pet_friendly_features']),
    );
  }

  /// Full-update payload. Only used by the edit screen when the user hits
  /// save on the existing form. Phase 2 screen uses partial PATCH payloads
  /// built field-by-field so most fields never go through this method.
  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'brief_description': briefDescription,
        'property_type': propertyType,
        'status': status,
        'price': price.toString(),
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'city': city,
        'county': county,
        'postcode': postcode,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'reception_rooms': receptionRooms,
        'square_feet': squareFeet,
        'epc_rating': epcRating,
        'features': features.map((f) => f.id).toList(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (whatThreeWords.isNotEmpty) 'what3words': whatThreeWords,
        if (videoUrl != null) 'video_url': videoUrl,
      };

  String get formattedPrice {
    return '\u00A3${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}
