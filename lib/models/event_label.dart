import 'package:flutter/material.dart';

class EventLabel {
  final int? id;
  final String name;
  final int color; // màu lưu dạng số ARGB

  const EventLabel({this.id, required this.name, required this.color});

  Color get colorValue => Color(color);

  Map<String, Object?> toMap() {
    return {'id': id, 'name': name, 'color': color};
  }

  factory EventLabel.fromMap(Map<String, Object?> map) {
    return EventLabel(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as int,
    );
  }
}
