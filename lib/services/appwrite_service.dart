import 'package:appwrite/appwrite.dart';
import '../config/appwrite_config.dart';

/// Singleton service to manage Appwrite client across the app
/// This ensures all services use the same authenticated client instance
class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();
  
  late final Client _client;
  late final Account _account;
  late final Databases _databases;

  factory AppwriteService() {
    return _instance;
  }

  AppwriteService._internal() {
    _client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId)
        .setSelfSigned(status: true); // Only for development
    
    _account = Account(_client);
    _databases = Databases(_client);
  }

  // Getters for services
  Client get client => _client;
  Account get account => _account;
  Databases get databases => _databases;

  // Reset client (useful for logout)
  void reset() {
    _client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId)
        .setSelfSigned(status: true);
    
    // Reinitialize services with new client
    // Note: This is not strictly necessary as the client maintains session
    // but can be useful for certain edge cases
  }
}