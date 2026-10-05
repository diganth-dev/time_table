import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/workflow_progress_bar.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';

class InputWorkflowScreen extends ConsumerStatefulWidget {
  const InputWorkflowScreen({super.key});

  @override
  ConsumerState<InputWorkflowScreen> createState() => _InputWorkflowScreenState();
}

class _InputWorkflowScreenState extends ConsumerState<InputWorkflowScreen> {
  int _currentStep = 0;
  bool _isGenerating = false;
  GenerationResult? _generationResult;
  String? _generationError;

  @override
  Widget build(BuildContext context) {
    final college = ref.watch(currentCollegeProvider).value;
    final activeDaysAsync = ref.watch(workingDaysProvider);
    final activeDays = activeDaysAsync.value ?? college?.workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final staffList = ref.watch(staffListProvider).value ?? [];
    final sections = ref.watch(sectionListProvider).value ?? [];
    final subjects = ref.watch(subjectListProvider).value ?? [];
    final rooms = ref.watch(roomListProvider).value ?? [];
    final timeSlots = ref.watch(timeSlotsProvider).value ?? [];
    final academicSlots = timeSlots.where((s) => !s.isBreak).toList();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkflowProgressBar(currentStep: WorkflowStep.generate),
            const SizedBox(height: 20),

            // Top Bar
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 650;
                final titleCol = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timetable Generation Workflow',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '6-Step guided configuration process leading to automated constraint-satisfaction generation',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                );

                final topActionBtn = _currentStep == 5
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onPressed: _isGenerating ? null : () => _runGenerator(),
                        icon: _isGenerating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(_isGenerating ? 'Solving Constraints...' : 'GENERATE TIMETABLE'),
                      )
                    : const SizedBox.shrink();

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleCol,
                      if (_currentStep == 5) ...[
                        const SizedBox(height: 12),
                        topActionBtn,
                      ],
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleCol),
                    if (_currentStep == 5) ...[
                      const SizedBox(width: 16),
                      topActionBtn,
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Stepper Navigation Tabs
            _buildStepperTabs(),
            const SizedBox(height: 24),

            // Active Step Content
            _buildActiveStepContent(college, activeDays, staffList, sections, subjects, rooms, timeSlots, academicSlots),
            const SizedBox(height: 24),

            // Navigation Controls (Back / Next)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                final prevBtn = _currentStep > 0
                    ? OutlinedButton.icon(
                        onPressed: () => setState(() => _currentStep--),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Previous Step'),
                      )
                    : const SizedBox.shrink();

                final nextBtn = _currentStep < 5
                    ? ElevatedButton.icon(
                        onPressed: () => setState(() => _currentStep++),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: Text('Proceed to Step ${_currentStep + 2}'),
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        onPressed: _isGenerating ? null : () => _runGenerator(),
                        icon: _isGenerating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.play_arrow, size: 20),
                        label: Text(
                          _isGenerating ? 'SOLVING CONSTRAINTS...' : 'GENERATE TIMETABLE NOW',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      nextBtn,
                      if (_currentStep > 0) ...[
                        const SizedBox(height: 10),
                        prevBtn,
                      ],
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    prevBtn,
                    nextBtn,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperTabs() {
    final steps = [
      '1. Schedule',
      '2. Professors',
      '3. Sections',
      '4. Subjects',
      '5. Rooms/Labs',
      '6. Generate',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(steps.length, (idx) {
          final isSelected = _currentStep == idx;
          final isPassed = _currentStep > idx;

          return Row(
            children: [
              InkWell(
                onTap: () => setState(() => _currentStep = idx),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : (isPassed ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (isPassed ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isPassed)
                        const Icon(Icons.check, size: 14, color: Color(0xFF15803D))
                      else
                        CircleAvatar(
                          radius: 9,
                          backgroundColor: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.primaryColor : Colors.white,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        steps[idx],
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isPassed ? const Color(0xFF15803D) : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (idx < steps.length - 1)
                Container(
                  width: 16,
                  height: 2,
                  color: isPassed ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildActiveStepContent(
    College? college,
    List<String> activeDays,
    List<Staff> staffList,
    List<Section> sections,
    List<Subject> subjects,
    List<Room> rooms,
    List<TimeSlot> timeSlots,
    List<TimeSlot> academicSlots,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Schedule(college, timeSlots, activeDays);
      case 1:
        return _buildStep2Professors(staffList);
      case 2:
        return _buildStep3Sections(sections);
      case 3:
        return _buildStep4Subjects(subjects, staffList, sections);
      case 4:
        return _buildStep5Rooms(rooms);
      case 5:
        return _buildStep6Generate(college, activeDays, staffList, sections, subjects, rooms, timeSlots, academicSlots);
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: College schedule (Working days, Periods per day, Period timings, Breaks)
  Widget _buildStep1Schedule(College? college, List<TimeSlot> timeSlots, List<String> activeDays) {
    final breaks = timeSlots.where((t) => t.isBreak).toList();
    final academicSlots = timeSlots.where((t) => !t.isBreak).toList();
    const allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final inactiveDays = allDays.where((d) => !activeDays.contains(d)).toList();

    return Card(
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STEP 1: College Schedule & Break Structure',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Configure active working days, academic period count, slot timings, and recess breaks',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/schedule'),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Detailed Schedule Editor'),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Working Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeDays.isNotEmpty ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: activeDays.isNotEmpty ? const Color(0xFF86EFAC) : const Color(0xFFFECDD3),
                    ),
                  ),
                  child: Text(
                    'Working Days: ${activeDays.length} active ${activeDays.length == 1 ? "day" : "days"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: activeDays.isNotEmpty ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ACTIVE DAYS
            Row(
              children: [
                const Icon(Icons.check_circle, size: 15, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Text(
                  'ACTIVE (${activeDays.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF15803D), letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (activeDays.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Text('No active working days selected. Timetable cannot be scheduled.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626), fontStyle: FontStyle.italic)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: activeDays.map((day) {
                  return FilterChip(
                    avatar: const Icon(Icons.check, size: 14, color: Colors.white),
                    label: Text(day, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                    selected: true,
                    selectedColor: AppTheme.primaryColor,
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    onSelected: (_) async {
                      final updated = List<String>.from(activeDays)..remove(day);
                      await ref.read(collegeControllerProvider.notifier).setWorkingDays(updated);
                    },
                    tooltip: 'Click to deactivate $day',
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            // INACTIVE DAYS
            Row(
              children: [
                const Icon(Icons.pause_circle_outline, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'INACTIVE (${inactiveDays.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (inactiveDays.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Text('All days are currently active.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: inactiveDays.map((day) {
                  return ActionChip(
                    avatar: const Icon(Icons.add, size: 14, color: Color(0xFF475569)),
                    label: Text(day, style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    onPressed: () async {
                      final updated = List<String>.from(activeDays);
                      final dayIndex = allDays.indexOf(day);
                      int insertIdx = updated.length;
                      for (int i = 0; i < updated.length; i++) {
                        if (allDays.indexOf(updated[i]) > dayIndex) {
                          insertIdx = i;
                          break;
                        }
                      }
                      updated.insert(insertIdx, day);
                      await ref.read(collegeControllerProvider.notifier).setWorkingDays(updated);
                    },
                    tooltip: 'Click to activate $day',
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 650;
                final periodsCard = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Periods Per Day: ${academicSlots.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        academicSlots.isEmpty
                            ? 'No academic periods configured'
                            : academicSlots.map((s) => 'P${s.periodNumber} (${s.startTime} - ${s.endTime})').join(', '),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                );

                final breaksCard = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Configured Breaks: ${breaks.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E))),
                      const SizedBox(height: 4),
                      Text(
                        breaks.isEmpty
                            ? 'No breaks configured'
                            : breaks.map((b) => '${b.label} (${b.startTime} - ${b.endTime})').join(' • '),
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                );

                if (isCompact) {
                  return Column(
                    children: [
                      periodsCard,
                      const SizedBox(height: 12),
                      breaksCard,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: periodsCard),
                    const SizedBox(width: 16),
                    Expanded(child: breaksCard),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // STEP 2: Professors (Names, subjects can teach, availability & optional unavailable periods)
  Widget _buildStep2Professors(List<Staff> staffList) {
    return Card(
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STEP 2: Faculty & Professor Availability',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Ensure professors are registered with their teaching subjects and availability constraints',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => context.go('/professors'),
                  icon: const Icon(Icons.people, size: 16),
                  label: const Text('Manage Professors'),
                ),
              ],
            ),
            const Divider(height: 24),
            if (staffList.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No professors added yet. Please add faculty members.'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: staffList.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, i) {
                  final s = staffList[i];
                  return Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: Text(s.name.isNotEmpty ? s.name[0] : 'P',
                            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('${s.designation} • Max ${s.maxClassesPerDay} classes/day',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              s.subjectsCanTeach.isEmpty
                                  ? 'Can teach: All Subjects'
                                  : 'Can teach: ${s.subjectsCanTeach.join(", ")}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: s.subjectsCanTeach.isEmpty ? const Color(0xFF15803D) : const Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Available Mon-Fri',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // STEP 3: Sections (Section A, Section B, Section C)
  Widget _buildStep3Sections(List<Section> sections) {
    return Card(
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STEP 3: Class Cohorts & Sections',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Sections to be scheduled (e.g. Section A, Section B, Section C)',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => context.go('/sections-subjects'),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Sections'),
                ),
              ],
            ),
            const Divider(height: 24),
            if (sections.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No sections configured. Please add Section A, Section B, etc.'),
                ),
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: sections.map((sec) {
                  return Container(
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(sec.sectionName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Section ${sec.sectionName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Sem ${sec.semester} • ${sec.studentCount} Students',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // STEP 4: Subjects (Assigned subjects, required periods/week, theory/lab type)
  Widget _buildStep4Subjects(List<Subject> subjects, List<Staff> staffList, List<Section> sections) {
    final staffMap = {for (var s in staffList) s.id: s};

    return Card(
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STEP 4: Section Subjects & Assigned Professors',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('For each section: Subject, assigned professor, required periods/week, and Theory/Lab type',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => context.go('/sections-subjects'),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Manage Subjects'),
                ),
              ],
            ),
            const Divider(height: 24),
            if (subjects.any((s) => !s.isLab && s.assignedTeacherIds.isEmpty))
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
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Incomplete Subjects: Some theory subjects are missing an assigned professor. You must assign an eligible professor to each theory subject before a timetable can be generated.',
                        style: TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            if (subjects.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No subjects added yet.'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subjects.length,
                separatorBuilder: (_, _) => const Divider(height: 12),
                itemBuilder: (context, i) {
                  final sub = subjects[i];
                  final teacherName = sub.assignedTeacherIds
                      .map((id) => staffMap[id]?.name ?? id)
                      .join(', ');
                  final isIncomplete = !sub.isLab && sub.assignedTeacherIds.isEmpty;

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(sub.subjectCode,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(sub.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                if (isIncomplete) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'INCOMPLETE: No Professor',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text('Professor: ${teacherName.isNotEmpty ? teacherName : (sub.isLab ? "None (Optional)" : "Not Assigned")} • Facility: ${sub.requiredRoomType}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (teacherName.isNotEmpty || sub.isLab) ? const Color(0xFF64748B) : Colors.red,
                                  fontWeight: (!sub.isLab && teacherName.isEmpty) ? FontWeight.bold : FontWeight.normal,
                                )),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: sub.isLab ? const Color(0xFFDBEAFE) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          sub.subjectType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: sub.isLab ? const Color(0xFF1E40AF) : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${sub.hoursPerWeek} periods/week',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // STEP 5: Rooms/Labs (Classroom, Computer Lab, Capacity)
  Widget _buildStep5Rooms(List<Room> rooms) {
    return Card(
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STEP 5: Available Classrooms & Laboratories',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Physical venues, room types (Classroom, Computer Lab, etc.), and seating capacities',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => context.go('/rooms'),
                  icon: const Icon(Icons.meeting_room, size: 16),
                  label: const Text('Manage Rooms & Labs'),
                ),
              ],
            ),
            const Divider(height: 24),
            if (rooms.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No rooms or labs configured yet.'),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: rooms.map((r) {
                  final isLab = r.roomType.contains('Lab');
                  return Container(
                    width: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLab ? Icons.computer : Icons.meeting_room,
                          color: isLab ? AppTheme.primaryColor : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.roomNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('${r.roomType} • ${r.capacity} seats',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // STEP 6: Generate Timetable
  Widget _buildStep6Generate(
    College? college,
    List<String> activeDays,
    List<Staff> staffList,
    List<Section> sections,
    List<Subject> subjects,
    List<Room> rooms,
    List<TimeSlot> timeSlots,
    List<TimeSlot> academicSlots,
  ) {
    // 7-Point Pre-Flight Verification Criteria
    final schedOk = activeDays.isNotEmpty && academicSlots.isNotEmpty;

    final activeStaff = staffList.where((s) => s.active && s.status != 'inactive').toList();
    final profsOk = activeStaff.isNotEmpty;

    final activeSecs = sections.where((s) => s.active).toList();
    final secsOk = activeSecs.isNotEmpty;

    final activeSubjs = subjects.where((s) => s.active).toList();
    final subjsExist = activeSubjs.isNotEmpty;
    final unassignedSubjs = activeSubjs.where((s) => !s.isLab && s.assignedTeacherIds.isEmpty).toList();

    final staffMap = {for (var s in staffList) s.id: s};
    final ineligibleSubjs = activeSubjs.where((sub) {
      if (sub.assignedTeacherIds.isEmpty) return false;
      final p = staffMap[sub.assignedTeacherIds.first];
      if (p == null || !p.active || p.status == 'inactive') return true;
      return !p.isEligibleForSubject(
        subjectName: sub.subjectName,
        subjectCode: sub.subjectCode,
        subjectId: sub.id,
      );
    }).toList();
    final subjsOk = subjsExist && unassignedSubjs.isEmpty && ineligibleSubjs.isEmpty;

    final totalSlotsPerWeek = activeDays.length * academicSlots.length;
    final zeroHourSubjs = activeSubjs.where((s) => s.hoursPerWeek <= 0).toList();
    String? overloadedSecName;
    int overloadedHours = 0;
    for (final sec in activeSecs) {
      final secSubjs = activeSubjs.where((s) {
        if (s.sectionId != null && s.sectionId!.isNotEmpty) return s.sectionId == sec.id;
        final deptMatch = s.departmentId.isEmpty || s.departmentId == sec.departmentId;
        final semMatch = s.semester == sec.semester;
        return deptMatch && semMatch;
      }).toList();
      final sumH = secSubjs.fold<int>(0, (acc, s) => acc + s.hoursPerWeek);
      if (totalSlotsPerWeek > 0 && sumH > totalSlotsPerWeek) {
        overloadedSecName = sec.sectionName;
        overloadedHours = sumH;
        break;
      }
    }
    final hoursOk = totalSlotsPerWeek > 0 && zeroHourSubjs.isEmpty && overloadedSecName == null;

    final activeRooms = rooms.where((r) => r.active && !r.isUnderMaintenance).toList();
    String? missingFacility;
    for (final sub in activeSubjs) {
      if (sub.requiredRoomType.isNotEmpty && sub.requiredRoomType != 'Classroom') {
        final match = activeRooms.where((r) => r.roomType == sub.requiredRoomType).toList();
        if (match.isEmpty) {
          missingFacility = sub.requiredRoomType;
          break;
        }
      }
    }
    final roomsOk = activeRooms.isNotEmpty && missingFacility == null;

    final assignedProfIds = activeSubjs.expand((s) => s.assignedTeacherIds).toSet();
    final zeroMaxProfs = assignedProfIds.map((id) => staffMap[id]).where((p) => p != null && p.maxClassesPerDay <= 0).toList();
    final availOk = zeroMaxProfs.isEmpty;

    final allChecksPass = schedOk && profsOk && secsOk && subjsOk && hoursOk && roomsOk && availOk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STEP 6: Pre-Flight Verification & Timetable Generation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Before generating, all 7 configuration requirements are strictly validated. No fake or mock data is ever created.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const Divider(height: 24),

                // Responsive Live Summary Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final cols = width >= 900 ? 6 : (width >= 600 ? 3 : 2);
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: cols == 6 ? 1.9 : (cols == 3 ? 2.5 : 2.8),
                      children: [
                        _buildSummaryCard('Working Days', '${activeDays.length} active days', Icons.calendar_today),
                        _buildSummaryCard('Periods / Day', '${academicSlots.length} periods', Icons.access_time),
                        _buildSummaryCard('Professors', '${staffList.length} faculty', Icons.people),
                        _buildSummaryCard('Sections', '${sections.length} cohorts', Icons.group),
                        _buildSummaryCard('Subjects', '${subjects.length} courses', Icons.book),
                        _buildSummaryCard('Rooms & Labs', '${rooms.length} venues', Icons.meeting_room),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 7-Point Pre-Flight Verification Checklist Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: allChecksPass ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: allChecksPass ? const Color(0xFF86EFAC) : const Color(0xFFFECDD3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            allChecksPass ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: allChecksPass ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              allChecksPass
                                  ? 'All 7 Pre-Flight Requirements Satisfied — Ready for Timetable Generation'
                                  : 'Pre-Flight Requirements Incomplete: Please resolve highlighted items below',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: allChecksPass ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      _checklistRow(
                        title: '1. College Schedule',
                        description: schedOk
                            ? '${activeDays.length} working days, ${academicSlots.length} academic periods per day'
                            : 'Missing active working days or period timings',
                        isSatisfied: schedOk,
                        actionLabel: 'Edit Schedule',
                        onFix: () => setState(() => _currentStep = 0),
                      ),
                      const SizedBox(height: 8),
                      _checklistRow(
                        title: '2. Faculty & Professors',
                        description: profsOk
                            ? '${activeStaff.length} active professor(s) registered'
                            : 'No active professors registered. Add faculty in Step 2.',
                        isSatisfied: profsOk,
                        actionLabel: 'Add Professors',
                        onFix: () => setState(() => _currentStep = 1),
                      ),
                      const SizedBox(height: 8),
                      _checklistRow(
                        title: '3. Class Sections',
                        description: secsOk
                            ? '${activeSecs.length} class section(s) configured'
                            : 'No class sections configured. Add sections in Step 3.',
                        isSatisfied: secsOk,
                        actionLabel: 'Add Sections',
                        onFix: () => setState(() => _currentStep = 2),
                      ),
                      const SizedBox(height: 8),
                      _checklistRow(
                        title: '4. Section Subjects & Assigned Faculty',
                        description: !subjsExist
                            ? 'No subjects configured yet. Add subjects in Step 4.'
                            : (unassignedSubjs.isNotEmpty
                                ? '${unassignedSubjs.length} subject(s) missing assigned professor (${unassignedSubjs.map((s) => s.subjectName).take(2).join(", ")})'
                                : (ineligibleSubjs.isNotEmpty
                                    ? 'Assigned professor for ${ineligibleSubjs.first.subjectName} is not eligible under Can Teach rule'
                                    : '${activeSubjs.length} subject(s) with eligible assigned professors')),
                        isSatisfied: subjsOk,
                        actionLabel: 'Fix in Subjects',
                        onFix: () => setState(() => _currentStep = 3),
                      ),
                      const SizedBox(height: 8),
                      _checklistRow(
                        title: '5. Weekly Period Requirements',
                        description: totalSlotsPerWeek == 0
                            ? 'No schedule capacity available (0 active working days or periods)'
                            : (zeroHourSubjs.isNotEmpty
                                ? 'Subject "${zeroHourSubjs.first.subjectName}" has 0 periods/week'
                                : (overloadedSecName != null
                                    ? 'Section $overloadedSecName requires $overloadedHours periods/week, exceeding schedule capacity ($totalSlotsPerWeek)'
                                    : 'All weekly period requirements fit within available schedule capacity ($totalSlotsPerWeek periods/week capacity)')),
                        isSatisfied: hoursOk,
                        actionLabel: 'Adjust Periods',
                        onFix: () => setState(() => _currentStep = 3),
                      ),
                      const SizedBox(height: 8),
                      _checklistRow(
                        title: '6. Classrooms & Specialized Labs',
                        description: activeRooms.isEmpty
                            ? 'No active classrooms or labs configured'
                            : (missingFacility != null
                                ? 'No active room available for required facility "$missingFacility"'
                                : '${activeRooms.length} active classrooms and labs available'),
                        isSatisfied: roomsOk,
                        actionLabel: 'Manage Rooms',
                        onFix: () => setState(() => _currentStep = 4),
                      ),
                      const SizedBox(height: 8),
                      _checklistRow(
                        title: '7. Faculty Availability Constraints',
                        description: availOk
                            ? 'All assigned faculty have valid daily teaching limits'
                            : 'Faculty member ${zeroMaxProfs.first!.name} has 0 max classes/day limit',
                        isSatisfied: availOk,
                        actionLabel: 'Review Faculty',
                        onFix: () => setState(() => _currentStep = 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Big Generate Timetable CTA Button
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: allChecksPass ? AppTheme.primaryColor : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: allChecksPass ? 4 : 0,
                    ),
                    onPressed: _isGenerating || !allChecksPass ? null : () => _runGenerator(),
                    icon: _isGenerating
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(allChecksPass ? Icons.auto_awesome : Icons.lock_outline, size: 24),
                    label: Text(
                      _isGenerating
                          ? 'SOLVING CONSTRAINTS & GENERATING...'
                          : (allChecksPass ? 'GENERATE TIMETABLE' : 'COMPLETE PRE-FLIGHT CHECKLIST FIRST'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Result Card (Success or Unresolvable Constraints)
        if (_generationResult != null) ...[
          const SizedBox(height: 20),
          _buildGenerationOutcomeCard(_generationResult!),
        ],
        if (_generationError != null) ...[
          const SizedBox(height: 20),
          _buildErrorCard(_generationError!),
        ],
      ],
    );
  }

  Widget _checklistRow({
    required String title,
    required String description,
    required bool isSatisfied,
    required String actionLabel,
    required VoidCallback onFix,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 550;
        final info = Row(
          children: [
            Icon(
              isSatisfied ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 18,
              color: isSatisfied ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSatisfied ? const Color(0xFF0F172A) : const Color(0xFF991B1B))),
                  Text(description, style: TextStyle(fontSize: 12, color: isSatisfied ? const Color(0xFF64748B) : const Color(0xFFB91C1C))),
                ],
              ),
            ),
          ],
        );

        final btn = isSatisfied
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('READY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
              )
            : TextButton.icon(
                onPressed: onFix,
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              info,
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: btn),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: 8),
            btn,
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationOutcomeCard(GenerationResult result) {
    final isSuccess = result.isSuccess;

    return Card(
      color: isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSuccess ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 750;
                final actionButtons = Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (isSuccess) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                        onPressed: () => context.go('/timetable'),
                        icon: const Icon(Icons.grid_view, size: 16),
                        label: const Text('View Timetable'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/conflicts'),
                        icon: const Icon(Icons.verified, size: 16, color: Color(0xFF166534)),
                        label: const Text('Check Conflicts'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/export'),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export'),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                        onPressed: () => context.go('/conflicts'),
                        icon: const Icon(Icons.warning_amber_rounded, size: 16),
                        label: const Text('Check Conflicts in Center'),
                      ),
                    ],
                  ],
                );

                final infoColumn = Row(
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: isSuccess ? const Color(0xFF16A34A) : AppTheme.errorColor,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSuccess
                                ? 'Timetable Generated Successfully!'
                                : 'Timetable cannot be generated with the current constraints',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSuccess ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                            ),
                          ),
                          Text(
                            result.summaryMessage,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSuccess ? const Color(0xFF166534) : const Color(0xFF7F1D1D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      infoColumn,
                      const SizedBox(height: 14),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: infoColumn),
                    const SizedBox(width: 16),
                    actionButtons,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (isSuccess) ...[
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  _metricPill('Classes Scheduled', '${result.totalClassesScheduled}'),
                  _metricPill('Professors Utilized', '${result.teachersUsed}'),
                  _metricPill('Rooms Allocated', '${result.roomsUsed}'),
                  _metricPill('Computation Time', '${result.generationTimeMs} ms'),
                  _metricPill('Constraint Conflicts', '0 Conflicts (Verified)'),
                ],
              ),
            ] else ...[
              const Text('Actionable Diagnostic Suggestions to Fix Constraints:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B))),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: result.conflicts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, idx) {
                  final c = result.conflicts[idx];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ${c.title}: ${c.description}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF881337))),
                        if (c.suggestion != null) ...[
                          const SizedBox(height: 4),
                          Text('  Fix Suggestion: ${c.suggestion}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF15803D))),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      color: const Color(0xFFFEF2F2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFCA5A5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Error: $error', style: const TextStyle(color: Color(0xFF991B1B))),
      ),
    );
  }

  Future<void> _runGenerator() async {
    setState(() {
      _isGenerating = true;
      _generationResult = null;
      _generationError = null;
    });

    try {
      final versionName = 'Generated Timetable ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
      final result = await ref.read(timetableControllerProvider.notifier).generateSchedule(
        customVersionName: versionName,
      );

      setState(() {
        _generationResult = result;
        _isGenerating = false;
      });

      if (mounted) {
        if (result.isSuccess && result.conflicts.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text(
                'Timetable generated successfully! ${result.totalClassesScheduled} classes scheduled with 0 hard conflicts.',
              ),
              action: SnackBarAction(
                label: 'View Matrix',
                textColor: Colors.white,
                onPressed: () => context.go('/timetable'),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.errorColor,
              content: Text(
                'Generation completed with ${result.conflicts.length} conflict(s): ${result.summaryMessage}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _generationError = e.toString();
        _isGenerating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.errorColor,
            content: Text('Generation failed: $e'),
          ),
        );
      }
    }
  }
}
