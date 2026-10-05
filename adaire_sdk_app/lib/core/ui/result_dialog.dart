import 'package:flutter/material.dart';

Future<void> showResultDialog({
  required BuildContext context,
  required String title,
  required String content,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SelectableText(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
