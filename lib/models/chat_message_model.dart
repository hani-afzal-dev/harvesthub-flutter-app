import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatRole { user, assistant }

class ChatMessageModel {
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  ChatMessageModel({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      role: map['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role == ChatRole.user ? 'user' : 'assistant',
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
