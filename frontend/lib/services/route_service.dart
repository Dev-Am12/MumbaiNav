import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/route_model.dart';

class LiveConditionsUpdate {
  final int timestamp;
  final bool densityUpdated;
  final bool bikesUpdated;

  const LiveConditionsUpdate({
    required this.timestamp,
    required this.densityUpdated,
    required this.bikesUpdated,
  });

  factory LiveConditionsUpdate.fromPayload(Map<String, dynamic> payload) {
    return LiveConditionsUpdate(
      timestamp:
          (payload['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      densityUpdated: payload['density_updated'] == true,
      bikesUpdated: payload['bikes_updated'] == true,
    );
  }
}

class RouteService {
  static const String _apiBaseUrl = String.fromEnvironment(
    'MUMBAINAV_API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  static const Map<String, String> _destinationAliases = {
    'BKC': 'BKC Bus Stop (RBI, SW)',
  };

  static io.Socket? _socket;
  static StreamController<LiveConditionsUpdate>? _liveConditionsController;

  static Future<List<RouteOption>> fetchRoutes({
    required String origin,
    required String destination,
  }) async {
    final resolvedDestination = _destinationAliases[destination] ?? destination;
    final uri = Uri.parse(
      '$_apiBaseUrl/route/smart?from=${Uri.encodeQueryComponent(origin)}&to=${Uri.encodeQueryComponent(resolvedDestination)}',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return [];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = (decoded['candidates'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (candidates.isEmpty) {
        return [];
      }

      final aiRanking = decoded['ai_ranking'] as Map<String, dynamic>?;
      final rankedRoutes =
          (aiRanking?['ranked_routes'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
      final rankingById = <String, Map<String, dynamic>>{
        for (final entry in rankedRoutes)
          if (entry['route_id'] is String) entry['route_id'] as String: entry,
      };

      final routes = candidates
          .map(
            (candidate) => _mapCandidateToRouteOption(
              candidate,
              ranking: rankingById[candidate['route_id']],
              topChoiceReason: aiRanking?['top_choice_reason'] as String?,
            ),
          )
          .toList();

      routes.sort((a, b) {
        final aRank = (rankingById[a.id]?['rank'] as num?)?.toInt() ?? 999;
        final bRank = (rankingById[b.id]?['rank'] as num?)?.toInt() ?? 999;
        return aRank.compareTo(bRank);
      });

      if (!routes.any((route) => route.isRecommended) && routes.isNotEmpty) {
        final first = routes.first;
        routes[0] = RouteOption(
          id: first.id,
          etaMinutes: first.etaMinutes,
          arrivalTime: first.arrivalTime,
          fare: first.fare,
          segments: first.segments,
          crowdLevel: first.crowdLevel,
          isRecommended: true,
          aiReasoning: decoded['ai_error'] as String? ?? first.aiReasoning,
          etaChangeNote: first.etaChangeNote,
          etaDeltaMinutes: first.etaDeltaMinutes,
        );
      }

      return routes;
    } catch (_) {
      return [];
    }
  }

  static Stream<LiveConditionsUpdate> liveConditionsStream() {
    _ensureSocketConnected();
    return _liveConditionsController!.stream;
  }

  static void disconnectLiveConditions() {
    _socket?.dispose();
    _socket = null;
  }

  static void _ensureSocketConnected() {
    _liveConditionsController ??=
        StreamController<LiveConditionsUpdate>.broadcast();

    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      }
      return;
    }

    _socket = io.io(
      _apiBaseUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      },
    );

    _socket!.on(
      'live_conditions_update',
      (payload) {
        if (payload is Map<String, dynamic>) {
          _liveConditionsController?.add(
            LiveConditionsUpdate.fromPayload(payload),
          );
        } else if (payload is Map) {
          _liveConditionsController?.add(
            LiveConditionsUpdate.fromPayload(Map<String, dynamic>.from(payload)),
          );
        }
      },
    );

    _socket!.connect();
  }

  static RouteOption _mapCandidateToRouteOption(
    Map<String, dynamic> candidate, {
    Map<String, dynamic>? ranking,
    String? topChoiceReason,
  }) {
    final steps = (candidate['steps'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final isRecommended = (ranking?['rank'] as num?)?.toInt() == 1;
    final totalSeconds =
        (candidate['total_duration_seconds'] as num?)?.toInt() ?? 0;
    final reasoning = isRecommended
        ? (topChoiceReason ?? ranking?['reason'] as String?)
        : ranking?['reason'] as String?;

    return RouteOption(
      id: candidate['route_id'] as String? ?? 'route-${candidate.hashCode}',
      etaMinutes: (totalSeconds / 60).round(),
      arrivalTime: _formatArrivalTime(candidate['arrival_time'] as String?),
      fare: 'Rs ${_estimateFare(steps)}',
      segments: steps.map(ModeSegment.fromBackendStep).toList(),
      crowdLevel: _deriveCrowdLevel(candidate, steps),
      isRecommended: isRecommended,
      aiReasoning: reasoning,
    );
  }

  static String _formatArrivalTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) {
      return '--';
    }

    final parsed = DateTime.tryParse(isoTime);
    if (parsed == null) {
      return '--';
    }

    return DateFormat('hh:mm a').format(parsed.toLocal());
  }

  static double _deriveCrowdLevel(
    Map<String, dynamic> candidate,
    List<Map<String, dynamic>> steps,
  ) {
    final maxCrowd = (candidate['max_crowd_density'] as num?)?.toDouble();
    if (maxCrowd != null) {
      return maxCrowd.clamp(0.0, 1.0);
    }

    final stepCrowds = steps
        .map((step) => (step['crowd_density'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    if (stepCrowds.isEmpty) {
      return 0.0;
    }

    return stepCrowds.reduce((a, b) => a > b ? a : b).clamp(0.0, 1.0);
  }

  static int _estimateFare(List<Map<String, dynamic>> steps) {
    final modes = steps
        .map((step) => step['mode'] as String?)
        .whereType<String>()
        .toSet();

    var fare = 0;
    if (modes.contains('train')) fare += 15;
    if (modes.contains('bus')) fare += 20;
    if (modes.contains('bike')) fare += 25;

    return fare == 0 ? 10 : fare;
  }
}
