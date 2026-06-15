import 'participant.dart';
import 'playback_state.dart';
import 'chat_message.dart';

class RoomState {
  const RoomState({
    required this.roomId,
    required this.hostId,
    required this.hostUsername,
    required this.hasVideo,
    required this.videoUrl,
    required this.participantCount,
    required this.isHost,
    required this.participants,
    required this.playbackState,
    required this.chatMessages,
    required this.createdAt,
  });

  final String roomId;
  final String hostId;
  final String hostUsername;
  final bool hasVideo;
  final String? videoUrl;
  final int participantCount;
  final bool isHost;
  final List<Participant> participants;
  final PlaybackState playbackState;
  final List<ChatMessage> chatMessages;
  final int createdAt;

  factory RoomState.fromJson(Map<String, dynamic> json) {
    return RoomState(
      roomId: json['roomId'] as String,
      hostId: json['hostId'] as String,
      hostUsername: json['hostUsername'] as String,
      hasVideo: json['hasVideo'] as bool? ?? false,
      videoUrl: json['videoUrl'] as String?,
      participantCount: json['participantCount'] as int? ?? 0,
      isHost: json['isHost'] as bool? ?? false,
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map((e) => Participant.fromJson(e as Map<String, dynamic>))
          .toList(),
      playbackState: PlaybackState.fromJson(
        json['playbackState'] as Map<String, dynamic>? ?? {},
      ),
      chatMessages: (json['chatMessages'] as List<dynamic>? ?? [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] as int? ?? 0,
    );
  }

  RoomState copyWith({
    bool? hasVideo,
    String? videoUrl,
    int? participantCount,
    List<Participant>? participants,
    PlaybackState? playbackState,
    List<ChatMessage>? chatMessages,
  }) {
    return RoomState(
      roomId: roomId,
      hostId: hostId,
      hostUsername: hostUsername,
      hasVideo: hasVideo ?? this.hasVideo,
      videoUrl: videoUrl ?? this.videoUrl,
      participantCount: participantCount ?? this.participantCount,
      isHost: isHost,
      participants: participants ?? this.participants,
      playbackState: playbackState ?? this.playbackState,
      chatMessages: chatMessages ?? this.chatMessages,
      createdAt: createdAt,
    );
  }
}

class CreateRoomResponse {
  const CreateRoomResponse({
    required this.roomId,
    required this.hostId,
    required this.hostUsername,
    required this.createdAt,
  });

  final String roomId;
  final String hostId;
  final String hostUsername;
  final int createdAt;

  factory CreateRoomResponse.fromJson(Map<String, dynamic> json) {
    return CreateRoomResponse(
      roomId: json['roomId'] as String,
      hostId: json['hostId'] as String,
      hostUsername: json['hostUsername'] as String,
      createdAt: json['createdAt'] as int,
    );
  }
}
