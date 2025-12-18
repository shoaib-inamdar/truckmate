import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/booking_model.dart';
import '../utils/maps_url_builder.dart';

/// Shipping Map Screen
///
/// Displays Google Maps directions in WebView for live tracking during shipping.
/// The transporter's device location (blue dot) is shown by Google Maps natively.
/// No GPS data is captured or stored by the app - this is view-only tracking.
class ShippingMapScreen extends StatefulWidget {
  final BookingModel booking;

  const ShippingMapScreen({Key? key, required this.booking}) : super(key: key);

  @override
  State<ShippingMapScreen> createState() => _ShippingMapScreenState();
}

class _ShippingMapScreenState extends State<ShippingMapScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      // Validate booking locations
      final startLoc = widget.booking.startLocation.trim();
      final destLoc = widget.booking.destination.trim();

      print('DEBUG: Building map URL');
      print('DEBUG: Start location: "$startLoc"');
      print('DEBUG: Destination: "$destLoc"');

      if (startLoc.isEmpty || destLoc.isEmpty) {
        throw 'Invalid booking locations: Start location and destination cannot be empty';
      }

      // Build the Google Maps direction URL from booking data
      final mapUrl = MapsUrlBuilder.buildDirectionUrl(
        origin: startLoc,
        destination: destLoc,
        travelMode: 'driving',
      );

      print('DEBUG: Generated map URL: $mapUrl');

      // Initialize WebView controller
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) {
              // Block navigation to app intents (intent://, market://, etc.)
              // This prevents the WebView from trying to open the Google Maps app
              if (request.url.startsWith('intent://') ||
                  request.url.startsWith('market://') ||
                  request.url.startsWith('android-app://')) {
                print('DEBUG: Blocked navigation to: ${request.url}');
                return NavigationDecision.prevent;
              }
              print('DEBUG: Allowing navigation to: ${request.url}');
              return NavigationDecision.navigate;
            },
            onPageStarted: (String url) {
              print('DEBUG: WebView loading: $url');
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            },
            onPageFinished: (String url) {
              print('DEBUG: WebView finished loading: $url');
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              print('DEBUG: WebView error: ${error.description}');
              print('DEBUG: Error type: ${error.errorType}');
              setState(() {
                _isLoading = false;
                _errorMessage = 'Failed to load map: ${error.description}';
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(mapUrl));
    } catch (e) {
      print('DEBUG: Exception in _initializeWebView: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initializing map: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Tracking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              'Booking ID: ${widget.booking.bookingId}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: AppColors.dark,
        foregroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: Column(
        children: [
          // Route info banner
          _buildRouteInfoBanner(),

          // Open in Google Maps button
          _buildOpenInMapsButton(),

          // Map WebView
          Expanded(child: _buildMapContent()),

          // Instructions footer
          _buildInstructionsFooter(),
        ],
      ),
    );
  }

  Widget _buildRouteInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, color: AppColors.dark, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.my_location,
                      color: AppColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.booking.startLocation,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.danger,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.booking.destination,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenInMapsButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.secondary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: _openInGoogleMaps,
        icon: const Icon(Icons.map, size: 20),
        label: const Text(
          'Open in Google Maps App',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.dark,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _openInGoogleMaps() async {
    try {
      final startLoc = Uri.encodeComponent(widget.booking.startLocation.trim());
      final destLoc = Uri.encodeComponent(widget.booking.destination.trim());

      // Build Google Maps app URL for directions
      final googleMapsUrl =
          'google.navigation:q=$destLoc&origin=$startLoc&mode=d';
      final fallbackUrl =
          'https://www.google.com/maps/dir/?api=1&origin=$startLoc&destination=$destLoc&travelmode=driving';

      // Try to launch Google Maps app first
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
        // Fallback to web version
        await launchUrl(
          Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not open Google Maps';
      }
    } catch (e) {
      print('Error opening Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Google Maps: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Widget _buildMapContent() {
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (_isLoading)
          Container(
            color: AppColors.white,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading map...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
                _initializeWebView();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.dark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Keep location ON for live tracking',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your blue dot on the map shows your live location. This is view-only - no data is stored.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
