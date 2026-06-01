// Exemple de classe de donnees (Model), a adapter selon vos besoins.

class User {
  final int id;
  final String name;
  final String email;
  final String? profileImageUrl; // ? = peut être null

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
  });

  /// Convertir depuis JSON (si vous faites des appels API)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      profileImageUrl: json['profileImageUrl'],
    );
  }

  /// Convertir en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
    };
  }
}
