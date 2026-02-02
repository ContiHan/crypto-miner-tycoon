// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'research_node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResearchNode _$ResearchNodeFromJson(Map<String, dynamic> json) => ResearchNode(
  id: json['id'] as String,
  isUnlocked: json['isUnlocked'] as bool? ?? false,
  isCompleted: json['isCompleted'] as bool? ?? false,
);

Map<String, dynamic> _$ResearchNodeToJson(ResearchNode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'isUnlocked': instance.isUnlocked,
      'isCompleted': instance.isCompleted,
    };
