import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/appwrite_config.dart';
import '../models/chat_message_model.dart';
import '../services/appwrite_service.dart';

class ChatService {
  final _appwriteService = AppwriteService();

  late final Databases _databases;
  late final Realtime _realtime;

  ChatService() {
    _databases = _appwriteService.databases;
    _realtime = Realtime(_appwriteService.client);
  }

  // Send a message
  Future<ChatMessage> sendMessage({
    required String bookingId,
    required String senderId,
    required String senderType,
    required String message,
  }) async {
    try {
      print('Sending message for booking: $bookingId');

      final data = {
        'booking_id': bookingId,
        'sender_id': senderId,
        'sender_type': senderType,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': false,
      };

      final doc = await _databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatMessagesCollectionId,
        documentId: ID.unique(),
        data: data,
        permissions: [
          Permission.read(Role.any()),
          Permission.update(Role.any()),
          Permission.delete(Role.any()),
        ],
      );

      print('Message sent successfully: ${doc.$id}');
      return _documentToChatMessage(doc);
    } on AppwriteException catch (e) {
      print(
        'Appwrite error in sendMessage: Code ${e.code}, Message: ${e.message}',
      );
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in sendMessage: ${e.toString()}');
      throw 'Failed to send message: ${e.toString()}';
    }
  }

  // Get messages for a booking
  Future<List<ChatMessage>> getMessages(String bookingId) async {
    try {
      print('Getting messages for booking: $bookingId');

      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatMessagesCollectionId,
        queries: [
          Query.equal('booking_id', bookingId),
          Query.orderAsc('timestamp'),
        ],
      );

      print('Found ${result.documents.length} messages');

      return result.documents
          .map((doc) => _documentToChatMessage(doc))
          .toList();
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to get messages: ${e.toString()}';
    }
  }

  // Get all active chats (for admin)
  Future<List<String>> getActiveChats() async {
    try {
      print('Getting all active chats...');

      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatMessagesCollectionId,
        queries: [Query.orderDesc('timestamp'), Query.limit(100)],
      );

      // Get unique booking IDs
      final Set<String> bookingIds = {};
      for (var doc in result.documents) {
        bookingIds.add(doc.data['booking_id'] ?? '');
      }

      print('Found ${bookingIds.length} active chats');
      return bookingIds.toList();
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to get active chats: ${e.toString()}';
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String bookingId, String userId) async {
    try {
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatMessagesCollectionId,
        queries: [
          Query.equal('booking_id', bookingId),
          Query.notEqual('sender_id', userId),
        ],
      );

      for (var doc in result.documents) {
        // Only update if not already read
        final isRead = doc.data['is_read'];
        if (isRead == false || isRead == 'false') {
          await _databases.updateDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.chatMessagesCollectionId,
            documentId: doc.$id,
            data: {'is_read': true},
          );
        }
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Delete all messages for a booking (admin only)
  Future<void> deleteChat(String bookingId) async {
    try {
      print('Deleting chat for booking: $bookingId');

      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatMessagesCollectionId,
        queries: [Query.equal('booking_id', bookingId)],
      );

      for (var doc in result.documents) {
        await _databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.chatMessagesCollectionId,
          documentId: doc.$id,
        );
      }

      print('Chat deleted successfully');
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to delete chat: ${e.toString()}';
    }
  }

  // Subscribe to messages (realtime)
  RealtimeSubscription subscribeToMessages(
    String bookingId,
    Function(ChatMessage) onMessage,
  ) {
    final subscription = _realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.chatMessagesCollectionId}.documents',
    ]);

    subscription.stream.listen((response) {
      if (response.events.contains(
        'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.chatMessagesCollectionId}.documents.*.create',
      )) {
        final message = ChatMessage.fromJson(response.payload);
        if (message.bookingId == bookingId) {
          onMessage(message);
        }
      }
    });

    return subscription;
  }

  // Convert Appwrite document to ChatMessage
  ChatMessage _documentToChatMessage(models.Document doc) {
    final isReadValue = doc.data['is_read'];
    bool isRead = false;

    if (isReadValue is bool) {
      isRead = isReadValue;
    } else if (isReadValue is String) {
      isRead = isReadValue.toLowerCase() == 'true';
    }

    return ChatMessage(
      id: doc.$id,
      bookingId: doc.data['booking_id'] ?? '',
      senderId: doc.data['sender_id'] ?? '',
      senderType: doc.data['sender_type'] ?? '',
      message: doc.data['message'] ?? '',
      timestamp: DateTime.parse(
        doc.data['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      isRead: isRead,
    );
  }

  // Handle Appwrite exceptions
  String _handleAppwriteException(AppwriteException e) {
    switch (e.code) {
      case 401:
        return 'Unauthorized. Please login again.';
      case 404:
        return 'Chat not found.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
