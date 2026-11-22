import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/core_providers.dart';
import 'providers/reminder_providers.dart';
import 'providers/sync_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class UniFriendApp extends ConsumerStatefulWidget {
  const UniFriendApp({super.key});

  @override
  ConsumerState<UniFriendApp> createState() => _UniFriendAppState();
}

/// Besides building the app, this runs what has to happen in the background
/// while it is open: noticing the connection come back, catching up on
/// returning to the foreground, and acting on tapped notifications.
class _UniFriendAppState extends ConsumerState<UniFriendApp>
    with WidgetsBindingObserver {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final Timer _retry;
  late final StreamSubscription<String> _tappedRoutes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final store = ref.read(rowStoreProvider);
    // While offline, look for the connection now and then, so the banner
    // clears and the lists reload by themselves once it is back.
    _retry = Timer.periodic(const Duration(seconds: 30), (_) {
      if (store.isOffline) store.checkConnection();
    });

    final reminders = ref.read(reminderGatewayProvider);
    _tappedRoutes = reminders.tappedRoutes.listen(
      (route) => ref.read(routerProvider).go(route),
    );
    unawaited(reminders.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retry.cancel();
    _tappedRoutes.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Covers whatever the live feed missed while the app was in the background.
    if (ref.read(currentUserIdProvider) != null) {
      reloadEverything(ref.invalidate);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(liveSyncProvider);
    ref.watch(reminderSyncProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'UniFriend',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scaffoldMessengerKey: _messengerKey,
      routerConfig: router,
    );
  }
}
