import 'dart:convert';

/// One day of a trip itinerary.
class ItineraryDay {
  final int day; // 1-based
  final String title;
  final List<String> activities;

  const ItineraryDay({
    required this.day,
    required this.title,
    required this.activities,
  });

  ItineraryDay copyWith({int? day, String? title, List<String>? activities}) =>
      ItineraryDay(
        day: day ?? this.day,
        title: title ?? this.title,
        activities: activities ?? this.activities,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'title': title,
        'activities': activities,
      };

  factory ItineraryDay.fromJson(Map<dynamic, dynamic> j) => ItineraryDay(
        day: ((j['day'] as num?) ?? 1).toInt(),
        title: (j['title'] as String?) ?? '',
        activities: _stringList(j['activities']),
      );
}

/// Firebase returns arrays either as JSON lists or as {"0": .., "1": ..} maps.
List<dynamic> _looseList(dynamic v) {
  if (v is List) return v.where((e) => e != null).toList();
  if (v is Map) {
    final keys = v.keys.toList()
      ..sort((a, b) => (int.tryParse('$a') ?? 0).compareTo(int.tryParse('$b') ?? 0));
    return keys.map((k) => v[k]).where((e) => e != null).toList();
  }
  if (v is String && v.isNotEmpty) {
    try {
      return _looseList(jsonDecode(v));
    } catch (_) {
      return const [];
    }
  }
  return const [];
}

List<String> _stringList(dynamic v) =>
    _looseList(v).map((e) => e.toString()).toList();

List<ItineraryDay> _itinerary(dynamic v) => _looseList(v)
    .whereType<Map>()
    .map((m) => ItineraryDay.fromJson(m))
    .toList();

/// Formats a date as yyyy-MM-dd (stored form).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseIsoDate(String? s) {
  if (s == null || s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// A planned trip. Stored in SQLite / browser storage (toMap/fromMap) and in
/// Firebase Realtime Database (toJson/fromJson).
class Trip {
  final String id;
  final String destination;
  final String startDate; // yyyy-MM-dd
  final String endDate; // yyyy-MM-dd
  final int budget; // total trip budget for all travellers, in INR
  final int travellers;
  final String travelType;
  final List<String> preferences;
  final List<ItineraryDay> itinerary;
  final String notes;
  final int estimatedCost; // 0 when unknown (custom destination)
  final int createdAt; // ms since epoch
  final int updatedAt; // ms since epoch, used for sync conflict resolution
  final bool synced; // true when the cloud copy is up to date
  final bool deleted; // local tombstone waiting for the cloud delete

  const Trip({
    required this.id,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.travellers,
    required this.travelType,
    required this.preferences,
    required this.itinerary,
    required this.notes,
    required this.estimatedCost,
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
    this.deleted = false,
  });

  DateTime get start => parseIsoDate(startDate) ?? DateTime.now();
  DateTime get end => parseIsoDate(endDate) ?? start;

  /// Number of days, inclusive of start and end.
  int get days {
    final d = end.difference(start).inDays + 1;
    return d < 1 ? 1 : d;
  }

  bool isUpcoming([DateTime? now]) {
    final n = now ?? DateTime.now();
    return !end.isBefore(DateTime(n.year, n.month, n.day));
  }

  Trip copyWith({
    String? destination,
    String? startDate,
    String? endDate,
    int? budget,
    int? travellers,
    String? travelType,
    List<String>? preferences,
    List<ItineraryDay>? itinerary,
    String? notes,
    int? estimatedCost,
    int? createdAt,
    int? updatedAt,
    bool? synced,
    bool? deleted,
  }) {
    return Trip(
      id: id,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      travellers: travellers ?? this.travellers,
      travelType: travelType ?? this.travelType,
      preferences: preferences ?? this.preferences,
      itinerary: itinerary ?? this.itinerary,
      notes: notes ?? this.notes,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
    );
  }

  /// Local row (SQLite / browser storage). Lists are stored as JSON text.
  Map<String, Object?> toMap() => {
        'id': id,
        'destination': destination,
        'startDate': startDate,
        'endDate': endDate,
        'days': days,
        'budget': budget,
        'travellers': travellers,
        'travelType': travelType,
        'preferences': jsonEncode(preferences),
        'itinerary': jsonEncode(itinerary.map((d) => d.toJson()).toList()),
        'notes': notes,
        'estimatedCost': estimatedCost,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'synced': synced ? 1 : 0,
        'deleted': deleted ? 1 : 0,
      };

  factory Trip.fromMap(Map<String, Object?> m) =>
      _fromAny(m['id'] as String, m, synced: ((m['synced'] as num?) ?? 0) == 1)
          .copyWith(deleted: ((m['deleted'] as num?) ?? 0) == 1);

  /// Firebase node (the id is the node key, so it is not repeated inside).
  Map<String, dynamic> toJson() => {
        'destination': destination,
        'startDate': startDate,
        'endDate': endDate,
        'budget': budget,
        'travellers': travellers,
        'travelType': travelType,
        'preferences': preferences,
        'itinerary': itinerary.map((d) => d.toJson()).toList(),
        'notes': notes,
        'estimatedCost': estimatedCost,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Trip.fromJson(String id, Map<dynamic, dynamic> j) =>
      _fromAny(id, j, synced: true);

  /// Shared parser. Also upgrades v1 records (which only had `days`).
  static Trip _fromAny(String id, Map<dynamic, dynamic> m, {required bool synced}) {
    final updatedAt = ((m['updatedAt'] as num?) ?? 0).toInt();
    final createdAt = ((m['createdAt'] as num?) ?? updatedAt).toInt();
    var start = parseIsoDate(m['startDate'] as String?);
    var end = parseIsoDate(m['endDate'] as String?);
    if (start == null) {
      final base = createdAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(createdAt)
          : DateTime.now();
      start = DateTime(base.year, base.month, base.day);
    }
    if (end == null || end.isBefore(start)) {
      final legacyDays = ((m['days'] as num?) ?? 1).toInt();
      end = start.add(Duration(days: (legacyDays < 1 ? 1 : legacyDays) - 1));
    }
    final travellers = ((m['travellers'] as num?) ?? 1).toInt();
    return Trip(
      id: id,
      destination: (m['destination'] as String?) ?? '',
      startDate: isoDate(start),
      endDate: isoDate(end),
      budget: ((m['budget'] as num?) ?? 0).toInt(),
      travellers: travellers < 1 ? 1 : travellers,
      travelType: (m['travelType'] as String?) ?? 'Beach',
      preferences: _stringList(m['preferences']),
      itinerary: _itinerary(m['itinerary']),
      notes: (m['notes'] as String?) ?? '',
      estimatedCost: ((m['estimatedCost'] as num?) ?? 0).toInt(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      synced: synced,
    );
  }
}
