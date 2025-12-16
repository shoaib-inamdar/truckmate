import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';

enum ChatStatus { initial, loading, success, error }

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();

  ChatStatus _status = ChatStatus.initial;
  List<ChatMessage> _messages = [];
  List<String> _activeChats = [];
  String? _errorMessage;

  ChatStatus get status => _status;
  List<ChatMessage> get messages => _messages;
  List<String> get activeChats => _activeChats;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ChatStatus.loading;

  // Send a message
  Future<bool> sendMessage({
    required String bookingId,
    required String senderId,
    required String senderType,
    required String message,
  }) async {
    try {
      _errorMessage = null;

      final newMessage = await _chatService.sendMessage(
        bookingId: bookingId,
        senderId: senderId,
        senderType: senderType,
        message: message,
      );

      _messages.add(newMessage);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Load messages for a booking
  Future<void> loadMessages(String bookingId) async {
    try {
      _status = ChatStatus.loading;
      _errorMessage = null;
      notifyListeners();

      _messages = await _chatService.getMessages(bookingId);

      _status = ChatStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ChatStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Load active chats (for admin)
  Future<void> loadActiveChats() async {
    try {
      _status = ChatStatus.loading;
      _errorMessage = null;
      notifyListeners();

      _activeChats = await _chatService.getActiveChats();

      _status = ChatStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ChatStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String bookingId, String userId) async {
    try {
      await _chatService.markMessagesAsRead(bookingId, userId);
      
      // Update local messages
      for (var i = 0; i < _messages.length; i++) {
        if (_messages[i].senderId != userId) {
          _messages[i] = _messages[i].copyWith(isRead: true);
        }
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Delete chat (admin only)
  Future<bool> deleteChat(String bookingId) async {
    try {
      _status = ChatStatus.loading;
      _errorMessage = null;
      notifyListeners();

      await _chatService.deleteChat(bookingId);

      _messages.clear();
      _activeChats.remove(bookingId);

      _status = ChatStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = ChatStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Clear messages
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Reset
  void reset() {
    _status = ChatStatus.initial;
    _messages = [];
    _activeChats = [];
    _errorMessage = null;
    notifyListeners();
  }
}