/// A lightweight representation of a chat participant.
///
/// Intentionally generic — no courier/customer distinction.
/// The consuming layer decides who is "me" via [currentUserId].
class ChatUserModel {
  final int id;
  final String name;
  final String? avatarUrl;

  const ChatUserModel({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory ChatUserModel.fromJson(Map<String, dynamic> json) {
    return ChatUserModel(
      id: json['id'] as int,
      // Support multiple common field names from the backend.
      name: (json['name'] as String?)?.trim() ??
          (json['full_name'] as String?)?.trim() ??
          (json['username'] as String?)?.trim() ??
          'User',
      avatarUrl: json['avatar'] as String? ??
          json['profile_picture'] as String? ??
          json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatUserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ChatUserModel(id: $id, name: $name)';
}
