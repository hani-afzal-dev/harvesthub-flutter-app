import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/ai_fallback_kb.dart';
import '../core/app_logger.dart';
import '../core/constants.dart';
import '../models/chat_message_model.dart';

class AiSendResult {
  final String answer;
  final bool isFallback;

  AiSendResult({required this.answer, required this.isFallback});
}

class AiAssistantService {
  static const int _maxMessagesPerSession = 50;
  static const Duration _requestTimeout = Duration(seconds: 15);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _relayUrl => dotenv.env['PUSH_RELAY_URL'] ?? '';

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection(FirestoreCollections.aiChatSessions);

  Query<Map<String, dynamic>> _latestSessionQuery(String uid) {
    return _sessions
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1);
  }

  Stream<List<ChatMessageModel>> watchSession() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _latestSessionQuery(uid).snapshots().map((snap) {
      if (snap.docs.isEmpty) return <ChatMessageModel>[];
      final data = snap.docs.first.data();
      final raw = List<Map<String, dynamic>>.from(data['messages'] ?? []);
      return raw.map(ChatMessageModel.fromMap).toList();
    });
  }

  Future<void> clearSession() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final latest = await _latestSession(uid);
    if (latest.docs.isEmpty) return;
    await latest.docs.first.reference
        .update({'messages': <Map<String, dynamic>>[]});
  }

  Future<AiSendResult> sendMessage(String userQuery) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return AiSendResult(answer: aiFallbackDefaultAnswer, isFallback: true);
    }

    final userMessage = ChatMessageModel(
        role: ChatRole.user, content: userQuery, timestamp: DateTime.now());
    final savingUserMessage = _saveUserMessage(uid, userMessage.toMap());
    savingUserMessage.ignore();

    String answer;
    bool isFallback;
    try {
      answer = await _callGemini(userQuery);
      isFallback = false;
    } catch (e) {
      AppLogger.info('Gemini unavailable: ${e.runtimeType}');
      answer = matchAiFallbackAnswer(userQuery);
      isFallback = true;
    }

    final sessionRef = await savingUserMessage;
    final assistantMessage = ChatMessageModel(
      role: ChatRole.assistant,
      content: answer,
      timestamp: DateTime.now(),
    );
    await sessionRef.update({
      'messages': FieldValue.arrayUnion([assistantMessage.toMap()])
    });

    return AiSendResult(answer: answer, isFallback: isFallback);
  }

  Future<DocumentReference<Map<String, dynamic>>> _saveUserMessage(
      String uid, Map<String, dynamic> message) async {
    final latest = await _latestSession(uid);
    if (latest.docs.isNotEmpty) {
      final doc = latest.docs.first;
      final existing =
          List<Map<String, dynamic>>.from(doc.data()['messages'] ?? []);
      if (existing.length + 2 <= _maxMessagesPerSession) {
        await doc.reference.update({
          'messages': FieldValue.arrayUnion([message])
        });
        return doc.reference;
      }
    }

    final newSession = _sessions.doc();
    await newSession.set({
      'userId': uid,
      'messages': [message],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return newSession;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _latestSession(String uid) async {
    try {
      final cached = await _latestSessionQuery(uid)
          .get(const GetOptions(source: Source.cache));
      if (cached.docs.isNotEmpty) return cached;
    } on FirebaseException {
      AppLogger.info('Chat session not cached yet');
    }
    return _latestSessionQuery(uid).get();
  }

  Future<String> _callGemini(String query) async {
    final user = FirebaseAuth.instance.currentUser;
    if (_relayUrl.isEmpty || user == null) {
      throw Exception('Assistant relay not configured');
    }
    final token = await user.getIdToken();
    final response = await http
        .post(
          Uri.parse('$_relayUrl/chat'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'question': query}),
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Assistant relay error ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    final answer = body is Map ? body['answer'] : null;
    if (answer is! String || answer.trim().isEmpty) {
      throw Exception('Empty assistant answer');
    }
    return answer.trim();
  }
}