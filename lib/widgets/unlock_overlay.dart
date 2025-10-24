import 'package:flutter/material.dart';
import 'dart:async';

Future<void> showUnlockOverlay(BuildContext context, {
  required String unlockTitle,
  required String itemName,
  required IconData iconData,
  required Color color,
}) {
  final completer = Completer<void>();
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => UnlockOverlay(
      unlockTitle: unlockTitle,
      itemName: itemName,
      iconData: iconData,
      color: color,
      onComplete: () {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    ),
  );

  overlay.insert(overlayEntry);
  return completer.future;
}

class UnlockOverlay extends StatefulWidget {
  final String unlockTitle;
  final String itemName;
  final IconData iconData;
  final Color color;
  final VoidCallback onComplete;

  const UnlockOverlay({
    super.key,
    required this.unlockTitle,
    required this.itemName,
    required this.iconData,
    required this.color,
    required this.onComplete,
  });

  @override
  State<UnlockOverlay> createState() => _UnlockOverlayState();
}

class _UnlockOverlayState extends State<UnlockOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500));

    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, -1.5), end: const Offset(0, 0.2))
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, 0.2), end: Offset.zero)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween(Offset.zero),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0, -1.5))
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_controller);

    _controller.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: widget.color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.iconData, color: widget.color, size: 28),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.unlockTitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                      Text(
                        widget.itemName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
