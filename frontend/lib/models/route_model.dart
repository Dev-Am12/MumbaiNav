enum TransitMode { train, bus, bike, walk }

/// One leg of a multi-modal route (e.g. "Western Line train, 12m").
class ModeSegment {
  final TransitMode mode;
  final String label; // e.g. "W. LINE", "318", "2m"
  final String duration; // e.g. "12m"

  const ModeSegment({
    required this.mode,
    required this.label,
    required this.duration,
  });

  factory ModeSegment.fromBackendStep(Map<String, dynamic> step) {
    final mode = parseTransitMode(step['mode'] as String?);
    final totalSeconds =
        ((step['wait_seconds'] as num?) ?? 0) + ((step['travel_seconds'] as num?) ?? 0);

    return ModeSegment(
      mode: mode,
      label: backendSegmentLabel(mode, step),
      duration: formatDurationFromSeconds(totalSeconds),
    );
  }
}

/// A single candidate route, as returned by the A* engine and
/// (for the top pick) re-ranked/annotated by the Gemini AI layer.
/// Mirrors the shape implied by PRD Section 8.2's prompt structure.
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
    case 'train':
      return TransitMode.train;
    case 'bus':
      return TransitMode.bus;
    case 'bike':
      return TransitMode.bike;
    case 'walk':
    default:
      return TransitMode.walk;
  }
}

String backendSegmentLabel(TransitMode mode, Map<String, dynamic> step) {
  final toStation = (step['to_station'] as String?) ?? '';

  switch (mode) {
    case TransitMode.train:
      return 'TRAIN';
    case TransitMode.bus:
      if (toStation.contains('RBI')) return 'RBI';
      if (toStation.contains('Diamond')) return 'DB';
      return 'BUS';
    case TransitMode.bike:
      return 'BIKE';
    case TransitMode.walk:
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
