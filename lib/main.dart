import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // 1️⃣ Import Provider

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/ledger_screen.dart'; // 🪙 Added Ledger Screen import
import 'services/notification_service.dart';
import 'utils/firestore_sync_notifier.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2️⃣ Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // 3️⃣ Initialize NotificationService
  // 🔥 INITIALIZE NOTIFICATIONS BEFORE runApp
  await NotificationService.instance.init();

  // 4️⃣ Ask user for notification permission
  await NotificationService.instance.requestPermissions();

  // ✅ Timezone initialization (REQUIRED)
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.local);

  // 5️⃣ Wrap MyApp with ChangeNotifierProvider for global sync state
  runApp(
    ChangeNotifierProvider(
      create: (_) => FirestoreSyncNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QuestForge',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F3460),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      navigatorKey: navigatorKey,
      // 🗺️ ADDED ROUTES FOR PROPER ARCHITECTURE
      routes: {
        '/ledger': (context) => const LedgerScreen(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return HomeScreen(uid: snapshot.data!.uid);
          }
          return const AuthScreen();
        },
      ),
    );
  }
}