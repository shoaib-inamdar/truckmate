/// Utility class for building Google Maps direction URLs
/// No API key required - uses public Google Maps web interface
class MapsUrlBuilder {
  /// Builds a Google Maps direction URL from source to destination
  ///
  /// Parameters:
  /// - [origin]: Starting point (city name, address, or "lat,lng")
  /// - [destination]: End point (city name, address, or "lat,lng")
  /// - [travelMode]: Optional travel mode (driving, walking, bicycling, transit)
  ///
  /// Returns a URL string that can be loaded in WebView
  ///
  /// Example usage:
  /// ```dart
  /// final url = MapsUrlBuilder.buildDirectionUrl(
  ///   origin: 'Mumbai, Maharashtra',
  ///   destination: 'Pune, Maharashtra',
  /// );
  /// ```
  static String buildDirectionUrl({
    required String origin,
    required String destination,
    String travelMode = 'driving',
  }) {
    // Validate inputs
    if (origin.trim().isEmpty || destination.trim().isEmpty) {
      throw ArgumentError('Origin and destination cannot be empty');
    }

    // URL encode the parameters to handle special characters and spaces
    final encodedOrigin = Uri.encodeComponent(origin.trim());
    final encodedDestination = Uri.encodeComponent(destination.trim());
    final encodedTravelMode = Uri.encodeComponent(travelMode.toLowerCase());

    // Build the Google Maps Directions URL
    // Using api=1 format for embedding/webview compatibility
    final url =
        'https://www.google.com/maps/dir/?api=1'
        '&origin=$encodedOrigin'
        '&destination=$encodedDestination'
        '&travelmode=$encodedTravelMode';

    return url;
  }

  /// Validates if a location string is properly formatted
  /// Returns true if valid, false otherwise
  static bool isValidLocation(String location) {
    if (location.trim().isEmpty) return false;

    // Check if it's a lat,lng format
    final latLngPattern = RegExp(r'^-?\d+\.?\d*,-?\d+\.?\d*$');
    if (latLngPattern.hasMatch(location.trim())) {
      return true;
    }

    // Otherwise assume it's a place name/address (allow alphanumeric and common punctuation)
    return location.trim().length >= 3;
  }

  /// Extracts city/location name from full address or returns as-is
  /// This is a simple helper - you can enhance it based on your data format
  static String extractLocationForMap(String fullAddress) {
    // If it's already a simple city name or lat,lng, return as-is
    if (fullAddress.split(',').length <= 2) {
      return fullAddress.trim();
    }

    // For complex addresses, try to extract city (usually second-to-last component)
    final parts = fullAddress.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}, ${parts[parts.length - 1]}';
    }

    return fullAddress.trim();
  }
}
