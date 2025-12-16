# Shipping Map Feature - Setup & Documentation

## Overview
This feature allows transporters (sellers) to start shipping and view live route tracking using Google Maps Directions in a WebView. No GPS data is captured or stored by the app - this is view-only tracking that relies on Google Maps' native blue dot for live location.

## Architecture

### Components Created

1. **ShippingMapScreen** (`lib/pages/shipping_map_screen.dart`)
   - Displays Google Maps directions in WebView
   - Shows route from source to destination
   - View-only tracking - no GPS data stored
   - Clean UI with route info banner and instructions

2. **MapsUrlBuilder** (`lib/utils/maps_url_builder.dart`)
   - Utility class for building Google Maps direction URLs
   - No API key required - uses public Google Maps web interface
   - URL format: `https://www.google.com/maps/dir/?api=1&origin={SOURCE}&destination={DESTINATION}&travelmode=driving`
   - Handles URL encoding and validation

3. **SellerBookingDetailScreen** (`lib/pages/seller_booking_detail_screen.dart`)
   - Complete seller booking detail view
   - Accept/Reject buttons for pending bookings
   - "Start Shipping" button for accepted bookings
   - Automatic map screen launch when shipping starts
   - "View Map" button for in-transit bookings

4. **Backend Integration**
   - `BookingService.startShipping()` - Updates booking status to `in_transit`
   - `BookingProvider.startShipping()` - Provider wrapper for UI
   - Sets `booking_status` to `in_transit` and `journey_state` to `shipping_done` in Appwrite

## User Flow

1. Customer creates a booking → Status: `pending`
2. Seller accepts booking → Status: `accepted`
3. Customer submits payment → Payment status: `submitted`
4. Seller clicks "Start Shipping" button:
   - Booking status updates to `in_transit` in Appwrite
   - Journey state updates to `shipping_done`
   - Map screen opens automatically
   - Google Maps shows route with live blue dot
5. Seller can return to view map anytime during transit
6. Seller completes delivery → Status: `delivered`/`completed`

## Permissions Required

### Android (`android/app/src/main/AndroidManifest.xml`)

Add these permissions and features:

```xml
<manifest ...>
    <!-- Internet permission for WebView -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- Location permissions for Google Maps blue dot (managed by Google Maps web) -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- Location hardware feature (optional) -->
    <uses-feature android:name="android.hardware.location.gps" android:required="false" />

    <application
        ...
        <!-- Allow cleartext traffic for local development (remove in production) -->
        android:usesCleartextTraffic="true"
        ...>
        ...
    </application>
</manifest>
```

**Important Android Notes:**
- WebView requires `INTERNET` permission
- Location permissions are for Google Maps' native blue dot feature
- The app itself does NOT request or process location data
- User must have location enabled on their device for the blue dot to appear
- `usesCleartextTraffic` should be removed in production builds

### iOS (`ios/Runner/Info.plist`)

Add these keys:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show your position on the delivery route map</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>CargoBalancer needs location access to track shipments on the map</string>

<key>io.flutter.embedded_views_preview</key>
<true/>
```

**Important iOS Notes:**
- `io.flutter.embedded_views_preview` enables platform views (required for WebView)
- Location permissions are for Google Maps' native feature only
- App does not programmatically access location data
- User will see iOS permission prompt when first opening map

## Installation Steps

### 1. Install Dependencies

The `webview_flutter` dependency has been added to `pubspec.yaml`:

```bash
flutter pub get
```

### 2. Update Android Manifest

Edit `android/app/src/main/AndroidManifest.xml` and add the permissions listed above.

### 3. Update iOS Info.plist

Edit `ios/Runner/Info.plist` and add the keys listed above.

### 4. Build and Test

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run on Android
flutter run

# Run on iOS
flutter run
```

## Usage in Code

### Open Map Screen Directly

```dart
import 'package:truckmate/pages/shipping_map_screen.dart';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ShippingMapScreen(booking: yourBookingObject),
  ),
);
```

### Start Shipping Flow

```dart
import 'package:provider/provider.dart';
import 'package:truckmate/providers/booking_provider.dart';

final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
final updatedBooking = await bookingProvider.startShipping(
  bookingId: booking.id,
);

if (updatedBooking != null) {
  // Success - open map screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ShippingMapScreen(booking: updatedBooking),
    ),
  );
}
```

### Build Custom Map URL

```dart
import 'package:truckmate/utils/maps_url_builder.dart';

final url = MapsUrlBuilder.buildDirectionUrl(
  origin: 'Mumbai, Maharashtra',
  destination: 'Pune, Maharashtra',
  travelMode: 'driving',
);
// Returns: https://www.google.com/maps/dir/?api=1&origin=...
```

## Database Schema

### Required Appwrite Fields

Ensure your `bookings` collection has these fields:

```
- booking_status (string)      // 'pending', 'accepted', 'in_transit', 'delivered'
- journey_state (string)       // 'payment_done', 'transporter_assigned', 'shipping_done', 'journey_completed'
- shipping_started_at (string) // ISO 8601 timestamp when shipping starts
```

## Limitations & Constraints

### ✅ What This Solution Provides

- **In-app map viewing** using WebView
- **Google Maps directions** from source to destination
- **Live blue dot tracking** via Google Maps native feature
- **No API key required** - uses public Google Maps URL
- **No GPS data stored** - completely view-only
- **Clean UI** with route information and status
- **Production-ready** MVP solution

### ⚠️ Limitations

- **No custom markers** (uses Google Maps defaults)
- **No ETA calculation** (Google Maps shows estimated time)
- **No route customization** (uses Google's optimal route)
- **Internet required** to load maps
- **Blue dot requires user's location** to be enabled on device
- **No offline maps** capability

### 🚫 Does NOT Include

- GPS coordinate extraction
- Location data storage
- Custom map styling
- Real-time location updates to backend
- Geofencing or route deviation alerts
- Turn-by-turn navigation prompts

## UX Considerations

### Good UX Patterns

1. **Pre-shipping checklist:**
   - Remind seller to enable location
   - Confirm source/destination are correct
   - Verify internet connectivity

2. **During shipping:**
   - Keep device location ON for blue dot
   - Keep internet connection active
   - Map can be reopened anytime from booking details

3. **Instructions to sellers:**
   - "Keep location enabled on your device"
   - "Your blue dot shows your current position"
   - "No tracking data is stored by the app"

### Error Handling

The `ShippingMapScreen` includes:
- Loading states while map loads
- Error handling for failed map loads
- Retry functionality
- Clear error messages

### Performance Notes

- WebView loads Google Maps web version (lighter than SDK)
- First load may take 2-3 seconds depending on network
- Subsequent loads are faster
- Minimal battery impact compared to native GPS tracking

## Testing Checklist

- [ ] Android: Permissions added to manifest
- [ ] iOS: Info.plist keys added
- [ ] Dependencies installed (`flutter pub get`)
- [ ] Build succeeds on both platforms
- [ ] Map loads correctly with sample booking data
- [ ] Blue dot appears when location is enabled
- [ ] "Start Shipping" button updates Appwrite correctly
- [ ] Map shows correct route from source to destination
- [ ] Error handling works when internet is disconnected
- [ ] UI is responsive and intuitive

## Production Deployment

Before deploying to production:

1. **Remove development flags:**
   - Remove `android:usesCleartextTraffic="true"` from Android manifest

2. **Optimize WebView:**
   - Consider adding caching headers
   - Test on various network speeds
   - Ensure HTTPS for all resources

3. **User education:**
   - Add tutorial/onboarding for first-time users
   - Explain location permission requirement
   - Clarify that tracking is view-only

4. **Monitor:**
   - Track map load success rate
   - Monitor user feedback on blue dot accuracy
   - Watch for WebView-related crashes

## Future Enhancements

If you want to add more features later:

1. **Google Maps SDK** (requires API key):
   - Custom markers and polylines
   - Real-time location updates to backend
   - ETA calculations
   - Route optimization

2. **Offline capabilities:**
   - Download maps for offline use
   - Cache routes

3. **Advanced tracking:**
   - Store GPS breadcrumbs
   - Show delivery history path
   - Customer-side live tracking

4. **Analytics:**
   - Track delivery times
   - Analyze route efficiency
   - Monitor fuel/distance metrics

## Support

For issues or questions:

1. Check WebView console logs: Enable debugging in WebViewController
2. Verify booking data has valid source/destination
3. Test URL directly in browser to confirm Google Maps format
4. Ensure device has internet and location enabled

## License & Attribution

- Google Maps is a trademark of Google LLC
- This implementation uses Google Maps' public web interface
- No Google Maps API key or SDK required
- Complies with Google Maps Terms of Service for public web usage
