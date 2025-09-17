class Event {
  final String id;
  final String title;
  final String description;
  final String address;     // <—
  final String city;
  final double lat;
  final double lon;
  final DateTime startAt;
  final DateTime endAt;
  final bool requiresApproval;
  final bool isPaid;
  final int? price;
  final String? currency;
  final String? coverUrl;   // <—

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.address,
    required this.city,
    required this.lat,
    required this.lon,
    required this.startAt,
    required this.endAt,
    required this.requiresApproval,
    required this.isPaid,
    this.price,
    this.currency,
    this.coverUrl,
  });

  factory Event.fromJson(Map<String, dynamic> j) => Event(
    id: j['id'],
    title: j['title'] ?? '',
    description: j['description'] ?? '',
    address: j['address'] ?? '',
    city: j['city'] ?? '',
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
    startAt: DateTime.parse(j['startAt']),
    endAt: DateTime.parse(j['endAt']),
    requiresApproval: (j['requiresApproval'] ?? false) as bool,
    isPaid: (j['isPaid'] ?? false) as bool,
    price: (j['price'] as num?)?.toInt(),
    currency: j['currency'] as String?,
    coverUrl: j['coverUrl'] as String?,
  );
}
