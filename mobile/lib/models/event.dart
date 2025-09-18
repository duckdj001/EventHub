class Event {
  final String id;
  final String title;
  final String description;
  final String city;
  final String? address;
  final double? lat;
  final double? lon;
  final DateTime startAt;
  final DateTime endAt;
  final bool requiresApproval;
  final bool isPaid;
  final bool isAddressHidden;
  final bool isAdultOnly;
  final int? price;
  final String? currency;
  final String? coverUrl;
  final String? categoryId;
  final String status;
  final int? capacity;
  final String? ownerId;
  final String? participationStatus;
  final EventOwner? owner;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.city,
    required this.startAt,
    required this.endAt,
    required this.requiresApproval,
    required this.isPaid,
    required this.isAddressHidden,
    required this.isAdultOnly,
    required this.status,
    this.address,
    this.lat,
    this.lon,
    this.price,
    this.currency,
    this.coverUrl,
    this.categoryId,
    this.capacity,
    this.ownerId,
    this.participationStatus,
    this.owner,
  });

  Event copyWith({
    String? title,
    String? description,
    String? city,
    String? address,
    double? lat,
    double? lon,
    DateTime? startAt,
    DateTime? endAt,
    bool? requiresApproval,
    bool? isPaid,
    bool? isAddressHidden,
    bool? isAdultOnly,
    int? price,
    String? currency,
    String? coverUrl,
    String? categoryId,
    String? status,
    int? capacity,
    String? ownerId,
    String? participationStatus,
    EventOwner? owner,
  }) {
    return Event(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      city: city ?? this.city,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      isPaid: isPaid ?? this.isPaid,
      isAddressHidden: isAddressHidden ?? this.isAddressHidden,
      isAdultOnly: isAdultOnly ?? this.isAdultOnly,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      coverUrl: coverUrl ?? this.coverUrl,
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
      ownerId: ownerId ?? this.ownerId,
      participationStatus: participationStatus ?? this.participationStatus,
      owner: owner ?? this.owner,
    );
  }

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        address: j['address'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        startAt: DateTime.parse(j['startAt'] as String),
        endAt: DateTime.parse(j['endAt'] as String),
        requiresApproval: (j['requiresApproval'] ?? false) as bool,
        isPaid: (j['isPaid'] ?? false) as bool,
        isAddressHidden: (j['isAddressHidden'] ?? false) as bool,
        isAdultOnly: (j['isAdultOnly'] ?? false) as bool,
        price: (j['price'] as num?)?.toInt(),
        currency: j['currency'] as String?,
        coverUrl: j['coverUrl'] as String?,
        categoryId: j['categoryId'] as String?,
        status: (j['status'] ?? 'published') as String,
        capacity: (j['capacity'] as num?)?.toInt(),
        ownerId: j['ownerId'] as String?,
        participationStatus: (j['participationStatus'] as String?)?.toLowerCase(),
        owner: j['owner'] is Map<String, dynamic>
            ? EventOwner.fromJson(j['owner'] as Map<String, dynamic>)
            : null,
      );
}

class EventOwner {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  const EventOwner({
    required this.id,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  String get fullName {
    final parts = [firstName, lastName]
        .where((p) => p != null && p!.trim().isNotEmpty)
        .map((p) => p!.trim());
    return parts.join(' ');
  }

  factory EventOwner.fromJson(Map<String, dynamic> json) {
    return EventOwner(
      id: json['id'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
