import 'package:flutter/material.dart';

import '../data/destinations.dart';

class TravelTypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const TravelTypeSelector({
    Key? key,
    required this.selected,
    required this.onChanged,
  }) : super(key: key);

  static String iconFor(String type) {
    switch (type) {
      case 'Beach':
        return '🏖️';
      case 'Adventure':
        return '🧗';
      case 'Culture':
        return '🏛️';
      case 'Nature':
        return '🌿';
      case 'Relaxation':
        return '🧘';
      default:
        return '🧳';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: kTravelTypes
          .map((t) => ChoiceChip(
                label: Text('${iconFor(t)} $t'),
                selected: t == selected,
                onSelected: (_) => onChanged(t),
              ))
          .toList(),
    );
  }
}
