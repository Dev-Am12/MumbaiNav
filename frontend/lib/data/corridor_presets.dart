import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'corridor_data_model.dart';

/// Primary demo corridor — PRD Section 3, locked.
const CorridorData andheriBkcCorridor = CorridorData(
  id: 'andheri_bkc',
  label: 'MUMBAI TRANSIT CORRIDOR',
  stations: [
    CorridorStation('ANDHERI', Offset(0.04, 0.38)),
    CorridorStation('BANDRA', Offset(0.34, 0.92)),
    CorridorStation('KURLA', Offset(0.66, 0.30)),
    CorridorStation('BKC', Offset(0.97, 0.04)),
  ],
  paths: [
    CorridorPath(
      stationOrder: ['ANDHERI', 'BANDRA', 'BKC'],
      color: AppColors.navy,
    ),
    CorridorPath(
      stationOrder: ['ANDHERI', 'KURLA', 'BKC'],
      color: AppColors.amber,
      strokeWidth: 3,
    ),
  ],
);

/// Stretch-goal second corridor (PRD Section 13: "candidate Andheri →
/// Powai, also lacks direct rail access, similar pattern"). Station
/// positions below are placeholder layout only.
const CorridorData andheriPowaiCorridor = CorridorData(
  id: 'andheri_powai',
  label: 'MUMBAI TRANSIT CORRIDOR',
  stations: [
    CorridorStation('ANDHERI', Offset(0.05, 0.42)),
    CorridorStation('JB NAGAR', Offset(0.42, 0.62)),
    CorridorStation('POWAI', Offset(0.93, 0.18)),
  ],
  paths: [
    CorridorPath(
      stationOrder: ['ANDHERI', 'JB NAGAR', 'POWAI'],
      color: AppColors.navy,
    ),
  ],
);

/// Known, selectable station endpoints — intentionally a short, fixed
/// list (not free-text search) since the PRD locks the demo to specific
/// corridors rather than city-wide coverage.
const List<String> kSelectableStations = ['Andheri', 'BKC', 'Powai'];

/// Returns the illustration data for a given origin/destination pair,
/// or null if that pair has no corridor built yet. The UI is expected
/// to handle null gracefully (PRD Section 12: no coverage beyond what's
/// explicitly built).
CorridorData? corridorFor(String origin, String destination) {
  final pair = {origin, destination};
  if (pair.containsAll({'Andheri', 'BKC'})) return andheriBkcCorridor;
  if (pair.containsAll({'Andheri', 'Powai'})) return andheriPowaiCorridor;
  return null;
}

extension on Set<String> {
  bool containsAll(Set<String> other) => other.every(contains);
}