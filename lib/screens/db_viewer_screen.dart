import 'package:flutter/material.dart';

import '../app_scope.dart';

/// Shows the rows of the local database. With real SQLite (Android) it also
/// runs read-only SELECT queries, like the "Query Playground" in the SQLite PDF.
class DbViewerScreen extends StatefulWidget {
  const DbViewerScreen({Key? key}) : super(key: key);

  @override
  State<DbViewerScreen> createState() => _DbViewerScreenState();
}

class _DbViewerScreenState extends State<DbViewerScreen> {
  final _sqlCtrl = TextEditingController(text: 'SELECT * FROM trips;');
  List<Map<String, Object?>> _rows = <Map<String, Object?>>[];
  String _message = '';

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _run();
    }
  }

  @override
  void dispose() {
    _sqlCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final s = AppScope.of(context);
      final store = s.trips.local;
      final uid = s.auth.currentUser?.uid ?? '';
      final List<Map<String, Object?>> rows;
      if (store.supportsRawSql) {
        rows = await store.rawSelect(_sqlCtrl.text);
      } else {
        rows = (await store.getAll(uid, includeDeleted: true)).map((t) => t.toMap()).toList();
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _message = '${rows.length} row(s)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = <Map<String, Object?>>[];
        _message = 'Error: $e';
      });
    }
  }

  Widget _table() {
    if (_rows.isEmpty) return const Text('No rows to display.');
    final cols = _rows.first.keys.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: cols.map((c) => DataColumn(label: Text(c))).toList(),
        rows: _rows
            .map((r) => DataRow(
                  cells: cols
                      .map((c) => DataCell(Text('${r[c] ?? "NULL"}')))
                      .toList(),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).trips.local;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _run,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Engine: ${store.label}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                'Table trips (schema v2): userId TEXT, id TEXT (PK userId+id), destination TEXT, '
                'startDate TEXT, endDate TEXT, days INTEGER, budget INTEGER, travellers INTEGER, '
                'travelType TEXT, preferences TEXT (JSON), itinerary TEXT (JSON), notes TEXT, '
                'estimatedCost INTEGER, createdAt INTEGER, updatedAt INTEGER, synced INTEGER (0/1), '
                'deleted INTEGER (0/1, pending cloud delete)',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (store.supportsRawSql) ...[
                TextField(
                  controller: _sqlCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'SELECT query (read-only)',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _run,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run query'),
                ),
              ] else
                const Text('Raw SQL is unavailable in the web fallback. '
                    'Run on Android to use real SQLite.'),
              const SizedBox(height: 8),
              Text(_message, style: const TextStyle(color: Colors.teal)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(child: _table()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
