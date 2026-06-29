/// Hardcoded BGC context used when web search returns nothing.
const Map<String, dynamic> bgcContextFallback = {
  'recurring_events': [
    {
      'name': 'BGC Night Market',
      'location': 'Burgos Circle',
      'day': 'Friday',
      'time': '6PM-12AM',
      'impact': 'Heavy foot traffic near Burgos Circle',
      'penalty': 10,
    },
    {
      'name': 'Weekend Market',
      'location': 'High Street',
      'day': 'Saturday',
      'time': '8AM-2PM',
      'impact': 'Congested sidewalks along High Street',
      'penalty': 8,
    },
    {
      'name': 'Sunday Salcedo Market',
      'location': 'Serendra',
      'day': 'Sunday',
      'time': '7AM-2PM',
      'impact': 'Moderate crowd near Serendra area',
      'penalty': 5,
    },
    {
      'name': 'BGC Sunrise Run',
      'location': 'Track 30th',
      'day': 'Saturday',
      'time': '5AM-8AM',
      'impact': 'Blocked pathways near Track 30th',
      'penalty': 8,
    },
  ],
  'rush_hour_patterns': [
    {
      'day': 'Monday-Friday',
      'time': '7AM-9AM',
      'areas': ['High Street', 'BGC Bus Stop'],
      'description': 'Heavy morning commuter traffic',
    },
    {
      'day': 'Monday-Friday',
      'time': '5PM-8PM',
      'areas': ['High Street', 'SM Aura', 'Market Market'],
      'description': 'Peak evening rush, sidewalks congested',
    },
    {
      'day': 'Friday',
      'time': '5PM-10PM',
      'areas': ['Burgos Circle', 'The Fort Strip'],
      'description': 'Friday nightlife crowd builds early',
    },
    {
      'day': 'Saturday-Sunday',
      'time': '12PM-6PM',
      'areas': ['SM Aura', 'Uptown Mall', 'High Street'],
      'description': 'Weekend leisure crowd at peak',
    },
  ],
  'safety_patterns': [
    {
      'area': 'Burgos Circle',
      'time': 'Night 10PM+',
      'note': 'Nightlife crowd, watch belongings',
    },
    {
      'area': 'BGC perimeter roads',
      'time': 'Night 9PM+',
      'note': 'Low foot traffic, stay on main roads',
    },
    {
      'area': 'Market Market',
      'time': 'Evening 6PM+',
      'note': 'Crowded parking exits, use pedestrian lane',
    },
    {
      'area': 'McKinley Hill',
      'time': 'Night',
      'note': 'Limited lighting on side streets',
    },
  ],
};

class BgcLocalContext {
  const BgcLocalContext({
    required this.matchedEvents,
    required this.matchedRushHour,
    required this.matchedSafety,
    required this.localContextSummary,
    required this.adjustments,
    required this.totalEventPenalty,
  });

  final List<Map<String, dynamic>> matchedEvents;
  final Map<String, dynamic>? matchedRushHour;
  final List<Map<String, dynamic>> matchedSafety;
  final String localContextSummary;
  final List<String> adjustments;
  final int totalEventPenalty;

  String get matchedEventsText => matchedEvents.isEmpty
      ? 'No known recurring events today'
      : matchedEvents
          .map((e) => '${e['name']} at ${e['location']}: ${e['impact']}')
          .join('; ');

  String get matchedRushHourText => matchedRushHour == null
      ? 'Normal traffic conditions'
      : '${matchedRushHour!['description']} (${matchedRushHour!['areas']?.join(', ')})';

  String get matchedSafetyText => matchedSafety.isEmpty
      ? 'No specific safety notes'
      : matchedSafety.map((s) => '${s['area']}: ${s['note']}').join('; ');
}

class BgcContextMatcher {
  BgcContextMatcher._();

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static BgcLocalContext match({
    required DateTime now,
    required String destinationLabel,
  }) {
    final dayName = _weekdays[now.weekday - 1];
    final events = _matchEvents(dayName, now);
    final rush = _matchRushHour(dayName, now);
    final safety = _matchSafety(destinationLabel, now);

    final adjustments = <String>[];
    var penalty = 0;

    for (final event in events) {
      adjustments.add(event['impact'] as String? ?? event['name'] as String);
      penalty += (event['penalty'] as num?)?.toInt() ?? 0;
    }
    if (rush != null) {
      adjustments.add(rush['description'] as String);
    }
    for (final note in safety) {
      adjustments.add('${note['area']}: ${note['note']}');
    }

    final parts = <String>[];
    if (events.isNotEmpty) {
      parts.add('Events: ${events.map((e) => e['name']).join(', ')}');
    }
    if (rush != null) {
      parts.add('Rush: ${rush['description']}');
    }
    if (safety.isNotEmpty) {
      parts.add('Safety: ${safety.map((s) => s['area']).join(', ')}');
    }

    return BgcLocalContext(
      matchedEvents: events,
      matchedRushHour: rush,
      matchedSafety: safety,
      localContextSummary:
          parts.isEmpty ? 'Typical BGC pedestrian conditions' : parts.join('. '),
      adjustments: adjustments,
      totalEventPenalty: penalty.clamp(0, 15),
    );
  }

  static List<Map<String, dynamic>> _matchEvents(String dayName, DateTime now) {
    final events =
        (bgcContextFallback['recurring_events'] as List).cast<Map<String, dynamic>>();
    return events.where((event) {
      if (!_dayMatches(event['day'] as String, dayName)) return false;
      return _timeInRange(now, event['time'] as String);
    }).toList();
  }

  static Map<String, dynamic>? _matchRushHour(String dayName, DateTime now) {
    final patterns = (bgcContextFallback['rush_hour_patterns'] as List)
        .cast<Map<String, dynamic>>();
    for (final pattern in patterns) {
      if (!_dayMatches(pattern['day'] as String, dayName)) continue;
      if (_timeInRange(now, pattern['time'] as String)) return pattern;
    }
    return null;
  }

  static List<Map<String, dynamic>> _matchSafety(
    String destinationLabel,
    DateTime now,
  ) {
    final patterns = (bgcContextFallback['safety_patterns'] as List)
        .cast<Map<String, dynamic>>();
    final lower = destinationLabel.toLowerCase();
    return patterns.where((pattern) {
      final area = (pattern['area'] as String).toLowerCase();
      final areaMatch = lower.contains(area) ||
          area.contains(lower) ||
          _destinationAliases(lower, area);
      if (!areaMatch) return false;
      return _safetyTimeMatches(now, pattern['time'] as String);
    }).toList();
  }

  static bool _destinationAliases(String dest, String area) {
    if (area.contains('burgos') && dest.contains('burgos')) return true;
    if (area.contains('market') && dest.contains('market')) return true;
    if (area.contains('mckinley') && dest.contains('mckinley')) return true;
    if (area.contains('serendra') && dest.contains('serendra')) return true;
    if (area.contains('perimeter')) return false;
    return false;
  }

  static bool _dayMatches(String pattern, String dayName) {
    if (pattern == dayName) return true;
    if (pattern == 'Monday-Friday') {
      return dayName != 'Saturday' && dayName != 'Sunday';
    }
    if (pattern == 'Saturday-Sunday') {
      return dayName == 'Saturday' || dayName == 'Sunday';
    }
    return false;
  }

  static bool _timeInRange(DateTime now, String range) {
    final parts = range.split('-');
    if (parts.length != 2) return false;
    final start = _parseMinutes(parts[0].trim());
    final end = _parseMinutes(parts[1].trim());
    if (start == null || end == null) return false;
    final current = now.hour * 60 + now.minute;
    if (start <= end) {
      return current >= start && current <= end;
    }
    return current >= start || current <= end;
  }

  static bool _safetyTimeMatches(DateTime now, String pattern) {
    final hour = now.hour;
    if (pattern.startsWith('Night')) {
      if (pattern.contains('10PM')) return hour >= 22 || hour < 5;
      if (pattern.contains('9PM')) return hour >= 21 || hour < 5;
      return hour >= 21 || hour < 5;
    }
    if (pattern.startsWith('Evening')) {
      return hour >= 18;
    }
    return true;
  }

  static int? _parseMinutes(String token) {
    final match = RegExp(r'(\d{1,2})(AM|PM)?', caseSensitive: false)
        .firstMatch(token.replaceAll(' ', ''));
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final period = match.group(2)?.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return hour * 60;
  }
}
