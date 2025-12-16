import 'package:appwrite/appwrite.dart';
import '../config/appwrite_config.dart';
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
  Client get client => _client;
  Account get account => _account;
  Databases get databases => _databases;
  void reset() {
    _client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId)
        .setSelfSigned(status: true);
  }
}
