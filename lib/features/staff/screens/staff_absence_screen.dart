import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';

class StaffAbsenceScreen extends ConsumerStatefulWidget {
  final Staff staff;

  const StaffAbsenceScreen({super.key, required this.staff});

  @override
  ConsumerState<StaffAbsenceScreen> createState() => _StaffAbsenceScreenState();
}

class _StaffAbsenceScreenState extends ConsumerState<StaffAbsenceScreen> {
  String _selectedDay = 'Monday';
  final _reasonCtrl = TextEditingController(text: 'Medical Leave');
  List<TimetableEntry> _affectedEntries = [];

  @override
  void initState() {
    super.initState();
    _checkImpact();
  }

  Future<void> _checkImpact() async {
    final db = ref.read(databaseRepositoryProvider);
    final collegeId = ref.read(activeCollegeIdProvider);

    final entries = await db.getTimetableEntries(
      collegeId,
      teacherId: widget.staff.id,
      status: 'published',
    );

    final affected = entries.where((e) => e.dayOfWeek == _selectedDay).toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    if (mounted) {
      setState(() {
        _affectedEntries = affected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final college = ref.watch(currentCollegeProvider).value;
    final workingDays = college?.workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final subjects = ref.watch(subjectListProvider).value ?? [];
    final staffList = ref.watch(staffListProvider).value ?? [];
    final rooms = ref.watch(roomListProvider).value ?? [];
    final sections = ref.watch(sectionListProvider).value ?? [];
    final availabilities = ref.watch(teacherAvailabilityProvider(null)).value ?? [];
    final allEntries = ref.watch(timetableEntriesProvider).value ?? [];

    final subMap = {for (var s in subjects) s.id: s};
    final secMap = {for (var s in sections) s.id: s};
    final roomMap = {for (var r in rooms) r.id: r};

    return Scaffold(
      appBar: AppBar(
        title: Text('Absence & Leave Impact: ${widget.staff.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mark Absence Date & Day', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedDay,
                            decoration: const InputDecoration(labelText: 'Day of Absence'),
                            items: workingDays.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDay = val);
                                _checkImpact();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _reasonCtrl,
                            decoration: const InputDecoration(labelText: 'Absence Reason'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final leave = TeacherAvailability(
                              id: const Uuid().v4(),
                              collegeId: widget.staff.collegeId,
                              teacherId: widget.staff.id,
                              dayOfWeek: _selectedDay,
                              periodNumber: 0, // All day
                              isAvailable: false,
                              isLeave: true,
                              leaveReason: _reasonCtrl.text.trim(),
                              leaveDate: DateTime.now(),
                            );
                            await ref.read(staffControllerProvider.notifier).markStaffLeave(leave);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Marked ${widget.staff.name} on leave for $_selectedDay.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Record Leave'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Affected Classes Impact Analysis
            Text(
              'Impact Analysis: ${_affectedEntries.length} Classes Affected on $_selectedDay',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            if (_affectedEntries.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text('No published classes affected on this day!'),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _affectedEntries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, idx) {
                  final entry = _affectedEntries[idx];
                  final sub = subMap[entry.subjectId];
                  final sec = secMap[entry.sectionId];
                  final room = roomMap[entry.roomId];

                  // System finds alternative qualified teachers available at this day and period
                  final alternatives = ConflictValidator.findReplacementTeachers(
                    collegeId: entry.collegeId,
                    subjectId: entry.subjectId,
                    dayOfWeek: entry.dayOfWeek,
                    periodNumber: entry.periodNumber,
                    allStaff: staffList,
                    allSubjects: subjects,
                    activeEntries: allEntries,
                    availabilities: availabilities,
                    excludeTeacherId: widget.staff.id,
                  );

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                    color: const Color(0xFFFEF2F2),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Period ${entry.periodNumber}: ${sub?.subjectName ?? "Subject"} (${sub?.subjectCode ?? ""})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF991B1B)),
                              ),
                              Chip(
                                label: Text('Sec: ${sec?.sectionName ?? ""} • Room: ${room?.roomNumber ?? ""}'),
                                backgroundColor: Colors.white,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Available Substitute Faculty Members (Qualified & Free at this period):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7F1D1D)),
                          ),
                          const SizedBox(height: 8),
                          if (alternatives.isEmpty)
                            const Text('No qualified substitute faculty available for this slot. Rescheduling recommended.')
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: alternatives.map((substitute) => ActionChip(
                                avatar: const Icon(Icons.swap_horiz, size: 16, color: Colors.white),
                                backgroundColor: AppTheme.secondaryColor,
                                label: Text(
                                  'Assign ${substitute.name}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                onPressed: () async {
                                  final updated = entry.copyWith(teacherId: substitute.id);
                                  await ref.read(timetableControllerProvider.notifier).forceSaveEntry(updated);
                                  _checkImpact();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Period ${entry.periodNumber} reassigned to ${substitute.name}!')),
                                    );
                                  }
                                },
                              )).toList(),
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
