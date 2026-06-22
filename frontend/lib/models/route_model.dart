enum TransitMode { train, bus, bike, walk }

/// One leg of a multi-modal route (e.g. "Western Line train, 12m").
class ModeSegment {
  final TransitMode mode;
  final String label;   // e.g. "WR LOCAL", "BEST 318", "YULU"
  final String sublabel; // from → to short form, shown as second line
  final String duration; // e.g. "12m"

  const ModeSegment({
    required this.mode,
    required this.label,
    required this.duration,
    this.sublabel = '',
  });

  factory ModeSegment.fromBackendStep(Map<String, dynamic> step) {
    final mode = parseTransitMode(step['mode'] as String?);
    final totalSeconds =
        ((step['wait_seconds'] as num?) ?? 0) +
        ((step['travel_seconds'] as num?) ?? 0);
    final fromStation = (step['from_station'] as String?) ?? '';
    final toStation   = (step['to_station']   as String?) ?? '';

    return ModeSegment(
      mode:      mode,
      label:     backendSegmentLabel(mode, step),
      sublabel:  _shortStation(toStation),
      duration:  formatDurationFromSeconds(totalSeconds),
    );
  }
}

/// Shorten a full station name to something that fits in the chip
/// e.g. "BKC Bus Stop (RBI, SW)" → "BKC (RBI)"
String _shortStation(String name) {
  if (name.contains('BKC Bus Stop (RBI'))         return 'BKC (RBI)';
  if (name.contains('BKC Bus Stop (Diamond'))      return 'BKC (DB)';
  if (name.contains('BKC Bike Dock'))              return 'BKC Dock';
  if (name.contains('Bandra Station Bus Stop'))    return 'Bandra BS';
  if (name.contains('Kurla Station Bus Stop'))     return 'Kurla BS';
  if (name.contains('Bandra Station Bike Dock'))   return 'Bandra BD';
  if (name.contains('Kurla Station Bike Dock'))    return 'Kurla BD';
  if (name.contains('Dadar (Western)'))            return 'Dadar WR';
  if (name.contains('Dadar (Central)'))            return 'Dadar CR';
  return name.length > 10 ? '${name.substring(0, 10)}…' : name;
}

/// A single candidate route, as returned by the A* engine and
/// (for the top pick) re-ranked/annotated by the Gemini AI layer.
class RouteOption {
  final String id;
  final int etaMinutes;
  final String arrivalTime;
  final String fare;
  final List<ModeSegment> segments;

  /// 0.0 (empty) to 1.0 (packed) — matches crowd_density.density_score
  final double crowdLevel;

  final bool isRecommended;
  final String? aiReasoning;

  /// Only set on a live-recalculated route, e.g. "ETA improved by 2m"
  final String? etaChangeNote;
  final int? etaDeltaMinutes;

  const RouteOption({
    required this.id,
    required this.etaMinutes,
    required this.arrivalTime,
    required this.fare,
    required this.segments,
    required this.crowdLevel,
    this.isRecommended = false,
    this.aiReasoning,
    this.etaChangeNote,
    this.etaDeltaMinutes,
  });

  RouteOption copyWith({
    int? etaMinutes,
    String? arrivalTime,
    double? crowdLevel,
    String? aiReasoning,
    String? etaChangeNote,
    int? etaDeltaMinutes,
  }) {
    return RouteOption(
      id: id,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      fare: fare,
      segments: segments,
      crowdLevel: crowdLevel ?? this.crowdLevel,
      isRecommended: isRecommended,
      aiReasoning: aiReasoning ?? this.aiReasoning,
      etaChangeNote: etaChangeNote ?? this.etaChangeNote,
      etaDeltaMinutes: etaDeltaMinutes ?? this.etaDeltaMinutes,
    );
  }
}

TransitMode parseTransitMode(String? rawMode) {
  switch (rawMode) {
    case 'train': return TransitMode.train;
    case 'bus':   return TransitMode.bus;
    case 'bike':  return TransitMode.bike;
    case 'walk':
    default:      return TransitMode.walk;
  }
}

String backendSegmentLabel(TransitMode mode, Map<String, dynamic> step) {
  final fromStation = (step['from_station'] as String?) ?? '';
  final toStation   = (step['to_station']   as String?) ?? '';
  final pair = '$fromStation→$toStation';

  switch (mode) {
    case TransitMode.train:
      // Derive line from station names — all stations in our seed are known.
      // Western Line: Andheri, Bandra, Dadar (Western)
      // Central Line: Kurla, Dadar (Central)
      // Harbour Line: direct Andheri↔Kurla (sparse, 33 min each way)
      const westernStations = {
        'Andheri', 'Bandra', 'Dadar (Western)',
      };
      const centralStations = {
        'Kurla', 'Dadar (Central)',
      };
      if (westernStations.contains(fromStation)) return 'WR LOCAL';
      if (centralStations.contains(fromStation)) return 'CR LOCAL';
      return 'LOCAL';

    case TransitMode.bus:
      // Fixed routes for the seeded corridor — no route numbers in DB schema,
      // so we derive from the known station pairs in seed/02_dadar_and_edges.sql.
      // BEST route 318 (approx): Bandra Station ↔ BKC (RBI gate)
      // BEST route C-54 (approx): Kurla Station ↔ BKC (Diamond Bourse gate)
      const busRoutes = <String, String>{
        'Bandra Station Bus Stop→BKC Bus Stop (RBI, SW)':            'BEST 318',
        'BKC Bus Stop (RBI, SW)→Bandra Station Bus Stop':            'BEST 318',
        'Kurla Station Bus Stop→BKC Bus Stop (Diamond Bourse, NE)': 'BEST C-54',
        'BKC Bus Stop (Diamond Bourse, NE)→Kurla Station Bus Stop': 'BEST C-54',
        // BKC internal walk treated as bus_corridor in some seeds — guard it
        'BKC Bus Stop (RBI, SW)→BKC Bus Stop (Diamond Bourse, NE)': 'BKC WALK',
        'BKC Bus Stop (Diamond Bourse, NE)→BKC Bus Stop (RBI, SW)': 'BKC WALK',
      };
      return busRoutes[pair] ?? 'BEST BUS';

    case TransitMode.bike:
      return 'YULU';

    case TransitMode.walk:
      // For walk we show a destination hint rather than "WALK"
      if (toStation.contains('Bus Stop'))  return 'TO BUS';
      if (toStation.contains('Bike Dock')) return 'TO DOCK';
      if (toStation.contains('BKC'))       return 'TO BKC';
      if (toStation.contains('Bandra'))    return 'TO BANDRA';
      if (toStation.contains('Kurla'))     return 'TO KURLA';
      return 'WALK';
  }
}

String formatDurationFromSeconds(num seconds) {
  final minutes = (seconds / 60).round();
  return '${minutes}m';
}

String crowdLabel(double level) {
  if (level < 0.4) return 'LOW';
  if (level < 0.7) return 'MODERATE';
  return 'HIGH';
}