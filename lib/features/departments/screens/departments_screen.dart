import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptsAsync = ref.watch(departmentListProvider);

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
                      'College Departments',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Manage academic departments (e.g. CSE, ISE, ECE, ME, CE) and HODs',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showDeptDialog(context, ref, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Department'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            deptsAsync.when(
              data: (depts) {
                if (depts.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: Text('No departments created yet.')),
                    ),
                  );
                }

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: DataTable(
                    columnSpacing: 24,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Department Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: depts.map((d) {
                      return DataRow(
                        cells: [
                          DataCell(Chip(
                            label: Text(d.code, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                          )),
                          DataCell(Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: d.active ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                d.active ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: d.active ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showDeptDialog(context, ref, d),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Delete Department?'),
                                        content: Text('Remove ${d.name} (${d.code})?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                                            onPressed: () => Navigator.pop(c, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ref.read(departmentControllerProvider.notifier).deleteDepartment(d.id);
                                    }
                                  },
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
              error: (e, _) => Text('Error loading departments: $e'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeptDialog(BuildContext context, WidgetRef ref, Department? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Create Department' : 'Edit Department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Department Name (e.g. Mechanical Engineering)')),
            const SizedBox(height: 12),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Department Code (e.g. ME)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && codeCtrl.text.isNotEmpty) {
                final collegeId = ref.read(activeCollegeIdProvider);
                if (existing == null) {
                  final newDept = Department(
                    id: 'dept_${codeCtrl.text.trim().toLowerCase()}_${const Uuid().v4().substring(0, 4)}',
                    collegeId: collegeId,
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim().toUpperCase(),
                  );
                  await ref.read(departmentControllerProvider.notifier).addDepartment(newDept);
                } else {
                  final updated = existing.copyWith(
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim().toUpperCase(),
                  );
                  await ref.read(departmentControllerProvider.notifier).updateDepartment(updated);
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
