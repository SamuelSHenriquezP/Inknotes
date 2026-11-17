import 'dart:convert';
import 'package:flutter/material.dart';

IconData getFolderIconData(int code) {
  switch (code) {
    case 0xe362:
      return Icons.lightbulb_rounded;
    case 0xe491:
      return Icons.person_rounded;
    case 0xe6f2:
      return Icons.work_rounded;
    case 0xe5f9:
      return Icons.star_rounded;
    case 0xe14d:
      return Icons.menu_book_rounded;
    case 0xe87d:
      return Icons.favorite_rounded;
    case 0xe59c:
      return Icons.shopping_bag_rounded;
    case 0xe2a3:
    default:
      return Icons.folder_rounded;
  }
}

class FolderModel {
  final String id;
  final String name;
  final int colorValue;
  final int iconCode;
  final DateTime createdAt;

  const FolderModel({
    required this.id,
    required this.name,
    this.colorValue = 0xFF6366F1,
    this.iconCode = 0xe2a3, // folder icon
    required this.createdAt,
  });

  IconData get iconData => getFolderIconData(iconCode);
  Color get color => Color(colorValue);

  FolderModel copyWith({
    String? id,
    String? name,
    int? colorValue,
    int? iconCode,
    DateTime? createdAt,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconCode: iconCode ?? this.iconCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'iconCode': iconCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FolderModel.fromMap(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'] as String? ?? 'general',
      name: map['name'] as String? ?? 'General',
      colorValue: map['colorValue'] as int? ?? 0xFF6366F1,
      iconCode: map['iconCode'] as int? ?? 0xe2a3,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory FolderModel.fromJson(String source) =>
      FolderModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
