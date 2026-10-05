import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';

class TimetableGenerateScreen extends ConsumerStatefulWidget {
  const TimetableGenerateScreen({super.key});

  @override
  ConsumerState<TimetableGenerateScreen> createState() => _TimetableGenerateScreenState();
}

class _TimetableGenerateScreenState extends ConsumerState<TimetableGenerateScreen> {
  final _versionNameController = TextEditingController();
  bool _isGenerating = false;
  GenerationResult? _lastResult;
  String? _selectedSectionId;

  @override
  void dispose() {
    _versionNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final college = ref.watch(currentCollegeProvider).value;
    final activeDaysAsync = ref.watch(workingDaysProvider);
    final activeDays = activeDaysAsync.value ?? college?.workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final sections = ref.watch(sectionListProvider).value ?? [];
    final subjects = ref.watch(subjectListProvider).value ?? [];
    final staffList = ref.watch(staffListProvider).value ?? [];
    final rooms = ref.watch(roomListProvider).value ?? [];
    final depts = ref.watch(departmentListProvider).value ?? [];
    final timeSlots = ref.watch(timeSlotsProvider).value ?? [];
    final academicSlots = timeSlots.where((s) => !s.isBreak).toList();

    final deptMap = {for (var d in depts) d.id: d};

    // Find selected section if any
    final selectedSection = _selectedSectionId != null
        ? sections.where((s) => s.id == _selectedSectionId).firstOrNull
        : null;

    final targetSubjects = selectedSection == null
        ? subjects
        : subjects.where((sub) {
            if (!sub.active) return false;
            if (sub.sectionId != null && sub.sectionId!.isNotEmpty) {
              return sub.sectionId == selectedSection.id;
            }
            final deptMatch = sub.departmentId.isEmpty || sub.departmentId == selectedSection.departmentId;
            final semMatch = sub.semester == selectedSection.semester;
            return deptMatch && semMatch;
          }).toList();

    final targetWeeklyHours = targetSubjects.fold<int>(0, (sum, s) => sum + s.hoursPerWeek);

    final result = _lastResult ?? ref.watch(lastGenerationResultProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Automated Timetable Generation Engine',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      selectedSection != null
                          ? 'Generating schedule for ${selectedSection.displayName} (coordinated with other classes to avoid conflicts)'
                          : 'Constraint Satisfaction Engine checking faculty availability, room capacity, labs, and breaks',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  onPressed: _isGenerating ? null : () => _executeGeneration(),
                  icon: _isGenerating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.play_arrow, size: 20),
                  label: Text(
                    _isGenerating
                        ? 'Calculating Optimal Schedule...'
                        : (selectedSection != null
                            ? 'GENERATE FOR SECTION ${selectedSection.sectionName}'
                            : 'GENERATE ALL TIMETABLES'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Class / Section Selection Scope Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: const Icon(Icons.groups, color: AppTheme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scheduling Scope & Class Selection',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'Generate a timetable for one selected class/section at a time, or generate for all classes together.',
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      key: ValueKey(_selectedSectionId),
                      initialValue: _selectedSectionId,
                      decoration: InputDecoration(
                        labelText: 'Select Target Class / Section',
                        prefixIcon: const Icon(Icons.class_, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'All Sections (Entire College Simultaneous Schedule)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...sections.map((sec) {
                          final deptCode = deptMap[sec.departmentId]?.code ?? 'Dept';
                          return DropdownMenuItem<String?>(
                            value: sec.id,
                            child: Text(
                              '${sec.displayName} ($deptCode • Sem ${sec.semester} • Sec ${sec.sectionName} • ${sec.studentCount} students)',
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedSectionId = val;
                          _lastResult = null;
                        });
                      },
                    ),
                    if (selectedSection != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Single Class Generation Active: ${selectedSection.displayName}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Scheduling ${targetSubjects.length} subjects ($targetWeeklyHours periods/week) for ${selectedSection.studentCount} students. Faculty and rooms occupied in other classes\' timetables are respected to guarantee 0 conflicts.',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Engine Input Verification Matrix
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedSection != null
                          ? 'Scheduling Constraints for ${selectedSection.displayName}'
                          : 'Active Scheduling Constraints & Inputs',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedSection != null
                          ? 'The engine will satisfy all weekly periods, room capacities, and teacher assignments for this class.'
                          : 'The engine will verify 10 hard constraints and optimize soft teacher/student preferences.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const Divider(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final count = constraints.maxWidth > 800 ? 4 : 2;
                        return GridView.count(
                          crossAxisCount: count,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 2.4,
                          children: selectedSection != null
                              ? [
                                  _paramChip('Target Section', selectedSection.displayName, Icons.groups, Colors.blue),
                                  _paramChip('Class Size', '${selectedSection.studentCount} Students', Icons.people, Colors.teal),
                                  _paramChip('Section Subjects', '${targetSubjects.length} Subjects', Icons.menu_book, Colors.amber),
                                  _paramChip('Required Periods', '$targetWeeklyHours / Week', Icons.schedule, Colors.deepOrange),
                                  _paramChip('Working Days', '${activeDays.length} Days', Icons.calendar_today, Colors.purple),
                                  _paramChip('Periods/Day', '${academicSlots.length} Periods', Icons.access_time, Colors.indigo),
                                  _paramChip('Operational Rooms', '${rooms.where((r) => !r.isUnderMaintenance).length}', Icons.meeting_room, Colors.brown),
                                  _paramChip('Constraint Rules', '10 Hard / 6 Soft', Icons.shield, Colors.green),
                                ]
                              : [
                                  _paramChip('Active Sections', '${sections.length}', Icons.groups, Colors.blue),
                                  _paramChip('Total Subjects', '${subjects.length}', Icons.menu_book, Colors.amber),
                                  _paramChip('Faculty Members', '${staffList.length}', Icons.badge, Colors.teal),
                                  _paramChip('Operational Rooms', '${rooms.where((r) => !r.isUnderMaintenance).length}', Icons.meeting_room, Colors.indigo),
                                  _paramChip('Working Days', '${activeDays.length} Days', Icons.calendar_today, Colors.purple),
                                  _paramChip('Academic Periods', '${academicSlots.length} Periods/Day', Icons.schedule, Colors.deepOrange),
                                  _paramChip('Breaks Configured', '${timeSlots.length - academicSlots.length} Breaks', Icons.coffee, Colors.brown),
                                  _paramChip('Constraint Rules', '10 Hard / 6 Soft', Icons.shield, Colors.green),
                                ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Generation Results Display
            if (result != null) ...[
              if (result.isSuccess)
                _buildSuccessCard(context, result, sections)
              else
                _buildConflictCard(context, result),
            ],
          ],
        ),
      ),
    );
  }

  Widget _paramChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(BuildContext context, GenerationResult result, List<Section> sections) {
    final targetSec = result.targetSectionId != null
        ? sections.where((s) => s.id == result.targetSectionId).firstOrNull
        : null;

    final title = targetSec != null
        ? 'Timetable for ${targetSec.displayName} Generated Successfully!'
        : 'Timetable Generated Successfully!';

    final desc = targetSec != null
        ? 'All hard constraints satisfied for ${targetSec.displayName}. Complete conflict-free schedule generated in ${result.generationTimeMs}ms.'
        : 'All hard constraints satisfied. Complete conflict-free schedule generated in ${result.generationTimeMs}ms.';

    return Card(
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF86EFAC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                      Text(
                        desc,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF14532D)),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (result.targetSectionId != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF166534),
                          side: const BorderSide(color: Color(0xFF16A34A)),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedSectionId = null;
                            _lastResult = null;
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Schedule Another Class'),
                      ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      onPressed: () {
                        if (result.targetSectionId != null) {
                          ref.read(selectedSectionFilterProvider.notifier).state = result.targetSectionId;
                        }
                        context.go('/timetable');
                      },
                      icon: const Icon(Icons.table_chart, size: 18),
                      label: Text(targetSec != null ? 'View ${targetSec.sectionName} Timetable' : 'View Timetable'),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth > 1100 ? 5 : (constraints.maxWidth > 650 ? 3 : 2);
                return GridView.count(
                  crossAxisCount: count,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: constraints.maxWidth > 1100
                      ? 1.9
                      : (constraints.maxWidth > 650 ? 2.0 : 2.2),
                  children: [
                    StatCard(title: 'CLASSES SCHEDULED', value: '${result.totalClassesScheduled}', icon: Icons.schedule, iconColor: Colors.green),
                    StatCard(title: 'TEACHERS UTILIZED', value: '${result.teachersUsed}', icon: Icons.person, iconColor: Colors.blue),
                    StatCard(title: 'ROOMS ALLOCATED', value: '${result.roomsUsed}', icon: Icons.meeting_room, iconColor: Colors.indigo),
                    StatCard(title: 'SECTIONS SCHEDULED', value: '${result.sectionsScheduled}', icon: Icons.groups, iconColor: Colors.purple),
                    StatCard(title: 'CONFLICTS DETECTED', value: '0', icon: Icons.verified, iconColor: Colors.teal),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictCard(BuildContext context, GenerationResult result) {
    return Card(
      color: const Color(0xFFFEF2F2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFCA5A5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Timetable could not be completely generated.',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.errorColor),
                      ),
                      Text(
                        '${result.conflicts.length} conflict(s) encountered during constraint satisfaction search.',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                  onPressed: () => context.go('/conflicts'),
                  icon: const Icon(Icons.rule_folder, size: 18),
                  label: const Text('Resolve in Conflict Center'),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'Exact Diagnostic Reasons:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF991B1B)),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: result.conflicts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final c = result.conflicts[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Conflict #${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(c.description, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                      if (c.suggestion != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Suggestion: ${c.suggestion}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeGeneration() async {
    setState(() => _isGenerating = true);
    try {
      final res = await ref.read(timetableControllerProvider.notifier).generateSchedule(
        customVersionName: _versionNameController.text.isNotEmpty ? _versionNameController.text.trim() : null,
        targetSectionId: _selectedSectionId,
      );
      if (mounted) {
        setState(() {
          _lastResult = res;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    }
  }
}
