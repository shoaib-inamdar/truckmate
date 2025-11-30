class AppwriteConfig {
  // Replace these with your actual Appwrite credentials
  static const String endpoint = 'https://fra.cloud.appwrite.io/v1';
  static const String projectId =
      '6906328a0013f1b7e688'; // Replace with your project ID
  static const String databaseId =
      '6923e6b60037e27a8d19'; // Optional: if using database

  static const String appUrl =
      'https://your-app-url.com'; // Update for production

  // Collection IDs (if you create collections)
  static const String usersCollectionId = 'users';
  static const String bookingsCollectionId = 'user_data_collection';
    static const String sellerRequestsCollectionId = 'seller_request';
  static const String sellerDocumentsBucketId = '692bccf7001b0bafdecd';


  // API Configuration
  static const Duration timeout = Duration(seconds: 30);
}
