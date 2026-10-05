import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _semCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final college = ref.watch(currentCollegeProvider).value;
    final useFirebase = ref.watch(useFirebaseBackendProvider);

    if (college != null && !_initialized) {
      _nameCtrl.text = college.name;
      _codeCtrl.text = college.code;
      _yearCtrl.text = college.academicYear;
      _semCtrl.text = college.currentSemester;
      _addressCtrl.text = college.address;
      _initialized = true;
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'College & System Settings',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Institution identity, academic terms, database backend mode, and data seeding',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Institution Details Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Institution Identity & Academic Term', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'College / University Name')),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Code (e.g. AEI)')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(controller: _yearCtrl, decoration: const InputDecoration(labelText: 'Academic Year (e.g. 2026-2027)')),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(controller: _semCtrl, decoration: const InputDecoration(labelText: 'Current Semester (e.g. Odd 2026)')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Campus Address')),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (college != null) {
                            final updated = college.copyWith(
                              name: _nameCtrl.text.trim(),
                              code: _codeCtrl.text.trim().toUpperCase(),
                              academicYear: _yearCtrl.text.trim(),
                              currentSemester: _semCtrl.text.trim(),
                              address: _addressCtrl.text.trim(),
                            );
                            await ref.read(collegeControllerProvider.notifier).updateCollege(updated);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('College profile updated successfully!')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Save College Details'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Backend Provider Mode
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Database & Cloud Backend Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text(
                      'Switch between simulated local storage and real Cloud Firestore backend.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const Divider(height: 24),
                    SwitchListTile(
                      title: const Text('Use Live Cloud Firestore Backend', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(useFirebase
                          ? 'Active: Queries connect directly to Cloud Firestore with multi-college rules.'
                          : 'Active: Running with local database repository. Instant zero-setup test mode.'),
                      value: useFirebase,
                      onChanged: (val) {
                        ref.read(useFirebaseBackendProvider.notifier).state = val;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(val ? 'Switched to Cloud Firestore backend' : 'Switched to Local Repository')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Account & Session Information
            Builder(
              builder: (context) {
                final user = ref.watch(currentProfileProvider);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Account & Authentication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        const Text(
                          'Authenticated user identity and college data isolation tenant.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF0F172A),
                              child: Text(
                                user?.name.isNotEmpty == true ? user!.name.substring(0, 1).toUpperCase() : 'U',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.name.isNotEmpty == true ? user!.name : 'Administrator',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    user?.email.isNotEmpty == true ? user!.email : 'admin@timepilot.edu',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Role: ${user?.role.displayName ?? "College Admin"} • College ID: ${user?.collegeId ?? "user_college"}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF0051D5)),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onPressed: () async {
                                await ref.read(authControllerProvider.notifier).signOut();
                              },
                              icon: const Icon(Icons.logout_rounded, size: 16),
                              label: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
