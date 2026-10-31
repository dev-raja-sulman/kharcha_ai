class UserModel {
  final int id;
  final String email;
  final String? fullName;
  final bool isActive;
  final String preferredCurrency;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    required this.isActive,
    this.preferredCurrency = 'PKR',
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      preferredCurrency: json['preferred_currency'] as String? ?? 'PKR',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'is_active': isActive,
      'preferred_currency': preferredCurrency,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get displayName => fullName?.trim().isNotEmpty == true ? fullName! : email.split('@').first;

  UserModel copyWith({
    int? id,
    String? email,
    String? fullName,
    bool? isActive,
    String? preferredCurrency,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      isActive: isActive ?? this.isActive,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
