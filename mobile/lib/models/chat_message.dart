class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.username,
    required this.content,
    required this.timestamp,
  });

  final String id;
  final String username;
  final String content;
  final int timestamp;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      username: json['username'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] as int,
    );
  }
}
