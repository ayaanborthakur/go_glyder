import 'package:flutter/material.dart';

import 'package:go_glyder/services/notification_service.dart';

import 'theme.dart';
import 'router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GoGlyder',
      debugShowCheckedModeBanner: false,
      // Lets NotificationService show foreground SnackBar banners without a
      // BuildContext.
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
