import 'dart:async';

import 'package:flutter/material.dart';

import '../sdk_showcase_item.dart';

class SdkBlock extends StatelessWidget {
  final SdkItem item;

  const SdkBlock({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => unawaited(item.onTap()),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
