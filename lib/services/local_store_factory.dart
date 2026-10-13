import 'package:flutter/foundation.dart' show kIsWeb;

import 'local_store.dart';
import 'sqlite_store.dart';
import 'web_fallback_store.dart';

/// Chooses the storage engine for the current platform.
LocalStore createPlatformLocalStore() => kIsWeb ? WebFallbackStore() : SqliteStore();
