import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../data/destinations.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../widgets/preference_chips.dart';
import '../widgets/storage_status_card.dart';
import 'db_viewer_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _budget = TextEditingController();
  String _type = '';
  List<String> _interests = <String>[];
  int _loadedUpdatedAt = -1;
  String? _loadedUid;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _budget.dispose();
    super.dispose();
  }

  void _load(UserProfile p) {
    if (_loadedUid == p.uid && _loadedUpdatedAt == p.updatedAt) return;
    _loadedUid = p.uid;
    _loadedUpdatedAt = p.updatedAt;
    _name.text = p.name;
    _phone.text = p.phone;
    _city.text = p.homeCity;
    _budget.text = p.defaultBudget > 0 ? '${p.defaultBudget}' : '';
    _type = p.preferredTravelType;
    _interests = List.of(p.interests);
  }

  Future<void> _save(UserProfile current) async {
    if (!_formKey.currentState!.validate()) return;
    final s = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final updated = current.copyWith(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      homeCity: _city.text.trim(),
      preferredTravelType: _type,
      interests: _interests,
      defaultBudget: int.tryParse(_budget.text.trim()) ?? 0,
    );
    final ok = await s.profile.save(updated);
    if (ok && updated.name != s.auth.currentUser?.displayName) {
      try {
        await s.auth.updateDisplayName(updated.name);
      } on AuthException catch (_) {}
    }
    _loadedUpdatedAt = s.profile.profile?.updatedAt ?? -1;
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? 'Profile saved' : 'Profile saved on device - will sync when online'),
    ));
  }

  Future<void> _resetPassword(String email) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).auth.sendPasswordReset(email);
      messenger.showSnackBar(SnackBar(content: Text('Password reset email sent to $email')));
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _logout() async {
    final auth = AppScope.of(context).auth;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Trips stay saved in your account and on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              key: const Key('confirm_logout'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (yes == true) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: s.profile,
          builder: (context, _) {
            final p = s.profile.profile;
            if (p == null) return const Center(child: CircularProgressIndicator());
            _load(p);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(children: [
                        CircleAvatar(radius: 32, child: Text(p.initials, style: const TextStyle(fontSize: 22))),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.name.isEmpty ? 'Traveller' : p.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(p.email),
                            if (s.profile.hasPendingChanges)
                              const Text('Changes waiting to sync',
                                  style: TextStyle(color: Colors.orange, fontSize: 12)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const Key('profile_name'),
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.length < 2) return 'Enter your name';
                          if (t.length > 60) return 'Name is too long';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                        decoration: const InputDecoration(
                            labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined)),
                        validator: (v) {
                          final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                          if (digits.isEmpty) return null;
                          if (digits.length < 10 || digits.length > 13) return 'Enter a valid phone number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _city,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Home city (optional)', prefixIcon: Icon(Icons.home_outlined)),
                        validator: (v) => (v ?? '').length > 60 ? 'Too long' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _budget,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                            labelText: 'Typical trip budget (₹, optional)',
                            prefixIcon: Icon(Icons.currency_rupee)),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if ((v ?? '').trim().isEmpty) return null;
                          if (n == null || n > 10000000) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: kTravelTypes.contains(_type) ? _type : null,
                        decoration: const InputDecoration(
                            labelText: 'Preferred travel type', prefixIcon: Icon(Icons.explore_outlined)),
                        items: [
                          for (final t in kTravelTypes) DropdownMenuItem(value: t, child: Text(t)),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? ''),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 16, bottom: 6),
                        child: Text('Interests', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      PreferenceChips(
                          selected: _interests, onChanged: (v) => setState(() => _interests = v)),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('profile_save'),
                        onPressed: _saving ? null : () => _save(p),
                        icon: _saving
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: const Text('Save profile'),
                      ),
                      const SizedBox(height: 24),
                      const Text('Account & data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      StorageStatusCard(repo: s.trips),
                      Card(
                        child: Column(children: [
                          ListTile(
                            leading: const Icon(Icons.lock_reset),
                            title: const Text('Send password reset email'),
                            onTap: () => _resetPassword(p.email),
                          ),
                          ListTile(
                            leading: const Icon(Icons.table_chart_outlined),
                            title: const Text('Local database viewer'),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const DbViewerScreen())),
                          ),
                          ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text('About'),
                            onTap: () => showAboutDialog(
                              context: context,
                              applicationName: 'AI Travel Planner',
                              applicationVersion: '2.0.0',
                              children: const [
                                Text('Recommendations and itineraries come from a transparent '
                                    'rule-based engine, not a trained AI model. Costs are '
                                    'illustrative estimates in INR, not live prices.\n\n'
                                    'Data is stored on the device first (SQLite on Android/iOS, '
                                    'browser storage on the web) and synced to Firebase '
                                    'Realtime Database under your account.'),
                              ],
                            ),
                          ),
                          ListTile(
                            key: const Key('profile_logout'),
                            leading: const Icon(Icons.logout, color: Colors.red),
                            title: const Text('Log out', style: TextStyle(color: Colors.red)),
                            onTap: _logout,
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
