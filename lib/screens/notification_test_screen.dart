import 'package:flutter/material.dart';

class NotificationTestScreen extends StatelessWidget {
  const NotificationTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Opened')),
      body: const Center(
        child: Text(
          'You opened this by tapping a notification 🎉',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
