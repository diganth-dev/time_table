import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

List<String> _parseBatches(String value) => value
    .split(RegExp(r'[,\n]'))
    .map((batch) => batch.trim())
    .where((batch) => batch.isNotEmpty)
    .toSet()
    .toList();

class SectionsScreen extends ConsumerWidget {
  const SectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(sectionListProvider);
    final depts = ref.watch(departmentListProvider).value ?? [];
    final courses = ref.watch(courseListProvider).value ?? [];
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
                      'Student Sections & Classes',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Manage class cohorts, semester levels, sections (A, B), and student counts for room capacity planning',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showSectionDialog(context, ref, null, depts, courses),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Section'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            sectionsAsync.when(
              data: (sections) {
                if (sections.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(
                        child: Text('No academic sections configured yet.'),
                      ),
                    ),
                  );
                }

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: DataTable(
                    columnSpacing: 24,
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF8FAFC),
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Department',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Semester',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Section',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Student Count',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Academic Year',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Actions',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: sections.map((sec) {
                      final deptCode = deptMap[sec.departmentId]?.code ?? 'CSE';
                      return DataRow(
                        cells: [
                          DataCell(
                            Chip(
                              label: Text(
                                deptCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text('Semester ${sec.semester}')),
                          DataCell(
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                sec.sectionName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${sec.studentCount} students',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(Text(sec.academicYear)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showSectionDialog(
                                    context,
                                    ref,
                                    sec,
                                    depts,
                                    courses,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Section?'),
                                        content: const Text(
                                          'Deleting this section will also remove its associated subjects and timetable entries.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.errorColor,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ref
                                          .read(
                                            sectionControllerProvider.notifier,
                                          )
                                          .deleteSection(sec.id);
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
              error: (e, _) => Text('Error loading sections: $e'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSectionDialog(
    BuildContext context,
    WidgetRef ref,
    Section? existing,
    List<Department> depts,
    List<Course> courses,
  ) {
    final semCtrl = TextEditingController(text: '${existing?.semester ?? 3}');
    final nameCtrl = TextEditingController(text: existing?.sectionName ?? 'A');
    final countCtrl = TextEditingController(
      text: '${existing?.studentCount ?? 60}',
    );
    final yearCtrl = TextEditingController(
      text: existing?.academicYear ?? '2026-2027',
    );
    final batchesCtrl = TextEditingController(
      text: existing?.batches.join(', ') ?? '',
    );
    String selectedDeptId =
        existing?.departmentId ?? (depts.isNotEmpty ? depts.first.id : '');
    String selectedCourseId =
        existing?.courseId ?? (courses.isNotEmpty ? courses.first.id : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Create Section' : 'Edit Section'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedDeptId,
                decoration: const InputDecoration(labelText: 'Department'),
                items: depts
                    .map(
                      (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedDeptId = val);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: semCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Semester (e.g. 3)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Section Name (e.g. A, B)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Student Count (Used for room capacity check)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearCtrl,
                decoration: const InputDecoration(
                  labelText: 'Academic Year (e.g. 2026-2027)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lab batches (comma-separated)',
                  hintText: 'e.g. B1, B2, B3',
                  helperText: 'Leave empty if this section has no lab batches.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final collegeId = ref.read(activeCollegeIdProvider);
                final sem = int.tryParse(semCtrl.text) ?? 1;
                final count = int.tryParse(countCtrl.text) ?? 30;

                if (existing == null) {
                  final newSec = Section(
                    id: 'sec_${selectedDeptId.split('_').last}_${sem}_${nameCtrl.text.trim().toLowerCase()}_${const Uuid().v4().substring(0, 4)}',
                    collegeId: collegeId,
                    departmentId: selectedDeptId,
                    courseId: selectedCourseId,
                    academicYear: yearCtrl.text.trim(),
                    semester: sem,
                    sectionName: nameCtrl.text.trim().toUpperCase(),
                    studentCount: count,
                    batches: _parseBatches(batchesCtrl.text),
                  );
                  await ref
                      .read(sectionControllerProvider.notifier)
                      .addSection(newSec);
                } else {
                  final updated = existing.copyWith(
                    departmentId: selectedDeptId,
                    courseId: selectedCourseId,
                    academicYear: yearCtrl.text.trim(),
                    semester: sem,
                    sectionName: nameCtrl.text.trim().toUpperCase(),
                    studentCount: count,
                    batches: _parseBatches(batchesCtrl.text),
                  );
                  await ref
                      .read(sectionControllerProvider.notifier)
                      .updateSection(updated);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Section'),
            ),
          ],
        ),
      ),
    );
  }
}
