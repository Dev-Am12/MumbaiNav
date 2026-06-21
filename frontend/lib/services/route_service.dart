import '../models/route_model.dart';

class RouteService {
  /// GET /routes?origin=Andheri&destination=BKC
  /// Returns the A* candidates + AI-recommended top pick (PRD 8.1, steps 1-4).
  static Future<List<RouteOption>> fetchRoutes({
    required String origin,
    required String destination,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    return const [
      RouteOption(
        id: 'via-bandra-train-bus',
        etaMinutes: 24,
        arrivalTime: '09:14 AM',
        fare: '₹35',
        isRecommended: true,
        crowdLevel: 0.55,
        aiReasoning:
            'Train crowd dropping — optimal connection found at Bandra.',
        segments: [
          ModeSegment(mode: TransitMode.train, label: 'W. LINE', duration: '12m'),
          ModeSegment(mode: TransitMode.bus, label: '310', duration: '10m'),
          ModeSegment(mode: TransitMode.walk, label: 'WALK', duration: '2m'),
        ],
      ),
      RouteOption(
        id: 'via-bandra-train-bike',
        etaMinutes: 28,
        arrivalTime: '09:18 AM',
        fare: '₹40',
        crowdLevel: 0.7,
        segments: [
          ModeSegment(mode: TransitMode.train, label: 'W. LINE', duration: '12m'),
          ModeSegment(mode: TransitMode.bike, label: 'YULU', duration: '14m'),
        ],
      ),
      RouteOption(
        id: 'direct-bus',
        etaMinutes: 42,
        arrivalTime: '09:32 AM',
        fare: '₹20',
        crowdLevel: 0.85,
        segments: [
          ModeSegment(mode: TransitMode.bus, label: 'C-54', duration: '42m'),
        ],
      ),
    ];
  }

  static Future<RouteOption> fetchLiveUpdate(RouteOption original) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    return original.copyWith(
      etaMinutes: original.etaMinutes - 2,
      crowdLevel: (original.crowdLevel - 0.25).clamp(0.0, 1.0),
      aiReasoning:
          'Train crowd dropping — transferring to Bus 310 still recommended.',
      etaChangeNote: 'ETA improved by 2m',
      etaDeltaMinutes: -2,
    );
  }
}