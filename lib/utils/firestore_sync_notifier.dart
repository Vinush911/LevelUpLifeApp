import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreSyncNotifier extends ChangeNotifier {
  bool _isSynced = true;
  bool get isSynced => _isSynced;

  StreamSubscription? _sub;

  FirestoreSyncNotifier() {
    // Listen to Firestore's sync state
    // Emits true when all writes are ack'd, false when writes are pending (offline/latency)
    _sub = FirebaseFirestore.instance.snapshotsInSync().listen((_) {
      _isSynced = true;
      notifyListeners();
    });
  }

  // Call this manually from UI catches if a specific write fails
  void markOffline() {
    if (_isSynced) {
      _isSynced = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}