import 'package:flutter/material.dart';

import '../data/destinations.dart';

/// Multi-select interests.
class PreferenceChips extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const PreferenceChips({Key? key, required this.selected, required this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final p in kPreferences)
          FilterChip(
            label: Text(p),
            selected: selected.contains(p),
            onSelected: (on) {
              final next = List<String>.from(selected);
              on ? next.add(p) : next.remove(p);
              onChanged(next);
            },
          ),
      ],
    );
  }
}
