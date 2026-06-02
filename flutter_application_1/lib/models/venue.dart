class Venue {
  final int id;
  final String name;
  final String city;
  final int capacity;
  final String imageUrl;

  Venue({
    required this.id,
    required this.name,
    required this.city,
    required this.capacity,
    required this.imageUrl,
  });

  factory Venue.fromApi(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Stadium',
      city: json['city']?['name'] ?? 'City',
      capacity: json['capacity'] ?? 0,
      imageUrl: 'https://api.sofascore.app/api/v1/venue/${json['id']}/image',
    );
  }
}
