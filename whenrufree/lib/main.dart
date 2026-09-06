import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'data/cloud/firestore_data_store.dart';
import 'services/notification_service.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cloud is dormant until real Firebase keys are pasted into
  // lib/firebase_options.dart and kCloudBackendEnabled is flipped.
  // Any failure falls back to fully-offline local mode.
  try {
    await FirestoreDataStore.instance.tryInit();
  } catch (_) {
    // Stay local.
  }

  // Local gap alerts (permissions are requested on first use, not here).
  try {
    await NotificationService.instance.init();
  } catch (_) {
    // Notifications unavailable on this platform — app works without them.
  }

  final store = AppStore();
  // Don't await: UI shows a loader until ready.
  unawaited(store.load());

  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const WhenRUFApp(),
    ),
  );
}
