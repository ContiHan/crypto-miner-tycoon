// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rig.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Rig _$RigFromJson(Map<String, dynamic> json) => Rig(
  id: json['id'] as String,
  amount: (json['amount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$RigToJson(Rig instance) => <String, dynamic>{
  'id': instance.id,
  'amount': instance.amount,
};
