import 'package:flutter/material.dart';

class SdkItem {
  final String title;
  final IconData icon;
  final Future<void> Function() onTap;

  const SdkItem({required this.title, required this.icon, required this.onTap});
}
