import 'package:flutter/material.dart';

class ResearchNode {
  final String id;
  final String name;
  final String description;
  final double cost;
  final IconData icon;
  
  // Research State
  bool isUnlocked; // Visible and purchasable
  bool isCompleted; // Purchased and active

  // Requirements (optional IDs of parent nodes)
  final List<String> requirements;

  ResearchNode({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.icon,
    this.isUnlocked = false,
    this.isCompleted = false,
    this.requirements = const [],
  });

  // Serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'isUnlocked': isUnlocked,
    'isCompleted': isCompleted,
  };
}
