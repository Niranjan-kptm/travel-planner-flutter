import 'package:flutter/material.dart';

import '../services/recommendation_service.dart';
import '../utils/format.dart';

class DestinationCard extends StatelessWidget {
  final Recommendation rec;
  final bool saved;
  final VoidCallback onSave;

  const DestinationCard({
    Key? key,
    required this.rec,
    required this.saved,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final d = rec.destination;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(d.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(d.country),
                    ],
                  ),
                ),
                Chip(
                  label: Text('${rec.score}% match'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(d.description),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text('Est. ${formatInr(rec.estimatedCost)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Chip(
                  label: Text(rec.withinBudget ? 'Within budget' : 'Over budget'),
                  backgroundColor:
                      rec.withinBudget ? Colors.green.shade100 : Colors.orange.shade100,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: d.highlights
                  .map((h) => Chip(
                        label: Text(h, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            const Text('Why this suggestion',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...rec.reasons.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: saved ? null : onSave,
                icon: Icon(saved ? Icons.check : Icons.edit_calendar),
                label: Text(saved ? 'Saved' : 'Plan this trip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
