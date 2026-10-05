import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class CollegeListScreen extends ConsumerWidget {
  const CollegeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collegesAsync = ref.watch(collegesListProvider);
    final activeCollegeId = ref.watch(activeCollegeIdProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Colleges & Campus Organizations',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Manage institutional tenants, campus codes, and academic years',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCollegeDialog(context, ref, null),
                  icon: const Icon(Icons.add_business, size: 18),
                  label: const Text('Add College'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            collegesAsync.when(
              data: (colleges) {
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: DataTable(
                    columnSpacing: 24,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('College Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Academic Year', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Daily Periods', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Active Scope', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: colleges.map((col) {
                      final isActive = col.id == activeCollegeId;

                      return DataRow(
                        cells: [
                          DataCell(Chip(label: Text(col.code, style: const TextStyle(fontWeight: FontWeight.bold)))),
                          DataCell(Text(col.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(col.academicYear)),
                          DataCell(Text('${col.periodsPerDay} periods')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isActive ? 'Active Management Scope' : 'Inactive Scope',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.green.shade800 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isActive)
                                  TextButton(
                                    onPressed: () {
                                      ref.read(activeCollegeIdProvider.notifier).state = col.id;
                                      ref.invalidate(currentCollegeProvider);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Switched active management scope to ${col.name}')),
                                      );
                                    },
                                    child: const Text('Switch To', style: TextStyle(fontSize: 12)),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showCollegeDialog(context, ref, col),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCollegeDialog(BuildContext context, WidgetRef ref, College? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final yearCtrl = TextEditingController(text: existing?.academicYear ?? '2026-2027');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Register New College' : 'Edit College Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'College Name')),
            const SizedBox(height: 12),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code (e.g. MIT, AEI)')),
            const SizedBox(height: 12),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 12),
            TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Academic Year')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && codeCtrl.text.isNotEmpty) {
                if (existing == null) {
                  final newCol = College(
                    id: 'col_${const Uuid().v4().substring(0, 8)}',
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim().toUpperCase(),
                    address: addressCtrl.text.trim(),
                    academicYear: yearCtrl.text.trim(),
                  );
                  await ref.read(collegeControllerProvider.notifier).createCollege(newCol);
                } else {
                  final updated = existing.copyWith(
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim().toUpperCase(),
                    address: addressCtrl.text.trim(),
                    academicYear: yearCtrl.text.trim(),
                  );
                  await ref.read(collegeControllerProvider.notifier).updateCollege(updated);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
