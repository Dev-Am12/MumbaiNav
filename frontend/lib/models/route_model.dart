enum TransitMode { train, bus, bike, walk }

/// One leg of a multi-modal route.
class ModeSegment {
  final TransitMode mode;
  final String label;       // e.g. "WR LOCAL", "BEST 318", "YULU"
  final String sublabel;    // short destination — shown in mode chip
  final String duration;    // combined wait+travel, e.g. "17m" — for mode chip

  // Step-by-step sheet fields
  final String fromStation;     // full boarding station name, e.g. "Andheri"
  final String toStation;       // full alighting station name
  final String? departAt;       // formatted departure time, e.g. "4:05 PM"
  final int    waitMinutes;     // scheduled wait before boarding (0 for walk/bike)
  final int    travelMinutes;   // pure travel time excluding wait

  const ModeSegment({
    required this.mode,
    required this.label,
    required this.duration,
    this.sublabel      = '',
    this.fromStation   = '',
    this.toStation     = '',
    this.departAt,
    this.waitMinutes   = 0,
    this.travelMinutes = 0,
  });

  factory ModeSegment.fromBackendStep(Map<String, dynamic> step) {
    final mode         = parseTransitMode(step['mode'] as String?);
    final waitSec      = ((step['wait_seconds']   as num?) ?? 0).toInt();
    final travelSec    = ((step['travel_seconds']  as num?) ?? 0).toInt();
    final totalSec     = waitSec + travelSec;
    final fromStation  = (step['from_station'] as String?) ?? '';
    final toStation    = (step['to_station']   as String?) ?? '';

    return ModeSegment(
      mode:          mode,
      label:         backendSegmentLabel(mode, step),
      sublabel:      _shortStation(toStation),
      duration:      formatDurationFromSeconds(totalSec),
      fromStation:   fromStation,
      toStation:     toStation,
      departAt:      _formatIsoTime(step['depart_at'] as String?),
      waitMinutes:   (waitSec  / 60).round(),
      travelMinutes: (travelSec / 60).round(),
    );
  }
}

// ── Time helpers ──────────────────────────────────────────────────────────────

String? _formatIsoTime(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  final local  = dt.toLocal();
  final h      = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m      = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $period';
}

// ── Station display helpers ───────────────────────────────────────────────────

/// Short name for the mode-chip sublabel (tight space)
String _shortStation(String name) {
  if (name.contains('BKC Bus Stop (RBI'))        return 'BKC (RBI)';
  if (name.contains('BKC Bus Stop (Diamond'))     return 'BKC (DB)';
  if (name.contains('BKC Bike Dock'))             return 'BKC Dock';
  if (name.contains('Bandra Station Bus Stop'))   return 'Bandra BS';
  if (name.contains('Kurla Station Bus Stop'))    return 'Kurla BS';
  if (name.contains('Bandra Station Bike Dock'))  return 'Bandra BD';
  if (name.contains('Kurla Station Bike Dock'))   return 'Kurla BD';
  if (name.contains('Dadar (Western)'))           return 'Dadar WR';
  if (name.contains('Dadar (Central)'))           return 'Dadar CR';
  return name.length > 12 ? '${name.substring(0, 12)}…' : name;
}

/// Clean boarding/alighting name for step-by-step sheet (more space)
String cleanStation(String name) {
  if (name.contains('BKC Bus Stop (RBI'))        return 'BKC — RBI Gate';
  if (name.contains('BKC Bus Stop (Diamond'))     return 'BKC — Diamond Bourse';
  if (name.contains('BKC Bike Dock'))             return 'BKC Bike Dock';
  if (name.contains('Bandra Station Bus Stop'))   return 'Bandra Bus Stop';
  if (name.contains('Kurla Station Bus Stop'))    return 'Kurla Bus Stop';
  if (name.contains('Bandra Station Bike Dock'))  return 'Bandra Bike Dock';
  if (name.contains('Kurla Station Bike Dock'))   return 'Kurla Bike Dock';
  return name; // train stations + Dadar already clean
}

// ── Route option ──────────────────────────────────────────────────────────────

class RouteOption {
  final String id;
  final int    etaMinutes;
  final String arrivalTime;
  final String fare;
  final List<ModeSegment> segments;
  final double crowdLevel;       // 0.0–1.0
  final bool   isRecommended;
  final String? aiReasoning;
  final String? etaChangeNote;
  final int?    etaDeltaMinutes;

  const RouteOption({
    required this.id,
    required this.etaMinutes,
    required this.arrivalTime,
    required this.fare,
    required this.segments,
    required this.crowdLevel,
    this.isRecommended   = false,
    this.aiReasoning,
    this.etaChangeNote,
    this.etaDeltaMinutes,
  });

  RouteOption copyWith({
    int?    etaMinutes,
    String? arrivalTime,
    double? crowdLevel,
    String? aiReasoning,
    String? etaChangeNote,
    int?    etaDeltaMinutes,
  }) {
    return RouteOption(
      id:              id,
      etaMinutes:      etaMinutes   ?? this.etaMinutes,
      arrivalTime:     arrivalTime  ?? this.arrivalTime,
      fare:            fare,
      segments:        segments,
      crowdLevel:      crowdLevel   ?? this.crowdLevel,
      isRecommended:   isRecommended,
      aiReasoning:     aiReasoning  ?? this.aiReasoning,
      etaChangeNote:   etaChangeNote   ?? this.etaChangeNote,
      etaDeltaMinutes: etaDeltaMinutes ?? this.etaDeltaMinutes,
    );
  }
}

// ── Label helpers ─────────────────────────────────────────────────────────────

TransitMode parseTransitMode(String? rawMode) {
  switch (rawMode) {
    case 'train': return TransitMode.train;
    case 'bus':   return TransitMode.bus;
    case 'bike':  return TransitMode.bike;
    default:      return TransitMode.walk;
  }
}

String backendSegmentLabel(TransitMode mode, Map<String, dynamic> step) {
  final from = (step['from_station'] as String?) ?? '';
  final to   = (step['to_station']   as String?) ?? '';
  final pair = '$from→$to';

  switch (mode) {
    case TransitMode.train:
      const western = {'Andheri', 'Bandra', 'Dadar (Western)'};
      const central = {'Kurla', 'Dadar (Central)'};
      if (western.contains(from)) return 'WR LOCAL';
      if (central.contains(from)) return 'CR LOCAL';
      return 'LOCAL';

    case TransitMode.bus:
      const routes = <String, String>{
        'Bandra Station Bus Stop→BKC Bus Stop (RBI, SW)':             'BEST 318',
        'BKC Bus Stop (RBI, SW)→Bandra Station Bus Stop':             'BEST 318',
        'Kurla Station Bus Stop→BKC Bus Stop (Diamond Bourse, NE)':  'BEST C-54',
        'BKC Bus Stop (Diamond Bourse, NE)→Kurla Station Bus Stop':  'BEST C-54',
        'BKC Bus Stop (RBI, SW)→BKC Bus Stop (Diamond Bourse, NE)':  'BKC WALK',
        'BKC Bus Stop (Diamond Bourse, NE)→BKC Bus Stop (RBI, SW)':  'BKC WALK',
      };
      return routes[pair] ?? 'BEST BUS';

    case TransitMode.bike:
      return 'YULU';

    case TransitMode.walk:
      // Walk label is only used in the mode chip, not the step sheet.
      // Keep it directional.
      if (to.contains('Bus Stop'))  return 'TO BUS';
      if (to.contains('Bike Dock')) return 'TO DOCK';
      if (to.contains('BKC'))       return 'TO BKC';
      if (to.contains('Bandra'))    return 'TO BANDRA';
      if (to.contains('Kurla'))     return 'TO KURLA';
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