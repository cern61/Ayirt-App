enum UserRole {
  customer,
  business,
  admin;

  static UserRole fromString(String? value) =>
      UserRole.values.firstWhere((r) => r.name == value, orElse: () => UserRole.customer);

  /// Her rolün ana sayfası (router bunu kullanır)
  String get homePath => switch (this) {
        UserRole.customer => '/customer',
        UserRole.business => '/business',
        UserRole.admin => '/admin',
      };
}

class Profile {
  final String id;
  final UserRole role;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;

  const Profile({
    required this.id,
    required this.role,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        role: UserRole.fromString(map['role'] as String?),
        fullName: (map['full_name'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        phone: map['phone'] as String?,
        avatarUrl: map['avatar_url'] as String?,
      );
}
