import 'package:flutter/material.dart';

class WatermarkDialog extends StatefulWidget {
  final Function(String text, String position, double opacity, bool allPages) onApply;
  
  const WatermarkDialog({super.key, required this.onApply});

  @override
  State<WatermarkDialog> createState() => _WatermarkDialogState();
}

class _WatermarkDialogState extends State<WatermarkDialog> {
  String text = "INDUS READER";
  String position = 'Center';
  double opacity = 0.5;
  bool allPages = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Watermark'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Watermark Text'),
              onChanged: (val) => text = val,
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: position,
              isExpanded: true,
              items: ['Top', 'Center', 'Bottom'].map((String val) {
                return DropdownMenuItem(value: val, child: Text(val));
              }).toList(),
              onChanged: (val) => setState(() => position = val!),
            ),
            const SizedBox(height: 10),
            const Text('Transparency (Opacity)'),
            Slider(
              value: opacity,
              min: 0.1, max: 1.0,
              onChanged: (val) => setState(() => opacity = val),
            ),
            SwitchListTile(
              title: const Text('Apply to All Pages'),
              value: allPages,
              onChanged: (val) => setState(() => allPages = val),
            )
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onApply(text, position, opacity, allPages);
          },
          child: const Text('Apply'),
        )
      ],
    );
  }
}
