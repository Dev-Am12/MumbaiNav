import 'package:flutter/material.dart';

/// A station on the decorative corridor illustration.
/// `pos` is fractional (0.0–1.0) within the drawable area — NOT a real
/// GPS coordinate. This is intentionally a stylized map, not a
/// geographically accurate one (see Path A vs B discussion: this is
/// the decorative-art path, real geography is a documented future swap).
class CorridorStation {
  final String name;
  final Offset pos;
  const CorridorStation(this.name, this.pos);
}

/// One drawn line through a sequence of station names, e.g. the
/// "via Bandra" route. `stationOrder` entries must match a `name` in
/// the corridor's `stations` list exactly.
class CorridorPath {
  final List<String> stationOrder;
  final Color color;
  final double strokeWidth;

  const CorridorPath({
    required this.stationOrder,
    required this.color,
    this.strokeWidth = 3.5,
  });
}

/// A full corridor illustration's data: every station shown, and every
/// route line drawn through them. The painter knows nothing about
/// "Andheri" or "BKC" specifically — it only knows how to draw whatever
/// CorridorData it's given.
class CorridorData {
  final String id;
  final String label;
  final List<CorridorStation> stations;
  final List<CorridorPath> paths;

  const CorridorData({
    required this.id,
    required this.label,
    required this.stations,
    required this.paths,
  });

  Offset positionOf(String stationName) {
    return stations
        .firstWhere(
          (s) => s.name == stationName,
          orElse: () => throw ArgumentError(
            'CorridorData "$id" has no station named "$stationName" — '
            'check stationOrder matches a defined CorridorStation.',
          ),
        )
        .pos;
  }
}