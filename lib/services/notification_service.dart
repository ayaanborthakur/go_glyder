// lib/services/notification_service.dart
//
// NotificationService — owns all Firebase Cloud Messaging (FCM)
// responsibilities for the Android and Web platforms.
//
// Responsibilities:
//   • Request notification permission on first launch
//   • Obtain and persist the FCM token to Firestore (users/{uid}.fcmToken)
//   • Refresh the token whenever FCM rotates it
//   • Handle foreground messages with an in-app SnackBar banner
//   • Handle background-tap and terminated-tap via the global router
//   • Clear the token on sign-out so no stale pushes arrive
//
// iOS is intentionally excluded from this implementation.

import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// VAPID key for Web Push — generated once in Firebase Console.
// Project Settings → Cloud Messaging → Web configuration → Web Push certificates
// ---------------------------------------------------------------------------
const String kVapidKey =
    'BIFO71lE0QHOkjY45u8jEniNQVfD_QtPG5bFH337NTIidGWr_aCglnqwb-1dhGT22kMDAFmVVVHn6m9V_VmYnlQ';

// ---------------------------------------------------------------------------
// Top-level background handler.
// FCM requires this to be a top-level (not a method) function annotated with
// @pragma('vm:entry-point') so the background isolate can locate it.
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // For data-only messages you can do lightweight work here.
  // Notification messages are automatically displayed by the OS —
  // no additional code needed.
  developer.log(
    'Background message received: ${message.messageId}',
    name: 'GoGlyder.FCM',
  );
}

// ---------------------------------------------------------------------------
// Global key so NotificationService can show SnackBars without needing a
// BuildContext passed in at call time. Register it on MaterialApp.router in
// app.dart.
// ---------------------------------------------------------------------------
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Navigation callback wired up by the app at startup (see main.dart).
  ///
  /// Kept as a callback rather than importing the router directly so this
  /// service never depends on the features/router layer (which would create a
  /// services → features → services import cycle via auth.dart).
  void Function(String route)? onNavigateToRoute;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once from [main()] after [Firebase.initializeApp()].
  ///
  /// Registers the background handler, requests permission, fetches and saves
  /// the FCM token, and sets up the three message stream listeners.
  Future<void> initialize() async {
    // 0. Background/terminated data handler must be registered before any other
    //    FCM setup so the background isolate can find it.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 1. Permission (Android 13+ and Web both require an explicit grant)
    await _requestPermission();

    // 2. Fetch + persist initial token
    await _fetchAndSaveToken();

    // 3. Token rotation listener
    _fcm.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _writeToken(uid, token);
    });

    // 4. Foreground message → in-app SnackBar banner
    FirebaseMessaging.onMessage.listen(_showForegroundBanner);

    // 5. Background notification tap → navigate
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // 6. Terminated-state tap → app was cold-launched via a notification
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleMessageTap(initial);
  }

  /// Call after successful sign-in to ensure the token is associated with
  /// the correct user account.
  Future<void> saveTokenForUser(String uid) async {
    await _fetchAndSaveToken(uid: uid);
  }

  /// Call on sign-out to prevent this device from receiving pushes intended
  /// for the previous user.
  Future<void> clearTokenForUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': FieldValue.delete(),
        'fcmPlatform': FieldValue.delete(),
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log(
        'Could not clear FCM token for $uid',
        name: 'GoGlyder.FCM',
        error: e,
      );
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    // iOS is skipped — the AuthorizationStatus check prevents any prompt.
    // Android 13+ and Web both respect this call.
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    developer.log(
      'FCM permission: ${settings.authorizationStatus}',
      name: 'GoGlyder.FCM',
    );
  }

  Future<void> _fetchAndSaveToken({String? uid}) async {
    try {
      final String? token;

      if (kIsWeb) {
        // Web requires the VAPID key to derive the push subscription.
        token = await _fcm.getToken(vapidKey: kVapidKey);
      } else {
        token = await _fcm.getToken();
      }

      if (token == null) return;

      final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (resolvedUid == null)
        return; // Not signed in yet — will be saved on sign-in

      await _writeToken(resolvedUid, token);
    } catch (e) {
      developer.log(
        'Could not fetch FCM token',
        name: 'GoGlyder.FCM',
        error: e,
      );
    }
  }

  Future<void> _writeToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmPlatform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      developer.log('FCM token saved for $uid', name: 'GoGlyder.FCM');
    } catch (e) {
      developer.log(
        'Could not write FCM token for $uid',
        name: 'GoGlyder.FCM',
        error: e,
      );
    }
  }

  /// Shows a dismissible SnackBar when a notification arrives while the app
  /// is in the foreground (the OS does NOT show its own banner in this case).
  void _showForegroundBanner(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(
              Icons.notifications_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (notification.title != null)
                    Text(
                      notification.title!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  if (notification.body != null)
                    Text(
                      notification.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: const Color(0xFF2FBF71),
          onPressed: () => _handleMessageTap(message),
        ),
      ),
    );
  }

  /// Routes the user to the appropriate screen based on the notification's
  /// data payload. Called on both background-tap and terminated-tap.
  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    final route = data['route'] as String?;

    if (route == null) return;

    // Small delay for the terminated-state case: the router isn't ready
    // until the first frame is rendered.
    Future.delayed(const Duration(milliseconds: 500), () {
      onNavigateToRoute?.call(route);
    });

    developer.log(
      'Notification tap → type: $type, route: $route',
      name: 'GoGlyder.FCM',
    );
  }
}
