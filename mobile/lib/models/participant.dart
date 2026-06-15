class Participant {
  const Participant({
    required this.id,
    required this.username,
    required this.joinedAt,
  });

  final String id;
  final String username;
  final int joinedAt;

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String,
      username: json['username'] as String,
      joinedAt: json['joinedAt'] as int,
    );
  }
}
