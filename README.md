# 📦 Expiry & Inventory Management App

A Flutter mobile application to track product expiry dates, manage inventory by category, scan barcodes and bills, and receive scheduled notifications before items expire.

---



## 📱 Screenshots

<img width="200" src="https://github.com/user-attachments/assets/3ce0952d-3d7b-4548-89b3-79ddbce548d7" />
<img width="200" src="https://github.com/user-attachments/assets/65ffa009-ca8d-4a41-b97f-eaea1e2bb3bf" />
<img width="200" src="https://github.com/user-attachments/assets/49f059d2-5015-4c0e-9667-9bda383dce2a" />
<img width="200" src="https://github.com/user-attachments/assets/976f3746-d6c2-4bd6-9881-661057ce2c70" />
<img width="200" src="https://github.com/user-attachments/assets/71ce53e7-0b73-4d76-b8ff-5b95336d8fc0" />
<img width="200" src="https://github.com/user-attachments/assets/5b7c3633-3a9f-4eb1-9bf6-09a5faf86fea" />
<img width="200" src="https://github.com/user-attachments/assets/dc6c9655-9d7f-419d-a62a-d59cfba35c8c" />
<img width="200" src="https://github.com/user-attachments/assets/93a115b4-74a7-42b1-9b39-c06d4f2f3bad" />
<img width="200" src="https://github.com/user-attachments/assets/9bc4defd-cbb8-4708-b767-e14d73d1a284" />
<img width="200" src="https://github.com/user-attachments/assets/6413e33f-b3e5-4650-a8bd-05c041523ec0" />
<img width="200" src="https://github.com/user-attachments/assets/9fcead1e-de02-4db0-a5a4-1aceba19443d" />
<img width="200" src="https://github.com/user-attachments/assets/f941814b-7e65-4d47-b734-08933f818ad9" />
<img width="200" src="https://github.com/user-attachments/assets/d8e2c687-6b58-4058-b1c6-41f37864fa5f" />


---

## ✨ Features

- 🔐 **Authentication** — Email/password sign-up, email verification, forgot password, auto-login
- 📋 **Item Management** — Add, edit, delete items with search and sort options
- 📷 **Barcode Scanner** — Scan products and auto-fill details from Open Facts databases
- 🧾 **Bill Scanner** — Photograph a shopping bill; OCR extracts and looks up all products at once
- 🗂️ **Groups** — Browse inventory organised by category
- ⚠️ **Expired Items** — Dedicated view for items past their expiry date
- 🔔 **Notifications** — Scheduled local alerts before items expire; persists across reboots
- ⚙️ **Settings** — Change email, change password, reset password, logout

---

## 🛠️ Tech Stack

| | |
|---|---|
| Framework | Flutter 3 / Dart |
| Auth & Database | Firebase Authentication + Cloud Firestore |
| Local Notifications | flutter_local_notifications + timezone |
| Barcode Scanning | mobile_scanner |
| OCR | google_mlkit_text_recognition |
| Product Lookup | Open Food Facts / Open Beauty Facts / Open Pet Food Facts / Open Products Facts APIs |
| Image Picking | image_picker |
| HTTP | http |
| Background Tasks | workmanager |

---

## 📁 Project Structure

```
lib/
├── main.dart                   # Entry point, Firebase init, auth wrapper
├── firebase_options.dart       # Firebase platform config
│
├── LoginPage.dart              # Login screen
├── create_account.dart         # Sign-up screen
├── email_verification.dart     # Email verification screen
├── forgot_password.dart        # Password reset screen
│
├── dashboard.dart              # Main scaffold with bottom navigation
│
├── all_items_page.dart         # All items — search & sort
├── grouped_items_page.dart     # Items grouped by category
├── expired_items_page.dart     # Expired items list
├── notifications_page.dart     # In-app notification centre
│
├── add_item.dart               # Add new item form
├── edit_item_page.dart         # Edit existing item form
│
├── qr_scanner_page.dart        # Barcode scanner + product lookup
├── bill_scanner_page.dart      # Bill OCR + bulk item save
│
├── profile_page.dart           # User profile
├── settings_page.dart          # Account settings
│
└── notification_service.dart   # Notification scheduling logic
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.8.1`
- Android device or emulator (minSdk 23, targetSdk 36)
- A Firebase project with **Firestore** and **Email/Password Authentication** enabled

### 1. Clone the repository

```bash
git clone https://github.com/your-username/expiry-inventory-app.git
cd expiry-inventory-app
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/) and create a project
2. Add an Android app with package name `com.example.expiry_and_inventory`
3. Download `google-services.json` and place it in `android/app/`
4. Run `flutterfire configure` or manually update `lib/firebase_options.dart`
5. Enable **Email/Password** under Authentication → Sign-in methods
6. Create a **Firestore** database and apply the security rules below

### 4. Run the app

```bash
flutter run
```

---

## 📦 Dependencies

```yaml
dependencies:
  firebase_core: ^4.5.0
  firebase_auth: ^6.2.0
  cloud_firestore: ^6.1.3
  flutter_local_notifications: ^17.0.0
  mobile_scanner: ^5.0.0
  google_mlkit_text_recognition: ^0.13.0
  image_picker: ^1.1.2
  http: ^1.2.0
  timezone: ^0.9.0
  workmanager: ^0.9.0
  random_string: ^2.3.1

dev_dependencies:
  device_preview: ^1.1.0
  flutter_lints: ^5.0.0
```

---

## 🗄️ Firestore Data Structure

### Collection: `items`

| Field | Type | Description |
|---|---|---|
| `userId` | String | Owner's Firebase Auth UID |
| `name` | String | Item name |
| `group` | String | Category (e.g. Food, Medicine) |
| `barcode` | String | Barcode number (optional) |
| `expiryDate` | Timestamp | Product expiry date |
| `reminderDays` | String | Days before expiry to send notification |
| `notificationTime` | String | Time of notification (e.g. `"9:00 AM"`) |
| `createdAt` | Timestamp | Document creation timestamp |

### Security Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /items/{itemId} {
      allow read, update, delete: if request.auth != null
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null
        && request.auth.uid == request.resource.data.userId;
    }
  }
}
```

---

## 🔔 Notification Setup

Notifications are scheduled using `flutter_local_notifications` with `zonedSchedule`. The timezone is set to `Asia/Kolkata` by default — update this in `notification_service.dart` if needed:

```dart
tz.setLocalLocation(tz.getLocation('Your/Timezone'));
```

The following permissions are declared in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you'd like to change.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
