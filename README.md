# TruckMate

Mobile application for transporters and customers to manage logistics and cargo transportation. TruckMate connects customers who need cargo transportation with available transporters, providing a seamless booking and tracking experience.

## Features

### For Transporters (Sellers)

- **Registration & Onboarding**
  - Individual transporter registration
  - Business company registration
  - Document upload (PAN, GST, Driving License, Transport License)
  - Vehicle registration with RC book and images
  - Shop photo upload (optional)
  - GST registration (optional for businesses)

- **Profile Management**
  - Update availability status
  - Set return location for return trips
  - Manage vehicle inventory
  - Add new vehicles (pending admin approval)
  - View and update profile information

- **Booking Management**
  - View incoming booking requests
  - Accept or reject bookings
  - Track active bookings
  - Update journey status (started, in progress, completed)
  - View booking history

- **Payment Tracking**
  - Submit payment proof
  - Track payment status
  - View payment history

### For Customers (Buyers)

- **Booking System**
  - Create new booking requests
  - Specify pickup and delivery locations
  - Select vehicle type and load details
  - View available transporters
  - Track booking status

- **Transporter Discovery**
  - Search for available transporters
  - Filter by vehicle type and location
  - View transporter profiles and ratings

- **Booking Tracking**
  - Real-time booking status updates
  - Journey tracking
  - Payment status monitoring

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Backend**: Appwrite (BaaS)
  - Authentication (including anonymous sessions)
  - Database (Collections)
  - Storage (Document and image uploads)
- **Additional Packages**:
  - `file_picker`: Document selection
  - `flutter_phone_direct_caller`: Direct calling functionality
  - `shared_preferences`: Local data persistence

## Project Structure

```
lib/
├── components/       # Reusable UI components
├── config/           # Appwrite and app configuration
├── constants/        # App-wide constants (colors, strings)
├── main.dart         # App entry point
├── models/           # Data models
├── pages/            # Screen/page widgets
├── providers/        # State management providers
├── services/         # API and business logic services
├── utils/            # Utility functions and helpers
└── widgets/          # Reusable widget components
```

## Setup Instructions

### Prerequisites

- Flutter SDK (3.0+)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Appwrite server instance

### Installation

1. **Clone the repository**
   ```bash
   cd truckmate
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Appwrite**
   - Update `lib/config/appwrite_config.dart` with your Appwrite credentials:
     - Project ID
     - Endpoint URL
     - Database ID
     - Collection IDs
     - Bucket ID

4. **Run the app**
   ```bash
   flutter run
   ```

## Configuration

Update the following in `lib/config/appwrite_config.dart`:

```dart
static const String projectId = 'YOUR_PROJECT_ID';
static const String endpoint = 'YOUR_APPWRITE_ENDPOINT';
static const String databaseId = 'YOUR_DATABASE_ID';
static const String sellerRequestsCollectionId = 'YOUR_COLLECTION_ID';
static const String bucketId = 'YOUR_BUCKET_ID';
// ... other configuration
```

## User Flows

### Transporter Registration Flow

1. Choose registration type (Individual/Business)
2. Fill in personal/business details
3. Upload required documents
4. Upload shop photo (optional)
5. Register vehicles (for individuals)
6. Submit for admin approval
7. Wait for approval notification
8. Login with generated credentials

### Booking Flow (Customer)

1. Login/Register as buyer
2. Create new booking request
3. Specify pickup/delivery details
4. Select vehicle type and load
5. Submit booking
6. Wait for transporter acceptance
7. Track journey progress
8. Confirm delivery and payment

### Booking Flow (Transporter)

1. Login as approved transporter
2. View incoming booking requests
3. Review booking details
4. Accept or reject booking
5. Start journey and update status
6. Complete delivery
7. Submit payment proof
8. Receive payment confirmation

## Key Screens

### Transporter Screens
- Registration screens (Individual/Business)
- Seller waiting confirmation
- Seller home screen
- My vehicles screen
- Booking requests list
- Booking detail screen
- Add vehicle screen
- Profile screen

### Customer Screens
- Buyer home screen
- Create booking screen
- My bookings screen
- Booking tracking screen
- Transporter search screen

## Database Collections

- `seller_requests`: Transporter registration requests (pending approval)
- `sellers`: Approved transporters
- `users`: User accounts (buyers and sellers)
- `bookings`: Booking requests and active bookings
- `vehicle_requests`: Vehicle addition requests

## Document Upload

Supported document types:
- PDF files
- Images (JPG, JPEG, PNG)
- Maximum file size: 1MB

Documents are stored in Appwrite Storage and linked via document IDs in the database.

## Building for Production

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## Features in Development

- Real-time location tracking
- In-app messaging between customers and transporters
- Rating and review system
- Advanced search and filtering
- Push notifications

## Contributing

This is a private project. For any issues or feature requests, please contact the development team.

## License

Proprietary - All rights reserved
