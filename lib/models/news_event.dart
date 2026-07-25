import 'package:flutter/material.dart';

enum EventType {
  // Three buff/debuff pairs + one neutral banner. Each pair = a temp buff and a
  // debuff on the same axis:
  bullRun, // income +   (pair: income)
  marketCrash, // income -
  airdrop, // wallet +   (pair: wallet, one-shot)
  hack, // wallet -
  cheapEnergy, // rig cost -   (pair: cost)
  costSpike, // rig cost +
  info, // neutral banner ONLY (e.g. halving) — never rolled as a random event
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
