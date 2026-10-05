import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(courseListProvider);
    final depts = ref.watch(departmentListProvider).value ?? [];
    final deptMap = {for (var d in depts) d.id: d};

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
                      'Programs & Degree Courses',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Create and manage B.E., B.Tech, BCA, MCA and degree durations',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCourseDialog(context, ref, null, depts),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Degree / Program'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            coursesAsync.when(
              data: (courses) {
                if (courses.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: Text('No courses created yet.')),
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
                      DataColumn(label: Text('Program Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Total Semesters', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: courses.map((c) {
                      final deptName = deptMap[c.departmentId]?.code ?? 'General';
                      return DataRow(
                        cells: [
                          DataCell(Chip(label: Text(c.code, style: const TextStyle(fontWeight: FontWeight.bold)))),
                          DataCell(Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(deptName)),
                          DataCell(Text('${c.durationYears} Years')),
                          DataCell(Text('${c.totalSemesters} Semesters')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showCourseDialog(context, ref, c, depts),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Course?'),
                                        content: Text('Remove ${c.name}?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ref.read(courseControllerProvider.notifier).deleteCourse(c.id);
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
              error: (e, _) => Text('Error loading courses: $e'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCourseDialog(BuildContext context, WidgetRef ref, Course? existing, List<Department> depts) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final durationCtrl = TextEditingController(text: '${existing?.durationYears ?? 4}');
    final semCtrl = TextEditingController(text: '${existing?.totalSemesters ?? 8}');
    String selectedDeptId = existing?.departmentId ?? (depts.isNotEmpty ? depts.first.id : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Program / Degree' : 'Edit Program'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Program Name (e.g. B.Tech in CSE)')),
              const SizedBox(height: 12),
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Program Code (e.g. BT-CSE)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedDeptId,
                decoration: const InputDecoration(labelText: 'Department'),
                items: depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedDeptId = val);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration (Years)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: semCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Total Semesters'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && codeCtrl.text.isNotEmpty) {
                  final collegeId = ref.read(activeCollegeIdProvider);
                  final duration = int.tryParse(durationCtrl.text) ?? 4;
                  final totalSem = int.tryParse(semCtrl.text) ?? 8;

                  if (existing == null) {
                    final newCourse = Course(
                      id: 'course_${const Uuid().v4().substring(0, 8)}',
                      collegeId: collegeId,
                      departmentId: selectedDeptId,
                      name: nameCtrl.text.trim(),
                      code: codeCtrl.text.trim().toUpperCase(),
                      durationYears: duration,
                      totalSemesters: totalSem,
                    );
                    await ref.read(courseControllerProvider.notifier).addCourse(newCourse);
                  } else {
                    final updated = existing.copyWith(
                      name: nameCtrl.text.trim(),
                      code: codeCtrl.text.trim().toUpperCase(),
                      departmentId: selectedDeptId,
                      durationYears: duration,
                      totalSemesters: totalSem,
                    );
                    await ref.read(courseControllerProvider.notifier).updateCourse(updated);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
