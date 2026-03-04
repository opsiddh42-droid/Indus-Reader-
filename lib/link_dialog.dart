import 'package:flutter/material.dart';

class LinkDialog extends StatefulWidget {
  final Function(String action, String url) onApply;
  const LinkDialog({super.key, required this.onApply});

  @override
  State<LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<LinkDialog> {
  String newUrl = "";

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Links'),
      content: TextField(
        decoration: const InputDecoration(labelText: 'Enter new link (http...)'),
        onChanged: (val) => newUrl = val,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onApply('remove', '');
          },
          child: const Text('Remove Old Links', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            if (newUrl.isNotEmpty) {
              widget.onApply('add', newUrl);
            }
          },
          child: const Text('Add Link'),
        ),
      ],
    );
  }
}
