# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Development Commands

### Flutter App (`lib/`)

```bash
# Install dependencies
flutter pub get

# Analyze code for issues/linting
flutter analyze

# Run the app
flutter run

# Run tests (if any are added)
flutter test

# Run a single test file
flutter test test/path/to_test.dart

# Build for Android
flutter build apk

# Build for iOS
flutter build ios

# Build for macOS
flutter build macos
```

### Firebase Functions (`functions/`)

```bash
# Install dependencies
npm install

# Run TypeScript compiler in watch mode
npm run build -- --watch

# Deploy functions
firebase deploy --only functions

# Serve functions locally
firebase emulators:start --only functions
```

## Architecture Overview

### High-Level Structure

This is a multi-platform Flutter application (Android, iOS, macOS, web) with Firebase backend services.

**Architecture layers:**

1. **Core Layer** (`lib/core/`): Application-wide configuration
   - `main.dart` - Entry point, initializes Firebase and Google Sign-In
   - `app.dart` - Root widget wrapping MaterialApp.router with go_router
   - `router.dart` - Navigation handled by go_router with auth-aware redirects
   - `session.dart` - Global auth + profile state manager (ChangeNotifier) that the router and screens read from
   - `theme.dart` - Design system (Plus Jakarta Sans font, brand greens, corner radii, spacing)

2. **Services Layer** (`lib/services/`):
   - `firebase.dart` - Firebase initialization
   - `firestore_service.dart` - Single point of contact for all Firestore I/O (users, schools, groups, trips, carpools, community posts)
   - `messages_fs.dart` - Typed models and Firestore I/O for direct messaging
   - `school_calendar_service.dart` - School-wide calendar upload/parse (ICS → JSON → Storage)
   - `notification_service.dart` - Firebase Cloud Messaging setup
   - `gmaps.dart` - Google Maps integration

3. **Features Layer** (`lib/features/`):
   - Generated barrel file `_index.g.dart` exports all feature screens
   - Each feature has its own `presentation/` and (optionally) `scripts/` subdirectory

4. **Models** (`lib/models/`):
   - `calendar_entry.dart` - Calendar items from school-wide upload or group events
   - `chat_message.dart` - Typed model for DM messages
   - `conversation.dart` - Typed model for DM threads

### Data Model

The Firestore structure follows a school-scoped hierarchy:

- `users/{uid}` - User profiles (email, displayName, role, schools, carbonMiles)
- `schools/{schoolId}` - School records with nested collections
  - `admins/{uid}` - Verified admin roster (the gate, not the profile's `role` field)
  - `groups/{groupId}` - Community groups within the school
    - `members/{uid}` - Group membership roster
    - `trips/{tripId}` - Carpool trips scoped to the group
      - `requests/{riderId}` - Seat requests on trips
- `conversations/{convId}` - Direct message threads (ID = sorted UIDs)
  - `messages/{msgId}` - Individual messages
- `communityPosts/{postId}` - Global community feed

### Authentication Flow

The router handles three states based on `Session`:
1. Not signed in → `/login`
2. Signed in, profile loading → `/loading`  
3. Signed in, no role → `/onboarding` (first-time role picker)
4. Fully set up → Main app routes

Roles are: `parent`, `staff`, `admin`. Admin role requires claiming via secret code (verified against Firestore security rules).