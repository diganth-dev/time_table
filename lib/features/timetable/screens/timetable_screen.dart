import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/workflow_progress_bar.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../timetable_utils.dart';
import 'timetable_editor_dialog.dart';

enum TimetableViewMode { section, teacher, room, department }

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  TimetableViewMode _viewMode = TimetableViewMode.section;

  String? _selectedSectionId;
  String? _selectedTeacherId;
  String? _selectedRoomId;
  String? _selectedDeptId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentProfileProvider);
    final isAdmin = user?.role == UserRole.collegeAdmin;
    final isTeacher = user?.role == UserRole.teacher;
    final isStudent = user?.role == UserRole.student;

    final versionsAsync = ref.watch(timetableVersionsProvider);
    final selectedVersionId = ref.watch(selectedVersionIdProvider);
    final versions = versionsAsync.value ?? [];
    final effectiveVersionId = (selectedVersionId != null && selectedVersionId.isNotEmpty)
        ? selectedVersionId
        : (versions.where((v) => v.status == 'draft').firstOrNull?.id ??
            (versions.isNotEmpty ? versions.first.id : null));

    final sections = ref.watch(sectionListProvider).value ?? [];
    final staffList = ref.watch(staffListProvider).value ?? [];
    final rooms = ref.watch(roomListProvider).value ?? [];
    final depts = ref.watch(departmentListProvider).value ?? [];
    final timeSlots = ref.watch(timeSlotsProvider).value ?? [];
    final college = ref.watch(currentCollegeProvider).value;
    final workingDays =
        college?.workingDays ??
        ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    final globalSectionFilter = ref.watch(selectedSectionFilterProvider);

    // Auto-select defaults
    if (_selectedSectionId == null && sections.isNotEmpty) {
      if (globalSectionFilter != null &&
          sections.any((s) => s.id == globalSectionFilter)) {
        _selectedSectionId = globalSectionFilter;
      } else if (isStudent && user?.sectionId != null) {
        _selectedSectionId = user!.sectionId;
      } else {
        _selectedSectionId = sections.first.id;
      }
    }
    if (_selectedTeacherId == null && staffList.isNotEmpty) {
      if (isTeacher && user?.staffId != null) {
        _selectedTeacherId = user!.staffId;
      } else {
        _selectedTeacherId = staffList.first.id;
      }
    }
    if (_selectedRoomId == null && rooms.isNotEmpty) {
      _selectedRoomId = rooms.first.id;
    }
    if (_selectedDeptId == null && depts.isNotEmpty) {
      _selectedDeptId = depts.first.id;
    }

    // Load entries
    final entriesAsync = ref.watch(timetableEntriesProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkflowProgressBar(currentStep: WorkflowStep.timetable),
            const SizedBox(height: 20),

            // Top Bar: View Mode Selector & Action Buttons
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 920;
                final titleColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'College Timetables',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Master schedule & occupancy matrix for ${college?.name ?? "College"}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.go('/conflicts'),
                      icon: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: const Text('Check Conflicts'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/export'),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/workflow'),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Generate New'),
                    ),
                    versionsAsync.when(
                      data: (versions) {
                        final currentVersion = versions.firstWhere(
                          (v) => v.id == selectedVersionId,
                          orElse: () => versions.isNotEmpty
                              ? versions.first
                              : TimetableVersion(
                                  id: '',
                                  collegeId: '',
                                  versionNumber: 1,
                                  name: '',
                                  academicYear: '',
                                  semester: '',
                                ),
                        );
                        final canPublish =
                            currentVersion.id.isNotEmpty &&
                            !currentVersion.isPublished;

                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canPublish
                                ? AppTheme.secondaryColor
                                : Colors.grey.shade400,
                          ),
                          onPressed: canPublish
                              ? () =>
                                    _showPublishDialog(context, currentVersion)
                              : null,
                          icon: const Icon(Icons.publish, size: 18),
                          label: Text(
                            currentVersion.isPublished
                                ? 'Published'
                                : 'Publish Version',
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
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
                    titleColumn,
                    const SizedBox(width: 16),
                    Flexible(child: actionButtons),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Controls Card: View Mode Tabs + Filter Selectors
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // View Mode Tabs
                    SegmentedButton<TimetableViewMode>(
                      segments: const [
                        ButtonSegment(
                          value: TimetableViewMode.section,
                          label: Text('Section View'),
                          icon: Icon(Icons.group),
                        ),
                        ButtonSegment(
                          value: TimetableViewMode.teacher,
                          label: Text('Faculty View'),
                          icon: Icon(Icons.badge),
                        ),
                        ButtonSegment(
                          value: TimetableViewMode.room,
                          label: Text('Room Occupancy'),
                          icon: Icon(Icons.meeting_room),
                        ),
                        ButtonSegment(
                          value: TimetableViewMode.department,
                          label: Text('Department View'),
                          icon: Icon(Icons.domain),
                        ),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (val) {
                        setState(() => _viewMode = val.first);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Filter Row
                    Row(
                      children: [
                        // Version Selector
                        Expanded(
                          flex: 3,
                          child: versionsAsync.when(
                            data: (versions) {
                              if (versions.isEmpty) {
                                return const Text('No timetable versions yet.');
                              }
                              final activeVersionId = (selectedVersionId != null && selectedVersionId.isNotEmpty)
                                  ? selectedVersionId
                                  : (versions.where((v) => v.status == 'draft').firstOrNull?.id ??
                                      (versions.isNotEmpty ? versions.first.id : null));
                              final dropdownVal = (activeVersionId != null && versions.any((v) => v.id == activeVersionId))
                                  ? activeVersionId
                                  : (versions.isNotEmpty ? versions.first.id : null);
                              return DropdownButtonFormField<String>(
                                value: dropdownVal,
                                decoration: const InputDecoration(
                                  labelText: 'Timetable Version',
                                  prefixIcon: Icon(Icons.history, size: 18),
                                ),
                                items: versions
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v.id,
                                        child: Row(
                                          children: [
                                            Text(v.name),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: v.isPublished
                                                    ? Colors.green.shade50
                                                    : Colors.amber.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                v.status.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: v.isPublished
                                                      ? Colors.green.shade800
                                                      : Colors.amber.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  ref
                                          .read(
                                            selectedVersionIdProvider.notifier,
                                          )
                                          .state =
                                      val;
                                },
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('Error: $e'),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Secondary Filter based on View Mode
                        Expanded(
                          flex: 3,
                          child: _buildSecondaryFilter(
                            sections,
                            staffList,
                            rooms,
                            depts,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Timetable Table Grid View
            entriesAsync.when(
              data: (allEntries) {
                final hasVersions = versionsAsync.maybeWhen(
                      data: (vList) => vList.isNotEmpty,
                      orElse: () => false,
                    ) ||
                    (selectedVersionId != null &&
                        selectedVersionId.isNotEmpty);

                if (allEntries.isEmpty && !hasVersions) {
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 60,
                        horizontal: 24,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 56,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No timetable data yet.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enter your college information to create a timetable.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/workflow'),
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: const Text('Start Input Workflow'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Filter entries according to active view mode & selector
                final filteredEntries = _filterEntries(allEntries);
                final currentSection = sections
                    .where((s) => s.id == _selectedSectionId)
                    .firstOrNull;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_viewMode == TimetableViewMode.section &&
                        currentSection != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.school_outlined,
                                  size: 20,
                                  color: Color(0xFF1E293B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Section: ${currentSection.sectionName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Semester: ${currentSection.semester}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            if (currentSection.academicYear.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.history_edu_outlined,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Academic Year: ${currentSection.academicYear}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    _buildTimetableGrid(
                      context,
                      entries: filteredEntries,
                      workingDays: workingDays,
                      timeSlots: timeSlots,
                      college: college,
                      isAdmin: isAdmin,
                    ),
                    const SizedBox(height: 20),
                    _buildCourseFacultyVenueTable(
                      context,
                      entries: filteredEntries,
                      subjects: ref.watch(subjectListProvider).value ?? [],
                      staffList: staffList,
                      rooms: rooms,
                      section: currentSection,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () => _confirmDeleteTimetable(context),
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          size: 20,
                        ),
                        label: const Text(
                          'Delete Timetable',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) =>
                  Center(child: Text('Error loading timetable entries: $e')),
            ),

            // Step Navigation Controls
            WorkflowBottomBar(
              backLabel: '← Back to Generator',
              onBack: () => context.go('/workflow'),
              nextLabel: 'Check Conflicts & Verification →',
              onNext: () => context.go('/conflicts'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryFilter(
    List<Section> sections,
    List<Staff> staffList,
    List<Room> rooms,
    List<Department> depts,
  ) {
    switch (_viewMode) {
      case TimetableViewMode.section:
        return DropdownButtonFormField<String>(
          initialValue: _selectedSectionId,
          decoration: const InputDecoration(
            labelText: 'Select Section',
            prefixIcon: Icon(Icons.class_, size: 18),
          ),
          items: sections
              .map(
                (s) =>
                    DropdownMenuItem(value: s.id, child: Text(s.displayName)),
              )
              .toList(),
          onChanged: (val) {
            setState(() => _selectedSectionId = val);
            ref.read(selectedSectionFilterProvider.notifier).state = val;
          },
        );
      case TimetableViewMode.teacher:
        return DropdownButtonFormField<String>(
          initialValue: _selectedTeacherId,
          decoration: const InputDecoration(
            labelText: 'Select Teacher',
            prefixIcon: Icon(Icons.person, size: 18),
          ),
          items: staffList
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text('${s.name} (${s.designation})'),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedTeacherId = val),
        );
      case TimetableViewMode.room:
        return DropdownButtonFormField<String>(
          initialValue: _selectedRoomId,
          decoration: const InputDecoration(
            labelText: 'Select Room / Lab',
            prefixIcon: Icon(Icons.meeting_room, size: 18),
          ),
          items: rooms
              .map(
                (r) => DropdownMenuItem(
                  value: r.id,
                  child: Text('${r.roomNumber} (${r.roomType})'),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedRoomId = val),
        );
      case TimetableViewMode.department:
        return DropdownButtonFormField<String>(
          initialValue: _selectedDeptId,
          decoration: const InputDecoration(
            labelText: 'Select Department',
            prefixIcon: Icon(Icons.domain, size: 18),
          ),
          items: depts
              .map(
                (d) => DropdownMenuItem(
                  value: d.id,
                  child: Text('${d.name} (${d.code})'),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedDeptId = val),
        );
    }
  }

  List<TimetableEntry> _filterEntries(List<TimetableEntry> entries) {
    switch (_viewMode) {
      case TimetableViewMode.section:
        if (_selectedSectionId == null) return entries;
        return entries.where((e) => e.sectionId == _selectedSectionId).toList();
      case TimetableViewMode.teacher:
        if (_selectedTeacherId == null) return entries;
        return entries.where((e) => e.teacherId == _selectedTeacherId).toList();
      case TimetableViewMode.room:
        if (_selectedRoomId == null) return entries;
        return entries.where((e) => e.roomId == _selectedRoomId).toList();
      case TimetableViewMode.department:
        return entries;
    }
  }

  Widget _buildTimetableGrid(
    BuildContext context, {
    required List<TimetableEntry> entries,
    required List<String> workingDays,
    required List<TimeSlot> timeSlots,
    required College? college,
    required bool isAdmin,
  }) {
    final sortedSlots = getEffectiveTimeSlots(timeSlots, college, entries);

    final subjects = ref.watch(subjectListProvider).value ?? [];
    final staffList = ref.watch(staffListProvider).value ?? [];
    final rooms = ref.watch(roomListProvider).value ?? [];
    final sections = ref.watch(sectionListProvider).value ?? [];
    final versionsAsync = ref.watch(timetableVersionsProvider);
    final selectedVersionId = ref.watch(selectedVersionIdProvider);
    final versions = versionsAsync.value ?? [];
    final effectiveVersionId = (selectedVersionId != null && selectedVersionId.isNotEmpty)
        ? selectedVersionId
        : (versions.where((v) => v.status == 'draft').firstOrNull?.id ??
            (versions.isNotEmpty ? versions.first.id : null));

    final subMap = {for (var s in subjects) s.id: s};
    final staffMap = {for (var s in staffList) s.id: s};
    final roomMap = {for (var r in rooms) r.id: r};
    final secMap = {for (var s in sections) s.id: s};

    final Map<int, TableColumnWidth> columnWidths = {
      0: const FixedColumnWidth(120),
    };
    for (int i = 0; i < sortedSlots.length; i++) {
      final slot = sortedSlots[i];
      if (slot.isBreak) {
        columnWidths[i + 1] = const FixedColumnWidth(130);
      } else {
        columnWidths[i + 1] = const FixedColumnWidth(230);
      }
    }

    final middleDayIndex = workingDays.length ~/ 2;

    String getCourseShortName(Subject? s) {
      return s?.shortName ?? 'SUB';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            columnWidths: columnWidths,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Period Header Row (Row 0)
              TableRow(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        right: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Day',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  ...sortedSlots.map((slot) {
                    if (slot.isBreak) {
                      final isLunch =
                          slot.breakTitle?.toLowerCase().contains('lunch') ==
                          true;
                      final headerTitle = isLunch
                          ? 'Lunch'
                          : (slot.breakTitle?.toLowerCase().contains('break') ==
                                    true
                                ? 'Break'
                                : (slot.breakTitle ?? 'Break'));
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isLunch
                              ? const Color(0xFFFED7AA)
                              : const Color(0xFFFDE68A),
                          border: Border(
                            bottom: BorderSide(
                              color: isLunch
                                  ? const Color(0xFFF97316)
                                  : const Color(0xFFF59E0B),
                              width: 1.5,
                            ),
                            left: BorderSide(
                              color: isLunch
                                  ? const Color(0xFFFDBA74)
                                  : const Color(0xFFFCD34D),
                              width: 1,
                            ),
                            right: BorderSide(
                              color: isLunch
                                  ? const Color(0xFFFDBA74)
                                  : const Color(0xFFFCD34D),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            headerTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: isLunch
                                  ? const Color(0xFF9A3412)
                                  : const Color(0xFF92400E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                          right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Period ${slot.periodNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }),
                ],
              ),

              // From Time Row (Row 1)
              TableRow(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                        right: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'From',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          color: Color(0xFF475569),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  ...sortedSlots.map((slot) {
                    final isLunch =
                        slot.isBreak &&
                        slot.breakTitle?.toLowerCase().contains('lunch') ==
                            true;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: slot.isBreak
                            ? (isLunch
                                  ? const Color(0xFFFED7AA)
                                  : const Color(0xFFFDE68A))
                            : const Color(0xFFF1F5F9),
                        border: Border(
                          bottom: BorderSide(
                            color: slot.isBreak
                                ? (isLunch
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFFF59E0B))
                                : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                          left: BorderSide(
                            color: slot.isBreak
                                ? (isLunch
                                      ? const Color(0xFFFDBA74)
                                      : const Color(0xFFFCD34D))
                                : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                          right: BorderSide(
                            color: slot.isBreak
                                ? (isLunch
                                      ? const Color(0xFFFDBA74)
                                      : const Color(0xFFFCD34D))
                                : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          slot.startTime,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: slot.isBreak
                                ? (isLunch
                                      ? const Color(0xFF9A3412)
                                      : const Color(0xFF92400E))
                                : const Color(0xFF1E293B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }),
                ],
              ),

              // To Time Row (Row 2)
              TableRow(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                        right: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'To',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          color: Color(0xFF475569),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  ...sortedSlots.map((slot) {
                    final isLunch =
                        slot.isBreak &&
                        slot.breakTitle?.toLowerCase().contains('lunch') ==
                            true;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: slot.isBreak
                            ? (isLunch
                                  ? const Color(0xFFFED7AA)
                                  : const Color(0xFFFDE68A))
                            : const Color(0xFFF1F5F9),
                        border: Border(
                          bottom: BorderSide(
                            color: slot.isBreak
                                ? (isLunch
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFFF59E0B))
                                : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                          left: BorderSide(
                            color: slot.isBreak
                                ? (isLunch
                                      ? const Color(0xFFFDBA74)
                                      : const Color(0xFFFCD34D))
                                : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                          right: BorderSide(
                            color: slot.isBreak
                                ? (isLunch
                                      ? const Color(0xFFFDBA74)
                                      : const Color(0xFFFCD34D))
                                : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          slot.endTime,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: slot.isBreak
                                ? (isLunch
                                      ? const Color(0xFF9A3412)
                                      : const Color(0xFF92400E))
                                : const Color(0xFF1E293B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }),
                ],
              ),

              // Working Day Rows
              ...List.generate(workingDays.length, (dayIndex) {
                final day = workingDays[dayIndex];
                final isLastDay = dayIndex == workingDays.length - 1;

                return TableRow(
                  children: [
                    // Day Column
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 64),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border(
                            right: const BorderSide(
                              color: Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                            bottom: BorderSide(
                              color: isLastDay
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),

                    // Slots Columns
                    ...sortedSlots.map((slot) {
                      if (slot.isBreak) {
                        final isLunch =
                            slot.breakTitle?.toLowerCase().contains('lunch') ==
                            true;
                        final breakBorderColor = isLunch
                            ? const Color(0xFFFED7AA)
                            : const Color(0xFFFDE68A);
                        final breakBgColor = isLunch
                            ? const Color(0xFFFFF7ED)
                            : const Color(0xFFFFFBEB);
                        final breakTextColor = isLunch
                            ? const Color(0xFF9A3412)
                            : const Color(0xFF92400E);
                        final breakIconColor = isLunch
                            ? const Color(0xFFEA580C)
                            : const Color(0xFFD97706);
                        final breakIcon = isLunch
                            ? Icons.restaurant_rounded
                            : Icons.coffee_rounded;
                        final breakTitle =
                            slot.breakTitle ??
                            (isLunch ? 'Lunch Break' : 'Tea Break');

                        return TableCell(
                          verticalAlignment: TableCellVerticalAlignment.fill,
                          child: Container(
                            decoration: BoxDecoration(
                              color: breakBgColor,
                              border: Border(
                                left: BorderSide(
                                  color: breakBorderColor,
                                  width: 1,
                                ),
                                right: BorderSide(
                                  color: breakBorderColor,
                                  width: 1,
                                ),
                                top: BorderSide.none,
                                bottom: isLastDay
                                    ? BorderSide(
                                        color: breakBorderColor,
                                        width: 1,
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Center(
                              child: dayIndex == middleDayIndex
                                  ? FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: isLunch
                                                  ? const Color(0xFFFFEDD5)
                                                  : const Color(0xFFFEF3C7),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              breakIcon,
                                              size: 16,
                                              color: breakIconColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            breakTitle,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              letterSpacing: 0.3,
                                              color: breakTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        );
                      }

                      // Academic Period
                      final matching = entries
                          .where(
                            (e) =>
                                e.dayOfWeek == day &&
                                e.periodNumber == slot.periodNumber &&
                                e.status != 'cancelled',
                          )
                          .toList();

                      final bottomBorderSide = BorderSide(
                        color: isLastDay
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      );

                      if (matching.isEmpty) {
                        return TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: InkWell(
                            key: Key('empty_cell_${day}_${slot.periodNumber}'),
                            borderRadius: BorderRadius.circular(6),
                            hoverColor: const Color(0xFFF1F5F9),
                            onTap: isAdmin
                                ? () => showDialog(
                                    context: context,
                                    builder: (_) => TimetableEditorDialog(
                                      initialDay: day,
                                      initialPeriod: slot.periodNumber,
                                      initialSectionId: _selectedSectionId,
                                      versionId: effectiveVersionId,
                                    ),
                                  )
                                : null,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 56),
                              decoration: BoxDecoration(
                                border: Border(
                                  right: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                  bottom: bottomBorderSide,
                                ),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Center(
                                child: Text(
                                  isAdmin ? '+' : '—',
                                  style: TextStyle(
                                    color: isAdmin
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFFCBD5E1),
                                    fontSize: 14,
                                    fontWeight: isAdmin
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      // Render all scheduled entries faithfully without hardcoded batch shortcuts

                      // If not both batches (e.g. single lab entry or theory)
                      return TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          decoration: BoxDecoration(
                            border: Border(
                              right: const BorderSide(
                                color: Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              bottom: bottomBorderSide,
                            ),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (matching.length > 1 &&
                                  matching.every(
                                    (entry) => entry.batch != null,
                                  ))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFBFDBFE),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'PARALLEL LAB BATCHES',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ...matching.asMap().entries.map((item) {
                                final index = item.key;
                                final entry = item.value;
                                final sub = subMap[entry.subjectId];
                                final teacher = staffMap[entry.teacherId];
                                final room = roomMap[entry.roomId];
                                final sec = secMap[entry.sectionId];

                                if (entry.isActivity) {
                                  final hasVenue = entry.roomId.isNotEmpty;
                                  final venueDisplay = room?.roomNumber ?? entry.roomId;
                                  return InkWell(
                                    key: Key('entry_card_${entry.id}'),
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: isAdmin
                                        ? () => showDialog(
                                            context: context,
                                            builder: (_) => TimetableEditorDialog(
                                              entry: entry,
                                              versionId: effectiveVersionId,
                                            ),
                                          )
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF5FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFD8B4FE),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  entry.activityName?.trim().isNotEmpty == true
                                                      ? entry.activityName!
                                                      : 'Activity / Event',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Color(0xFF581C87),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF3E8FF),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: const Color(0xFFD8B4FE),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'ACTIVITY',
                                                  style: TextStyle(
                                                    color: Color(0xFF7E22CE),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (entry.description != null &&
                                              entry.description!.trim().isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              entry.description!.trim(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF475569),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (hasVenue) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.meeting_room_outlined,
                                                  size: 13,
                                                  color: Color(0xFF7E22CE),
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    venueDisplay,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1E293B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (_viewMode != TimetableViewMode.section && sec != null) ...[
                                            const SizedBox(height: 2.5),
                                            Text(
                                              sec.displayName,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF475569),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final isLab =
                                    sub?.isLab == true || entry.batch != null;
                                final shortName = getCourseShortName(sub);
                                final roomName = room?.roomNumber ?? 'Room';

                                final card = InkWell(
                                  key: Key('entry_card_${entry.id}'),
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: isAdmin
                                      ? () => showDialog(
                                          context: context,
                                          builder: (_) => TimetableEditorDialog(
                                            entry: entry,
                                            versionId: effectiveVersionId,
                                          ),
                                        )
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLab
                                          ? const Color(0xFFEFF6FF)
                                          : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isLab
                                            ? const Color(0xFF93C5FD)
                                            : const Color(0xFF86EFAC),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: isLab
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      shortName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                        color:
                                                            Color(0xFF1E3A8A),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (entry.batch != null) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF2563EB,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: Text(
                                                        entry.batch!,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 10.5,
                                                          color: Colors.white,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              if (sub != null &&
                                                  sub.subjectName.isNotEmpty &&
                                                  sub.subjectName !=
                                                      shortName) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  sub.subjectName,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF334155),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                              const SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.person_outline,
                                                    size: 13,
                                                    color: Color(0xFF2563EB),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      teacher?.name ??
                                                          'Teacher',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color:
                                                            Color(0xFF334155),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2.5),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .meeting_room_outlined,
                                                    size: 13,
                                                    color: Color(0xFF2563EB),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      roomName,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF1E293B),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (_viewMode !=
                                                      TimetableViewMode
                                                          .section &&
                                                  sec != null) ...[
                                                const SizedBox(height: 2.5),
                                                Text(
                                                  sec.displayName,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF475569),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      shortName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                        color:
                                                            Color(0xFF14532D),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 5,
                                                          vertical: 1.5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFDCFCE7,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFF86EFAC,
                                                        ),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'THEORY',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF15803D,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 9,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (sub != null &&
                                                  sub.subjectName.isNotEmpty &&
                                                  sub.subjectName !=
                                                      shortName) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  sub.subjectName,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF334155),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                              const SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.person_outline,
                                                    size: 13,
                                                    color: Color(0xFF16A34A),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      '${teacher?.name ?? "Teacher"} • $roomName',
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Color(0xFF334155),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (_viewMode !=
                                                      TimetableViewMode
                                                          .section &&
                                                  sec != null) ...[
                                                const SizedBox(height: 2.5),
                                                Text(
                                                  sec.displayName,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF475569),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                  ),
                                );

                                if (index > 0 &&
                                    matching.length > 1 &&
                                    matching.every((e) => e.batch != null)) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: const [
                                            Expanded(
                                              child: Divider(
                                                height: 1,
                                                thickness: 1,
                                                color: Color(0xFFBFDBFE),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6,
                                              ),
                                              child: Text(
                                                'and simultaneously:',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontStyle: FontStyle.italic,
                                                  color: Color(0xFF2563EB),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Divider(
                                                height: 1,
                                                thickness: 1,
                                                color: Color(0xFFBFDBFE),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      card,
                                    ],
                                  );
                                }
                                return card;
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseFacultyVenueTable(
    BuildContext context, {
    required List<TimetableEntry> entries,
    required List<Subject> subjects,
    required List<Staff> staffList,
    required List<Room> rooms,
    required Section? section,
  }) {
    final staffMap = {for (var s in staffList) s.id: s};
    final roomMap = {for (var r in rooms) r.id: r};

    // Filter relevant subjects for this section or active entries
    final entrySubjectIds = entries.map((e) => e.subjectId).toSet();
    List<Subject> displaySubjects = [];
    if (section != null) {
      displaySubjects = subjects
          .where(
            (s) => s.sectionId == section.id || entrySubjectIds.contains(s.id),
          )
          .toList();
    }
    if (displaySubjects.isEmpty) {
      displaySubjects = subjects
          .where((s) => entrySubjectIds.contains(s.id))
          .toList();
    }
    if (displaySubjects.isEmpty &&
        subjects.isNotEmpty &&
        _viewMode != TimetableViewMode.section) {
      displaySubjects = subjects;
    }

    // Sort subjects by code then name
    displaySubjects.sort((a, b) {
      if (a.subjectCode.isNotEmpty && b.subjectCode.isNotEmpty) {
        return a.subjectCode.compareTo(b.subjectCode);
      }
      return a.subjectName.compareTo(b.subjectName);
    });

    if (displaySubjects.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.table_view_outlined,
                    size: 18,
                    color: Color(0xFF1E293B),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Course / Faculty / Venue Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (section != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${section.displayName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                columnWidths: const {
                  0: FixedColumnWidth(140), // Course Code
                  1: FixedColumnWidth(160), // Course Short Name
                  2: FixedColumnWidth(280), // Course Name
                  3: FixedColumnWidth(220), // Faculty
                  4: FixedColumnWidth(240), // Venue
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  // Header Row
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                    children: [
                      _buildInfoTableHeaderCell('Course Code'),
                      _buildInfoTableHeaderCell('Course Short Name'),
                      _buildInfoTableHeaderCell('Course Name'),
                      _buildInfoTableHeaderCell('Faculty'),
                      _buildInfoTableHeaderCell('Venue'),
                    ],
                  ),
                  // Subject Rows
                  ...List.generate(displaySubjects.length, (idx) {
                    final sub = displaySubjects[idx];
                    final isLast = idx == displaySubjects.length - 1;
                    final subEntries = entries
                        .where((e) => e.subjectId == sub.id)
                        .toList();

                    // Resolve faculty names
                    final teacherNames = subEntries
                        .map((e) => staffMap[e.teacherId]?.name)
                        .whereType<String>()
                        .toSet()
                        .toList();
                    if (teacherNames.isEmpty &&
                        sub.assignedTeacherIds.isNotEmpty) {
                      for (final tId in sub.assignedTeacherIds) {
                        final name = staffMap[tId]?.name;
                        if (name != null) teacherNames.add(name);
                      }
                    }
                    final facultyStr = teacherNames.isNotEmpty
                        ? teacherNames.join(', ')
                        : '—';

                    // Include every configured batch and its assigned room.
                    String venueStr;
                    final batchEntries =
                        subEntries
                            .where((entry) => entry.batch != null)
                            .toList()
                          ..sort((a, b) => a.batch!.compareTo(b.batch!));
                    if (batchEntries.isNotEmpty) {
                      venueStr = batchEntries
                          .map(
                            (entry) =>
                                '${entry.batch}: ${roomMap[entry.roomId]?.roomNumber ?? 'Room'}',
                          )
                          .join(', ');
                    } else {
                      final entryRooms = subEntries
                          .map((e) => roomMap[e.roomId]?.roomNumber)
                          .whereType<String>()
                          .toSet()
                          .toList();
                      if (entryRooms.isNotEmpty) {
                        venueStr = entryRooms.join(', ');
                      } else {
                        venueStr = sub.requiredRoomType.isNotEmpty
                            ? sub.requiredRoomType
                            : 'Classroom';
                      }
                    }

                    final rowBg = idx.isEven
                        ? Colors.white
                        : const Color(0xFFF8FAFC);
                    final courseCodeStr = sub.subjectCode.trim().isNotEmpty
                        ? sub.subjectCode.trim()
                        : '—';
                    final courseShortNameStr = sub.shortName;

                    return TableRow(
                      decoration: BoxDecoration(color: rowBg),
                      children: [
                        _buildInfoTableCell(
                          courseCodeStr,
                          isLast: isLast,
                          isBold: true,
                        ),
                        _buildInfoTableCell(
                          courseShortNameStr,
                          isLast: isLast,
                          isBold: true,
                          textColor: const Color(0xFF1D4ED8),
                        ),
                        _buildInfoTableCell(sub.subjectName, isLast: isLast),
                        _buildInfoTableCell(facultyStr, isLast: isLast),
                        _buildInfoTableCell(venueStr, isLast: isLast),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTableHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
          right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildInfoTableCell(
    String text, {
    required bool isLast,
    bool isBold = false,
    Color textColor = const Color(0xFF1E293B),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          right: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }

  void _confirmDeleteTimetable(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Timetable?'),
        content: const Text(
          'This will remove the currently generated timetable. Your sections, subjects, professors, rooms and other input data will remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(timetableControllerProvider.notifier)
                    .deleteTimetable();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Timetable deleted successfully.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete timetable: $e'),
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

  void _showPublishDialog(BuildContext context, TimetableVersion version) {
    final changeLogCtrl = TextEditingController(
      text: 'Initial validated schedule for semester.',
    );
    final user = ref.read(currentProfileProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.publish, color: AppTheme.secondaryColor),
            const SizedBox(width: 8),
            Text('Publish Timetable: ${version.name}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Publishing this version makes it officially active for all students and faculty across the college. Any previously published schedule will be archived.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: changeLogCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Change Log / Release Notes',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            onPressed: () async {
              await ref
                  .read(timetableControllerProvider.notifier)
                  .publishVersion(
                    versionId: version.id,
                    publishedByName: user?.name ?? 'College Dean',
                    changeLog: changeLogCtrl.text.trim(),
                  );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Timetable "${version.name}" successfully published!',
                    ),
                  ),
                );
              }
            },
            child: const Text('Confirm & Publish'),
          ),
        ],
      ),
    );
  }
}
