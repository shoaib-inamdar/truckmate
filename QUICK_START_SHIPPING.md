# Shipping Map Feature - Quick Start Guide

## 🚀 Quick Implementation Summary

A complete shipping tracking feature has been added to CargoBalancer. Sellers can start shipping and view live routes using Google Maps in WebView.

## 📁 Files Created/Modified

### New Files Created:
1. **`lib/pages/shipping_map_screen.dart`** - WebView map screen
2. **`lib/pages/seller_booking_detail_screen.dart`** - Seller booking details with Start Shipping button
3. **`lib/utils/maps_url_builder.dart`** - Google Maps URL builder utility
4. **`SHIPPING_MAP_SETUP.md`** - Complete documentation

### Modified Files:
1. **`pubspec.yaml`** - Added `webview_flutter: ^4.10.0`
2. **`lib/services/booking_service.dart`** - Added `startShipping()` method
3. **`lib/providers/booking_provider.dart`** - Added `startShipping()` provider method
4. **`lib/pages/seller_dashboard.dart`** - Updated to use new detail screen

## ⚡ Next Steps (Required Before Running)

### 1. Update Android Manifest

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <application
        ...
        android:usesCleartextTraffic="true"
        ...>
```

### 2. Update iOS Info.plist

Edit `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show your position on the delivery route map</string>

<key>io.flutter.embedded_views_preview</key>
<true/>
```

### 3. Rebuild

```bash
flutter clean
flutter pub get
flutter run
```

## 🎯 How It Works

### User Flow:

```
Customer creates booking (pending)
         ↓
Seller accepts (accepted)
         ↓
Customer submits payment (payment submitted)
         ↓
Seller clicks "Start Shipping" button
         ↓
✅ Appwrite updates: booking_status → in_transit
✅ Map screen opens automatically
✅ Google Maps shows route with live blue dot
         ↓
Seller can view map anytime during transit
         ↓
Seller completes delivery (delivered)
```

### Key Features:

✅ **WebView-based** - No Google Maps SDK or API key needed  
✅ **Live tracking** - Blue dot shows seller's real position (via Google Maps)  
✅ **No data storage** - App doesn't capture or store GPS coordinates  
✅ **Production-ready** - Clean architecture, error handling, loading states  
✅ **MVP-friendly** - Simple, scalable, no paid services  

## 🔧 Technical Details

### Booking Status Flow:

| Status | Description | Seller Action |
|--------|-------------|---------------|
| `pending` | New booking | Accept/Reject buttons shown |
| `accepted` | Seller accepted | "Start Shipping" button shown |
| `in_transit` | Shipping in progress | "View Map" button shown |
| `delivered` | Completed | No action needed |
| `rejected` | Seller rejected | No action needed |

### Appwrite Fields Updated:

When "Start Shipping" is clicked:
```javascript
{
  "booking_status": "in_transit",
  "journey_state": "shipping_done",
  "shipping_started_at": "2025-12-14T10:30:00.000Z"
}
```

### Map URL Format:

```
https://www.google.com/maps/dir/?api=1
  &origin=Mumbai,%20Maharashtra
  &destination=Pune,%20Maharashtra
  &travelmode=driving
```

## 📱 Testing Checklist

Before deploying:

- [ ] Android permissions added to manifest
- [ ] iOS location keys added to Info.plist
- [ ] Dependencies installed (`flutter pub get`)
- [ ] Test Accept/Reject buttons
- [ ] Test "Start Shipping" → Map opens
- [ ] Verify blue dot appears (location ON)
- [ ] Test "View Map" for in-transit bookings
- [ ] Check error handling (no internet)
- [ ] Verify Appwrite status updates correctly

## 🚨 Important Notes

### Permissions:
- **Location permissions** are for Google Maps' native blue dot only
- **App does NOT** read, process, or store GPS data
- **User must enable** location on their device for blue dot to work

### Limitations:
- Requires internet connection
- Uses Google Maps' default UI (no customization)
- No real-time location updates to backend
- View-only tracking (as requested)

### Production:
- Remove `android:usesCleartextTraffic="true"` before production release
- Test on real devices (emulators may not show accurate location)
- Consider adding user tutorial for first-time sellers

## 💡 Usage Examples

### For Seller Dashboard:

Seller clicks on a booking → Opens `SellerBookingDetailScreen`  
→ Shows booking info + action buttons based on status

### Programmatic Usage:

```dart
// Start shipping and open map
final booking = await bookingProvider.startShipping(bookingId: 'ABC123');
if (booking != null) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ShippingMapScreen(booking: booking),
    ),
  );
}
```

```dart
// Build custom map URL
final url = MapsUrlBuilder.buildDirectionUrl(
  origin: 'Delhi',
  destination: 'Jaipur',
);
```

## 📚 Full Documentation

For complete details, architecture, and advanced usage:  
**See `SHIPPING_MAP_SETUP.md`**

## ✅ What's Included

✓ WebView map screen with route display  
✓ URL builder utility (no API key needed)  
✓ Seller booking detail screen  
✓ Start Shipping button functionality  
✓ Appwrite integration (in_transit status)  
✓ Error handling & loading states  
✓ Permission documentation  
✓ Clean architecture & best practices  

## 🎉 Ready to Use!

After updating the manifest/plist files and running `flutter pub get`, the feature is production-ready for your MVP logistics app.

**No additional configuration needed!**
