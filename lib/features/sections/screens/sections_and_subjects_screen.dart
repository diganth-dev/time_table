import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/workflow_progress_bar.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class SectionsAndSubjectsScreen extends ConsumerStatefulWidget {
  const SectionsAndSubjectsScreen({super.key});

  @override
  ConsumerState<SectionsAndSubjectsScreen> createState() =>
      _SectionsAndSubjectsScreenState();
}

class _SectionsAndSubjectsScreenState
    extends ConsumerState<SectionsAndSubjectsScreen> {
  String? _selectedSectionId;
  static const _uuid = Uuid();

  List<String> _parseBatches(String value) => value
      .split(RegExp(r'[,\n]'))
      .map((batch) => batch.trim())
      .where((batch) => batch.isNotEmpty)
      .toSet()
      .toList();

  @override
  Widget build(BuildContext context) {
    final sections = ref.watch(sectionListProvider).value ?? [];
    final subjects = ref.watch(subjectListProvider).value ?? [];
    final staffList = ref.watch(staffListProvider).value ?? [];
    final depts = ref.watch(departmentListProvider).value ?? [];
    final college = ref.watch(currentCollegeProvider).value;

    final staffMap = {for (var s in staffList) s.id: s};
    final deptMap = {for (var d in depts) d.id: d};

    if (_selectedSectionId == null && sections.isNotEmpty) {
      _selectedSectionId = sections.first.id;
    }

    final selectedSection =
        sections.where((s) => s.id == _selectedSectionId).firstOrNull ??
        sections.firstOrNull;

    // Filter subjects for the selected section (prioritizing direct sectionId binding)
    final sectionSubjects = selectedSection == null
        ? <Subject>[]
        : subjects.where((sub) {
            if (sub.sectionId != null && sub.sectionId!.isNotEmpty) {
              return sub.sectionId == selectedSection.id;
            }
            final deptMatch =
                sub.departmentId.isEmpty ||
                sub.departmentId == selectedSection.departmentId;
            final semMatch = sub.semester == selectedSection.semester;
            return deptMatch && semMatch;
          }).toList();

    final totalWeeklyHours = sectionSubjects.fold<int>(
      0,
      (sum, sub) => sum + sub.hoursPerWeek,
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkflowProgressBar(
              currentStep: WorkflowStep.sectionsAndSubjects,
            ),
            const SizedBox(height: 20),

            // Top Bar
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 800;
                final titleColumn = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sections & Subjects Configuration',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Define class sections (A, B, C) and assign weekly subjects, assigned professors, and required periods',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showAddSectionDialog(
                        context,
                        college?.id ?? ref.read(activeCollegeIdProvider),
                        depts,
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Section'),
                    ),
                    ElevatedButton.icon(
                      onPressed: selectedSection == null
                          ? null
                          : () => _showAddSubjectDialog(
                              context,
                              college?.id ?? ref.read(activeCollegeIdProvider),
                              selectedSection,
                              staffList,
                              null,
                            ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Subject to Section'),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleColumn,
                      const SizedBox(height: 12),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleColumn),
                    const SizedBox(width: 16),
                    actionButtons,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Section Selector Chips / Tabs
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Academic Section',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (sections.isEmpty)
                      const Text(
                        'No sections configured. Click "Add Section" to create Section A, B, or C.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: sections.map((sec) {
                          final isSelected = sec.id == _selectedSectionId;
                          final deptCode =
                              deptMap[sec.departmentId]?.code ?? 'CSE';
                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sec ${sec.sectionName}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$deptCode Sem ${sec.semester}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryColor,
                            onSelected: (_) =>
                                setState(() => _selectedSectionId = sec.id),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Active Section Header & Summary Card
            if (selectedSection != null) ...[
              Card(
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.primaryColor,
                              child: Text(
                                selectedSection.sectionName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Section ${selectedSection.sectionName} — Semester ${selectedSection.semester} (${deptMap[selectedSection.departmentId]?.name ?? "Department"})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Cohort Size: ${selectedSection.studentCount} Students • Academic Year: ${selectedSection.academicYear}',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(
                              Icons.meeting_room_outlined,
                              size: 16,
                            ),
                            label: const Text('Configure Room/Lab Requirements'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(color: Color(0xFFC7D2FE)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () => _showRoomLabRequirementsDialog(
                              context,
                              selectedSection,
                              sectionSubjects,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            tooltip: 'Configure Lab Batches',
                            onPressed: () => _showBatchConfigurationDialog(
                              context,
                              selectedSection,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFC7D2FE),
                              ),
                            ),
                            child: Text(
                              'Total: $totalWeeklyHours Required Periods / Week',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            tooltip: 'Delete Section',
                            onPressed: () =>
                                _confirmDeleteSection(context, selectedSection),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Subjects Table for this Section
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Subjects Assigned to Section ${selectedSection.sectionName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${sectionSubjects.length} subjects registered',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (sectionSubjects.any(
                        (s) => !s.isLab && s.assignedTeacherIds.isEmpty,
                      ))
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFDC2626),
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Incomplete Subjects Detected: Every subject must have an assigned professor. Subjects marked "INCOMPLETE" will prevent timetable generation.',
                                  style: TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (sectionSubjects.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(
                                Icons.menu_book_outlined,
                                size: 48,
                                color: Color(0xFFCBD5E1),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No subjects assigned to Section ${selectedSection.sectionName} yet.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Click "Add Subject to Section" above to add subjects for this section.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                          columnSpacing: 24,
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC),
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Code',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Subject Name',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Type',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Periods / Week',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Assigned Professor',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Facility Required',
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
                          rows: sectionSubjects.map((sub) {
                            final assignedNames = sub.assignedTeacherIds
                                .map((id) => staffMap[id]?.name ?? id)
                                .join(', ');

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    sub.subjectCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(sub.subjectName),
                                      if (sub.courseShortName != null &&
                                          sub.courseShortName!.isNotEmpty)
                                        Text(
                                          'Short Name: ${sub.courseShortName}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      sub.subjectType,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: sub.isLab
                                        ? Colors.indigo.shade50
                                        : Colors.teal.shade50,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${sub.hoursPerWeek} periods',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (sub.isLab)
                                        const Text(
                                          ' (2-hr blocks)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  sub.assignedTeacherIds.isEmpty
                                      ? (sub.isLab
                                          ? const Text(
                                              'None',
                                              style: TextStyle(
                                                color: Color(0xFF64748B),
                                                fontStyle: FontStyle.italic,
                                              ),
                                            )
                                          : Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEE2E2),
                                                borderRadius: BorderRadius.circular(
                                                  6,
                                                ),
                                                border: Border.all(
                                                  color: const Color(0xFFFCA5A5),
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.error_outline,
                                                    size: 14,
                                                    color: Color(0xFFDC2626),
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'INCOMPLETE: No Professor',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFFDC2626),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ))
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.person,
                                              size: 14,
                                              color: Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                assignedNames,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      sub.requiredRoomType,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () => _showAddSubjectDialog(
                                          context,
                                          college?.id ??
                                              ref.read(activeCollegeIdProvider),
                                          selectedSection,
                                          staffList,
                                          sub,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _confirmDeleteSubject(context, sub),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 48,
                    horizontal: 24,
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.class_outlined,
                          size: 52,
                          color: Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No sections created yet.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Click "Add Section" to create your first class section.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddSectionDialog(
                            context,
                            college?.id ?? ref.read(activeCollegeIdProvider),
                            depts,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Section'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Step Navigation Controls
            WorkflowBottomBar(
              backLabel: '← Professors',
              onBack: () => context.go('/professors'),
              nextLabel: 'Continue to Rooms & Labs →',
              onNext: () async {
                final curSections = ref.read(sectionListProvider).value ?? [];
                if (curSections.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please add at least one section before proceeding.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final curSubjects = ref.read(subjectListProvider).value ?? [];
                if (curSubjects.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please add at least one subject before proceeding.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final staff = ref.read(staffListProvider).value ?? [];
                final staffMap = {for (var s in staff) s.id: s};

                final unassigned = curSubjects
                    .where((s) => !s.isLab && s.assignedTeacherIds.isEmpty)
                    .toList();
                if (unassigned.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Incomplete Subject: "${unassigned.first.subjectName}" is missing an assigned professor. Every theory subject must have an assigned professor.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final ineligible = curSubjects.where((sub) {
                  if (sub.assignedTeacherIds.isEmpty) return false;
                  final p = staffMap[sub.assignedTeacherIds.first];
                  if (p == null || !p.active || p.status == 'inactive') {
                    return true;
                  }
                  return !p.isEligibleForSubject(
                    subjectName: sub.subjectName,
                    subjectCode: sub.subjectCode,
                    courseShortName: sub.courseShortName,
                    subjectId: sub.id,
                  );
                }).toList();

                if (ineligible.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Eligibility Violation: Assigned professor for "${ineligible.first.subjectName}" is not eligible under Can Teach rules.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                context.go('/rooms');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBatchConfigurationDialog(BuildContext context, Section section) {
    final batchesCtrl = TextEditingController(text: section.batches.join(', '));
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Lab Batches — Section ${section.sectionName}'),
        content: TextField(
          controller: batchesCtrl,
          decoration: const InputDecoration(
            labelText: 'Batch names (comma-separated)',
            hintText: 'e.g. B1, B2, B3',
            helperText:
                'Leave empty when the section has no parallel lab batches.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final batches = _parseBatches(batchesCtrl.text);
              await ref
                  .read(sectionControllerProvider.notifier)
                  .updateSection(section.copyWith(batches: batches));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRoomLabRequirementsDialog(
    BuildContext context,
    Section section,
    List<Subject> sectionSubjects,
  ) {
    final allRooms = ref.read(roomListProvider).value ?? [];
    final activeRooms =
        allRooms.where((r) => r.active && !r.isUnderMaintenance).toList();
    final classrooms = activeRooms
        .where((r) => !r.isLab && r.roomType == 'Classroom')
        .toList();
    final labRooms =
        activeRooms.where((r) => r.isLab || r.roomType != 'Classroom').toList();
    final labSubjects = sectionSubjects.where((s) => s.isLab).toList();

    final selectedClassrooms = Set<String>.from(section.eligibleClassroomIds);
    final subjectEligibleLabs = <String, Set<String>>{};
    for (final sub in labSubjects) {
      subjectEligibleLabs[sub.id] = Set<String>.from(sub.eligibleLabIds);
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.meeting_room,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Room/Lab Requirements — Section ${section.sectionName}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: (MediaQuery.of(context).size.width - 48).clamp(0.0, 640.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Color(0xFF475569),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rooms and Labs are global college resources. Selected options below are references to the global master data (no duplicate physical rooms are created).',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CLASSROOM REQUIREMENTS
                    const Row(
                      children: [
                        Icon(
                          Icons.school,
                          size: 18,
                          color: Color(0xFF0F172A),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'CLASSROOM REQUIREMENTS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select which global classrooms this section may use for theory classes. Leave all unchecked to allow any compatible global classroom.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    if (classrooms.isEmpty)
                      const Text(
                        'No classrooms found in Rooms & Labs.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF94A3B8),
                        ),
                      )
                    else
                      ...classrooms.map((room) {
                        final isChecked = selectedClassrooms.contains(room.id);
                        return CheckboxListTile(
                          dense: true,
                          value: isChecked,
                          title: Text(
                            room.roomNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'Capacity: ${room.capacity} seats • Building: ${room.building}, Floor ${room.floor}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedClassrooms.add(room.id);
                              } else {
                                selectedClassrooms.remove(room.id);
                              }
                            });
                          },
                        );
                      }),

                    const Divider(height: 32),

                    // LAB REQUIREMENTS
                    const Row(
                      children: [
                        Icon(
                          Icons.science,
                          size: 18,
                          color: Color(0xFF0F172A),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'LAB REQUIREMENTS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Configure compatible global laboratories for each lab subject belonging to this section. Selected labs are references to global master records.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    if (labSubjects.isEmpty)
                      const Text(
                        'No lab subjects found for this section. Add lab subjects under this section first.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF94A3B8),
                        ),
                      )
                    else
                      ...labSubjects.map((sub) {
                        final assignedLabIds =
                            subjectEligibleLabs[sub.id] ?? <String>{};
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          color: const Color(0xFFFAFAFA),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sub.subjectName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        sub.requiredRoomType,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.blue.shade50,
                                    ),
                                  ],
                                ),
                                Text(
                                  'Required: ${sub.hoursPerWeek} periods/week (${sub.consecutivePeriods}-period block) • Code: ${sub.subjectCode}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Compatible venues:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                CheckboxListTile(
                                  dense: true,
                                  value: assignedLabIds.any((id) =>
                                      id.toLowerCase() == 'class' ||
                                      id.toLowerCase() == 'classroom'),
                                  title: const Text(
                                    'Class',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Allow conducting in a normal classroom instead of requiring a physical laboratory',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      subjectEligibleLabs.putIfAbsent(
                                        sub.id,
                                        () => <String>{},
                                      );
                                      if (val == true) {
                                        subjectEligibleLabs[sub.id]!.add(
                                          Subject.classVenueId,
                                        );
                                      } else {
                                        subjectEligibleLabs[sub.id]!.removeWhere(
                                          (id) =>
                                              id.toLowerCase() == 'class' ||
                                              id.toLowerCase() == 'classroom',
                                        );
                                      }
                                    });
                                  },
                                ),
                                if (labRooms.isEmpty)
                                  const Text(
                                    'No specialized laboratories configured in Rooms & Labs.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  )
                                else
                                  ...labRooms.map((room) {
                                    final isChecked =
                                        assignedLabIds.contains(room.id);
                                    final compStr = room
                                            .compatibleSubjects.isNotEmpty
                                        ? ' • Compatible: ${room.compatibleSubjects.join(", ")}'
                                        : '';
                                    return CheckboxListTile(
                                      dense: true,
                                      value: isChecked,
                                      title: Text(
                                        room.roomNumber,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Facility: ${room.roomType} • Capacity: ${room.capacity} seats$compStr',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          subjectEligibleLabs.putIfAbsent(
                                            sub.id,
                                            () => <String>{},
                                          );
                                          if (val == true) {
                                            subjectEligibleLabs[sub.id]!
                                                .add(room.id);
                                          } else {
                                            subjectEligibleLabs[sub.id]!
                                                .remove(room.id);
                                          }
                                        });
                                      },
                                    );
                                  }),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // 1. Update section with eligibleClassroomIds
                  await ref
                      .read(sectionControllerProvider.notifier)
                      .updateSection(
                        section.copyWith(
                          eligibleClassroomIds: selectedClassrooms.toList(),
                        ),
                      );

                  // 2. Update each lab subject with eligibleLabIds
                  for (final sub in labSubjects) {
                    final selectedLabs =
                        subjectEligibleLabs[sub.id]?.toList() ?? <String>[];
                    await ref
                        .read(subjectControllerProvider.notifier)
                        .updateSubject(
                          sub.copyWith(eligibleLabIds: selectedLabs),
                        );
                  }

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Room/Lab requirements saved for Section ${section.sectionName}.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text('Save Requirements'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddSectionDialog(
    BuildContext context,
    String collegeId,
    List<Department> depts,
  ) {
    final nameCtrl = TextEditingController(text: '');
    final countCtrl = TextEditingController(text: '');
    final batchesCtrl = TextEditingController(text: '');
    var semester = 1;
    var deptId = depts.isNotEmpty ? depts.first.id : 'dept_default';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Add Section'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Section Name',
                  hintText: 'e.g. A, B, C',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Student Count',
                  hintText: 'e.g. 60',
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
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: semester,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: List.generate(8, (i) => i + 1)
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text('Semester $s'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setDlgState(() => semester = val ?? 1),
              ),
              const SizedBox(height: 12),
              if (depts.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: deptId,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: depts
                      .map(
                        (d) =>
                            DropdownMenuItem(value: d.id, child: Text(d.name)),
                      )
                      .toList(),
                  onChanged: (val) => setDlgState(() => deptId = val ?? deptId),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter Section Name (e.g. A)'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final newSec = Section(
                  id: 'sec_${_uuid.v4().substring(0, 8)}',
                  collegeId: collegeId,
                  departmentId: deptId,
                  courseId: 'course_default',
                  academicYear: '2026-2027',
                  semester: semester,
                  sectionName: nameCtrl.text.trim().toUpperCase(),
                  studentCount: int.tryParse(countCtrl.text.trim()) ?? 0,
                  batches: _parseBatches(batchesCtrl.text),
                );
                try {
                  await ref
                      .read(sectionControllerProvider.notifier)
                      .addSection(newSec);
                  setState(() => _selectedSectionId = newSec.id);
                  setDlgState(() {
                    nameCtrl.clear();
                    countCtrl.clear();
                    batchesCtrl.clear();
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Section ${newSec.sectionName} added! Enter another section or click Save & Close.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add section: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add Another'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final newSec = Section(
                  id: 'sec_${_uuid.v4().substring(0, 8)}',
                  collegeId: collegeId,
                  departmentId: deptId,
                  courseId: 'course_default',
                  academicYear: '2026-2027',
                  semester: semester,
                  sectionName: nameCtrl.text.trim().toUpperCase(),
                  studentCount: int.tryParse(countCtrl.text.trim()) ?? 0,
                  batches: _parseBatches(batchesCtrl.text),
                );
                try {
                  await ref
                      .read(sectionControllerProvider.notifier)
                      .addSection(newSec);
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() => _selectedSectionId = newSec.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Section ${newSec.sectionName} added successfully.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add section: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save & Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubjectDialog(
    BuildContext context,
    String collegeId,
    Section section,
    List<Staff> staffList,
    Subject? existing,
  ) {
    final codeCtrl = TextEditingController(text: existing?.subjectCode ?? '');
    final shortNameCtrl = TextEditingController(
      text: existing?.courseShortName ?? '',
    );
    final nameCtrl = TextEditingController(text: existing?.subjectName ?? '');
    final hoursCtrl = TextEditingController(
      text: existing != null ? '${existing.hoursPerWeek}' : '',
    );
    var type = existing?.subjectType ?? 'Theory';
    var roomType = existing?.requiredRoomType ?? 'Classroom';
    var selectedTeacherId = existing?.assignedTeacherIds.firstOrNull ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final liveStaffList =
              ref.watch(staffListProvider).asData?.value ?? staffList;
          return StatefulBuilder(
            builder: (context, setDlgState) {
              final isLab = type.trim().toLowerCase() == 'lab' ||
                  roomType.trim().toLowerCase().contains('lab');
              final enteredName = nameCtrl.text.trim();
              final enteredCode = codeCtrl.text.trim();
              final enteredShortName = shortNameCtrl.text.trim();

              // Evaluate professor eligibility:
              // 1. If a professor has an empty "Can Teach" list -> eligible for any subject.
              // 2. If a professor has a non-empty list -> eligible if ANY meaningful
              // token matches subject name, code, short name, or matches acronym/abbreviation/fuzzy spelling.
              final eligibleProfessors = liveStaffList.where((staff) {
                if (!staff.active || staff.status == 'inactive') return false;
                return staff.isEligibleForSubject(
                  subjectName: enteredName,
                  subjectCode: enteredCode,
                  courseShortName: enteredShortName,
                  subjectId: existing?.id,
                );
              }).toList();



              final isSelectedTeacherEligible = eligibleProfessors.any(
                (p) => p.id == selectedTeacherId,
              );
              if (selectedTeacherId.isNotEmpty && !isSelectedTeacherEligible) {
                selectedTeacherId = '';
              }

          return AlertDialog(
            title: Text(
              existing == null
                  ? 'Add Subject to Section ${section.sectionName}'
                  : 'Edit Subject',
            ),
            content: SizedBox(
              width: (MediaQuery.of(context).size.width - 48).clamp(0.0, 520.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subject Code',
                        hintText: 'e.g. CS101',
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: shortNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Course Short Name (Optional)',
                        hintText: 'e.g. DVL, DBMS, OS',
                        helperText:
                            'Displayed inside timetable cells. Defaults to Subject Code if empty.',
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subject Name',
                        hintText: 'e.g. Data Structures',
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: type,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                            ),
                            items: ['Theory', 'Lab', 'Tutorial', 'Seminar']
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setDlgState(() {
                                type = val ?? 'Theory';
                                if (type == 'Lab') {
                                  roomType = 'Computer Lab';
                                } else {
                                  roomType = 'Classroom';
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: hoursCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Required Periods/Week',
                              hintText: 'e.g. 4',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: roomType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Required Room / Lab Facility',
                      ),
                      items:
                          [
                                'Classroom',
                                'Computer Lab',
                                'Electronics Lab',
                                'Physics Lab',
                                'Workshop',
                              ]
                              .map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              )
                              .toList(),
                      onChanged: (val) =>
                          setDlgState(() => roomType = val ?? 'Classroom'),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      isLab
                          ? 'Assigned Professor / Lab Assistant (Optional)'
                          : 'Assigned Professor',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),

                    if (liveStaffList.isEmpty) ...[
                      if (!isLab) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_off_outlined,
                                color: Color(0xFFDC2626),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'No professors added yet. Add a professor first.',
                                  style: TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  context.go('/professors');
                                },
                                child: const Text('Add Professor'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No professors registered yet. Assigned professor is optional for Lab subjects.',
                                  style: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else if (eligibleProfessors.isEmpty) ...[
                      if (!isLab) ...[
                        if (enteredName.isEmpty &&
                            enteredCode.isEmpty &&
                            enteredShortName.isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF0284C7),
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Enter a Subject Name or Code above to see eligible professors based on their Can Teach subjects.',
                                    style: TextStyle(
                                      color: Color(0xFF0369A1),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFD97706),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No eligible professor available for "${enteredName.isNotEmpty ? enteredName : enteredCode}". All registered professors have restricted "Can Teach" lists that do not match this subject. Update a professor\'s "Subjects they can teach" or add a professor with general availability.',
                                    style: const TextStyle(
                                      color: Color(0xFF92400E),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'prof_${selectedTeacherId}_${eligibleProfessors.length}_lab_empty',
                          ),
                          initialValue: '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText:
                                'Assigned Professor / Lab Assistant (Optional)',
                            helperText:
                                'No eligible professors available — lab will be saved without an instructor',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text('None (No instructor assigned)'),
                            ),
                          ],
                          onChanged: (val) =>
                              setDlgState(() => selectedTeacherId = val ?? ''),
                        ),
                      ],
                    ] else ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'prof_${selectedTeacherId}_${eligibleProfessors.length}_${isLab ? "lab" : "theory"}',
                        ),
                        initialValue: isSelectedTeacherEligible
                            ? selectedTeacherId
                            : (isLab ? '' : null),
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: isLab
                              ? 'Select Assigned Professor / Lab Assistant (Optional)'
                              : 'Select Eligible Professor *',
                          helperText: isLab
                              ? 'Optional — select an instructor or leave as None'
                              : '${eligibleProfessors.length} eligible professor(s) available',
                          border: const OutlineInputBorder(),
                        ),
                        hint: Text(
                          isLab
                              ? 'None (No instructor)'
                              : 'Choose a professor',
                        ),
                        selectedItemBuilder: (BuildContext context) {
                          if (isLab) {
                            return [
                              const Text(
                                'None (No instructor assigned)',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              ...eligibleProfessors.map<Widget>((s) {
                                return Text(
                                  s.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                );
                              }),
                            ];
                          }
                          return eligibleProfessors.map<Widget>((s) {
                            return Text(
                              s.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            );
                          }).toList();
                        },
                        items: [
                          if (isLab)
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('None (No instructor assigned)'),
                            ),
                          ...eligibleProfessors.map((s) {
                            final canTeachNote = s.subjectsCanTeach.isEmpty
                                ? 'All Subjects'
                                : s.subjectsCanTeach.join(', ');
                            final designationStr = s.designation.isNotEmpty
                                ? ' (${s.designation})'
                                : '';
                            return DropdownMenuItem<String>(
                              value: s.id,
                              child: Text(
                                '${s.name}$designationStr — Can teach: $canTeachNote',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) =>
                            setDlgState(() => selectedTeacherId = val ?? ''),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              if (existing == null)
                OutlinedButton(
                  onPressed: (!isLab && (liveStaffList.isEmpty || eligibleProfessors.isEmpty))
                      ? null
                      : () async {
                          if (codeCtrl.text.trim().isEmpty ||
                              nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter Subject Name and Code',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (!isLab && selectedTeacherId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select an eligible professor for this subject',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final shortNameVal = shortNameCtrl.text.trim();
                          final subject = Subject(
                            id: 'sub_${_uuid.v4().substring(0, 8)}',
                            collegeId: collegeId,
                            sectionId: section.id,
                            departmentId: section.departmentId,
                            courseId: section.courseId,
                            semester: section.semester,
                            subjectCode: codeCtrl.text.trim().toUpperCase(),
                            courseShortName: shortNameVal.isNotEmpty
                                ? shortNameVal
                                : null,
                            subjectName: nameCtrl.text.trim(),
                            subjectType: type,
                            hoursPerWeek:
                                int.tryParse(hoursCtrl.text.trim()) ?? 4,
                            requiredRoomType: roomType,
                            assignedTeacherIds: selectedTeacherId.isNotEmpty
                                ? [selectedTeacherId]
                                : [],
                            consecutivePeriods: isLab ? 2 : 1,
                          );

                          try {
                            await ref
                                .read(subjectControllerProvider.notifier)
                                .addSubject(subject);
                            setDlgState(() {
                              codeCtrl.clear();
                              shortNameCtrl.clear();
                              nameCtrl.clear();
                              hoursCtrl.clear();
                              selectedTeacherId = '';
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Subject added! Enter another subject or click Save & Close.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save subject: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: const Text('Add Another'),
                ),
              ElevatedButton(
                onPressed: (!isLab && (liveStaffList.isEmpty || eligibleProfessors.isEmpty))
                    ? null
                    : () async {
                        if (codeCtrl.text.trim().isEmpty ||
                            nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter Subject Name and Code',
                              ),
                            ),
                          );
                          return;
                        }
                        if (!isLab && selectedTeacherId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select an eligible professor for this subject',
                              ),
                            ),
                          );
                          return;
                        }

                        final shortNameVal = shortNameCtrl.text.trim();
                        final subject = Subject(
                          id:
                              existing?.id ??
                              'sub_${_uuid.v4().substring(0, 8)}',
                          collegeId: collegeId,
                          sectionId: section.id,
                          departmentId: section.departmentId,
                          courseId: section.courseId,
                          semester: section.semester,
                          subjectCode: codeCtrl.text.trim().toUpperCase(),
                          courseShortName: shortNameVal.isNotEmpty
                              ? shortNameVal
                              : null,
                          subjectName: nameCtrl.text.trim(),
                          subjectType: type,
                          hoursPerWeek:
                              int.tryParse(hoursCtrl.text.trim()) ?? 4,
                          requiredRoomType: roomType,
                          assignedTeacherIds: selectedTeacherId.isNotEmpty
                              ? [selectedTeacherId]
                              : [],
                          consecutivePeriods: isLab ? 2 : 1,
                          eligibleLabIds: existing?.eligibleLabIds,
                        );

                        try {
                          if (existing == null) {
                            await ref
                                .read(subjectControllerProvider.notifier)
                                .addSubject(subject);
                          } else {
                            await ref
                                .read(subjectControllerProvider.notifier)
                                .updateSubject(subject);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  existing == null
                                      ? 'Subject added successfully.'
                                      : 'Subject updated successfully.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save subject: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: Text(existing == null ? 'Save & Close' : 'Save Changes'),
              ),
            ],
          );
        },
      );
    },
  ),
);
  }

  void _confirmDeleteSection(BuildContext context, Section section) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section?'),
        content: const Text(
          'Deleting this section will also remove its associated subjects and timetable entries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref
                    .read(sectionControllerProvider.notifier)
                    .deleteSection(section.id);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _selectedSectionId = null);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Section ${section.sectionName} deleted.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete section: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubject(BuildContext context, Subject subject) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${subject.subjectName}?'),
        content: Text(
          'Are you sure you want to remove ${subject.subjectName} (${subject.subjectCode})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref
                    .read(subjectControllerProvider.notifier)
                    .deleteSubject(subject.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Subject ${subject.subjectName} deleted.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete subject: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
