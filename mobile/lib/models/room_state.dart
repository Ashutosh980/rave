import 'participant.dart';
import 'playback_state.dart';
import 'chat_message.dart';
import 'live_stream_info.dart';

class RoomState {
  const RoomState({
    required this.roomId,
    required this.hostId,
    required this.hostUsername,
    required this.hasVideo,
    required this.videoUrl,
    required this.videoVersion,
    required this.participantCount,
    required this.isHost,
    required this.participants,
    required this.playbackState,
    required this.chatMessages,
    required this.createdAt,
    this.liveStream = const LiveStreamInfo(active: false),
  });

  final String roomId;
  final String hostId;
  final String hostUsername;
  final bool hasVideo;
  final String? videoUrl;
  final int videoVersion;
  final int participantCount;
  final bool isHost;
  final List<Participant> participants;
  final PlaybackState playbackState;
  final List<ChatMessage> chatMessages;
  final int createdAt;
  final LiveStreamInfo liveStream;

  factory RoomState.fromJson(Map<String, dynamic> json) {
    return RoomState(
      roomId: json['roomId'] as String,
      hostId: json['hostId'] as String,
      hostUsername: json['hostUsername'] as String,
      hasVideo: json['hasVideo'] as bool? ?? false,
      videoUrl: json['videoUrl'] as String?,
      videoVersion: json['videoVersion'] as int? ?? 0,
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
      liveStream: LiveStreamInfo.fromJson(
        json['liveStream'] as Map<String, dynamic>?,
      ),
    );
  }

  RoomState copyWith({
    String? hostId,
    String? hostUsername,
    bool? hasVideo,
    String? videoUrl,
    int? videoVersion,
    int? participantCount,
    bool? isHost,
    List<Participant>? participants,
    PlaybackState? playbackState,
    List<ChatMessage>? chatMessages,
    LiveStreamInfo? liveStream,
  }) {
    return RoomState(
      roomId: roomId,
      hostId: hostId ?? this.hostId,
      hostUsername: hostUsername ?? this.hostUsername,
      hasVideo: hasVideo ?? this.hasVideo,
      videoUrl: videoUrl ?? this.videoUrl,
      videoVersion: videoVersion ?? this.videoVersion,
      participantCount: participantCount ?? this.participantCount,
      isHost: isHost ?? this.isHost,
      participants: participants ?? this.participants,
      playbackState: playbackState ?? this.playbackState,
      chatMessages: chatMessages ?? this.chatMessages,
      createdAt: createdAt,
      liveStream: liveStream ?? this.liveStream,
    );
  }
}

class UploadVideoResponse {
  const UploadVideoResponse({
    required this.videoUrl,
    required this.videoVersion,
    required this.playbackState,
  });

  final String videoUrl;
  final int videoVersion;
  final PlaybackState playbackState;

  factory UploadVideoResponse.fromJson(Map<String, dynamic> json) {
    return UploadVideoResponse(
      videoUrl: json['videoUrl'] as String,
      videoVersion: json['videoVersion'] as int? ?? 0,
      playbackState: PlaybackState.fromJson(
        json['playbackState'] as Map<String, dynamic>? ?? {},
      ),
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
