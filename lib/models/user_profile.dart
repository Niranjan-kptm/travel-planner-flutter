/// Profile stored at /users/<uid>/profile in the Realtime Database.
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String homeCity;
  final String preferredTravelType;
  final List<String> interests;
  final int defaultBudget; // INR
  final int createdAt;
  final int updatedAt;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.homeCity = '',
    this.preferredTravelType = '',
    this.interests = const [],
    this.defaultBudget = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  String get firstName {
    final n = name.trim();
    if (n.isEmpty) return email.split('@').first;
    return n.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? homeCity,
    String? preferredTravelType,
    List<String>? interests,
    int? defaultBudget,
    int? createdAt,
    int? updatedAt,
  }) =>
      UserProfile(
        uid: uid,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        homeCity: homeCity ?? this.homeCity,
        preferredTravelType: preferredTravelType ?? this.preferredTravelType,
        interests: interests ?? this.interests,
        defaultBudget: defaultBudget ?? this.defaultBudget,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'homeCity': homeCity,
        'preferredTravelType': preferredTravelType,
        'interests': interests,
        'defaultBudget': defaultBudget,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory UserProfile.fromJson(String uid, Map<dynamic, dynamic> j) {
    final rawInterests = j['interests'];
    final interests = rawInterests is List
        ? rawInterests.where((e) => e != null).map((e) => e.toString()).toList()
        : rawInterests is Map
            ? rawInterests.values.where((e) => e != null).map((e) => e.toString()).toList()
            : <String>[];
    return UserProfile(
      uid: uid,
      name: (j['name'] as String?) ?? '',
      email: (j['email'] as String?) ?? '',
      phone: (j['phone'] as String?) ?? '',
      homeCity: (j['homeCity'] as String?) ?? '',
      preferredTravelType: (j['preferredTravelType'] as String?) ?? '',
      interests: interests,
      defaultBudget: ((j['defaultBudget'] as num?) ?? 0).toInt(),
      createdAt: ((j['createdAt'] as num?) ?? 0).toInt(),
      updatedAt: ((j['updatedAt'] as num?) ?? 0).toInt(),
    );
  }
}
