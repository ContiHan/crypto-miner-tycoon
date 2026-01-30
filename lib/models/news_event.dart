import 'package:flutter/material.dart';

enum EventType {
  info,
  marketCrash, // -$$
  bullRun, // +$$
  hack, // -Wallet
  cheapEnergy // -Cost
}

class NewsEvent {
  final String message;
  final EventType type;
  final double value; // Multiplier or amount depending on type
  final int durationSeconds;
  final Color color;

  const NewsEvent({
    required this.message,
    required this.type,
    this.value = 0,
    this.durationSeconds = 10,
    this.color = Colors.white,
  });
}
