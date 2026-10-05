import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/workflow_progress_bar.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../services/pdf_export_service.dart';
import '../timetable_utils.dart';

enum ExportFormat { printView, csv, pdf, json }

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportFormat _selectedFormat = ExportFormat.printView;
  String? _selectedSectionId;
  String? _selectedTeacherId;
  String? _selectedSubjectId;
  String? _selectedRoomId;
  String _targetView = 'section'; // 'section', 'teacher', 'course', 'room', 'master'

  @override
  Widget build(BuildContext context) {
    final college = ref.watch(currentCollegeProvider).value;
    final sections = ref.watch(sectionListProvider).value ?? [];
    final staffList = ref.watch(staffListProvider).value ?? [];
    final rooms = ref.watch(roomListProvider).value ?? [];
    final timeSlots = ref.watch(timeSlotsProvider).value ?? [];
    final subjects = ref.watch(subjectListProvider).value ?? [];
    final entriesAsync = ref.watch(timetableEntriesProvider);
    final entries = entriesAsync.value ?? [];
    final versionsAsync = ref.watch(timetableVersionsProvider);
    final versions = versionsAsync.value ?? [];
    final selectedVersionId = ref.watch(selectedVersionIdProvider);
    final activeVersion =
        versions.where((v) => v.id == selectedVersionId).firstOrNull ??
        versions.where((v) => v.status == 'draft').firstOrNull ??
        versions.firstOrNull;

    final globalSectionFilter = ref.watch(selectedSectionFilterProvider);
    final globalTeacherFilter = ref.watch(selectedTeacherFilterProvider);
    final globalRoomFilter = ref.watch(selectedRoomFilterProvider);

    if (_selectedSectionId == null && sections.isNotEmpty) {
      if (globalSectionFilter != null &&
          sections.any((s) => s.id == globalSectionFilter)) {
        _selectedSectionId = globalSectionFilter;
      } else {
        _selectedSectionId = sections.first.id;
      }
    }
    if (_selectedTeacherId == null && staffList.isNotEmpty) {
      if (globalTeacherFilter != null &&
          staffList.any((s) => s.id == globalTeacherFilter)) {
        _selectedTeacherId = globalTeacherFilter;
      } else {
        _selectedTeacherId = staffList.first.id;
      }
    }
    if (_selectedSubjectId == null && subjects.isNotEmpty) {
      _selectedSubjectId = subjects.first.id;
    }
    if (_selectedRoomId == null && rooms.isNotEmpty) {
      if (globalRoomFilter != null &&
          rooms.any((r) => r.id == globalRoomFilter)) {
        _selectedRoomId = globalRoomFilter;
      } else {
        _selectedRoomId = rooms.first.id;
      }
    }

    final staffMap = {for (var s in staffList) s.id: s};
    final sectionMap = {for (var s in sections) s.id: s};
    final roomMap = {for (var r in rooms) r.id: r};
    final subjectMap = {for (var s in subjects) s.id: s};
    final slotMap = {for (var s in timeSlots) s.id: s};

    final uniqueSections = sectionMap.values.toList();
    final uniqueStaff = staffMap.values.toList();
    final uniqueSubjects = subjectMap.values.toList();
    final uniqueRooms = roomMap.values.toList();
    final uniqueVersions = {for (var v in versions) v.id: v}.values.toList();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkflowProgressBar(currentStep: WorkflowStep.export),
            const SizedBox(height: 20),

            // Top Bar
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 750;
                final titleWidget = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export & Print Timetable',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Generate print-ready formats, CSV tables for Excel, PDF documents, and JSON structured payloads',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                );
                final actionsWidget = _buildActionButtons(
                  entries,
                  college,
                  activeVersion,
                  timeSlots,
                  staffMap,
                  sectionMap,
                  roomMap,
                  subjectMap,
                  slotMap,
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 16),
                      actionsWidget,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 16),
                    actionsWidget,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Format Selector Tabs
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<ExportFormat>(
                        segments: const [
                          ButtonSegment(
                            value: ExportFormat.printView,
                            label: Text('Print-Ready Matrix'),
                            icon: Icon(Icons.print_outlined),
                          ),
                          ButtonSegment(
                            value: ExportFormat.csv,
                            label: Text('CSV (Excel)'),
                            icon: Icon(Icons.table_chart_outlined),
                          ),
                          ButtonSegment(
                            value: ExportFormat.pdf,
                            label: Text('PDF Document'),
                            icon: Icon(Icons.picture_as_pdf_outlined),
                          ),
                          ButtonSegment(
                            value: ExportFormat.json,
                            label: Text('JSON Data'),
                            icon: Icon(Icons.code_outlined),
                          ),
                        ],
                        selected: {_selectedFormat},
                        onSelectionChanged: (set) =>
                            setState(() => _selectedFormat = set.first),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (entriesAsync.isLoading)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading timetable entries...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (entries.isEmpty)
              Card(
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
              )
            else ...[
              // Filters: Timetable Version & View Target (Section, Teacher, Room)
              if (_selectedFormat != ExportFormat.json)
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
                        if (versions.isNotEmpty) ...[
                          Builder(builder: (context) {
                            final effectiveVerId = (selectedVersionId != null &&
                                    uniqueVersions.any((v) => v.id == selectedVersionId))
                                ? selectedVersionId
                                : (activeVersion?.id ?? uniqueVersions.first.id);
                            return DropdownButtonFormField<String>(
                              key: ValueKey(effectiveVerId),
                              initialValue: effectiveVerId,
                              decoration: const InputDecoration(
                                labelText: 'Timetable Version',
                                prefixIcon: Icon(Icons.history, size: 18),
                                isDense: true,
                              ),
                              items: uniqueVersions
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v.id,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(v.name),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
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
                                if (val != null) {
                                  ref
                                      .read(selectedVersionIdProvider.notifier)
                                      .state = val;
                                }
                              },
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 650;
                            final chips = Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  'Export View:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text('Section'),
                                  selected: _targetView == 'section',
                                  onSelected: (_) =>
                                      setState(() => _targetView = 'section'),
                                ),
                                ChoiceChip(
                                  label: Stack(
                                    alignment: Alignment.center,
                                    children: const [
                                      Text('Faculty'),
                                      Opacity(
                                        opacity: 0.0,
                                        child: Text('By Professor'),
                                      ),
                                    ],
                                  ),
                                  selected: _targetView == 'teacher',
                                  onSelected: (_) =>
                                      setState(() => _targetView = 'teacher'),
                                ),
                                ChoiceChip(
                                  label: const Text('Course'),
                                  selected: _targetView == 'course',
                                  onSelected: (_) =>
                                      setState(() => _targetView = 'course'),
                                ),
                                ChoiceChip(
                                  label: const Text('Room / Lab'),
                                  selected: _targetView == 'room',
                                  onSelected: (_) =>
                                      setState(() => _targetView = 'room'),
                                ),
                                ChoiceChip(
                                  label: const Text('Master'),
                                  selected: _targetView == 'master',
                                  onSelected: (_) =>
                                      setState(() => _targetView = 'master'),
                                ),
                              ],
                            );

                            final effectiveSectionId = (_selectedSectionId != null &&
                                    uniqueSections.any((s) => s.id == _selectedSectionId))
                                ? _selectedSectionId
                                : (uniqueSections.isNotEmpty ? uniqueSections.first.id : null);
                            final effectiveTeacherId = (_selectedTeacherId != null &&
                                    uniqueStaff.any((s) => s.id == _selectedTeacherId))
                                ? _selectedTeacherId
                                : (uniqueStaff.isNotEmpty ? uniqueStaff.first.id : null);
                            final effectiveSubjectId = (_selectedSubjectId != null &&
                                    uniqueSubjects.any((s) => s.id == _selectedSubjectId))
                                ? _selectedSubjectId
                                : (uniqueSubjects.isNotEmpty ? uniqueSubjects.first.id : null);
                            final effectiveRoomId = (_selectedRoomId != null &&
                                    uniqueRooms.any((r) => r.id == _selectedRoomId))
                                ? _selectedRoomId
                                : (uniqueRooms.isNotEmpty ? uniqueRooms.first.id : null);

                            Widget selector;
                            if (_targetView == 'section') {
                              selector = DropdownButtonFormField<String>(
                                key: ValueKey('sec_$effectiveSectionId'),
                                initialValue: effectiveSectionId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Section',
                                  isDense: true,
                                ),
                                items: uniqueSections
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(s.displayName),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() => _selectedSectionId = val);
                                  ref
                                      .read(selectedSectionFilterProvider.notifier)
                                      .state = val;
                                },
                              );
                            } else if (_targetView == 'teacher') {
                              selector = DropdownButtonFormField<String>(
                                key: ValueKey('tea_$effectiveTeacherId'),
                                initialValue: effectiveTeacherId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Faculty',
                                  isDense: true,
                                ),
                                items: uniqueStaff
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(
                                          s.designation.isNotEmpty
                                              ? '${s.name} (${s.designation})'
                                              : s.name,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() => _selectedTeacherId = val);
                                  ref
                                      .read(selectedTeacherFilterProvider.notifier)
                                      .state = val;
                                },
                              );
                            } else if (_targetView == 'course') {
                              selector = DropdownButtonFormField<String>(
                                key: ValueKey('sub_$effectiveSubjectId'),
                                initialValue: effectiveSubjectId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Course / Subject',
                                  isDense: true,
                                ),
                                items: uniqueSubjects
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(
                                          '${s.subjectName} (${s.subjectCode})',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() => _selectedSubjectId = val);
                                },
                              );
                            } else if (_targetView == 'room') {
                              selector = DropdownButtonFormField<String>(
                                key: ValueKey('room_$effectiveRoomId'),
                                initialValue: effectiveRoomId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Room / Lab',
                                  isDense: true,
                                ),
                                items: uniqueRooms
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r.id,
                                        child: Text(
                                          '${r.roomNumber} (${r.roomType})',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() => _selectedRoomId = val);
                                  ref
                                      .read(selectedRoomFilterProvider.notifier)
                                      .state = val;
                                },
                              );
                            } else {
                              selector = Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Color(0xFF2563EB),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Consolidated master timetable schedule across all sections, faculties, and rooms.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1E3A8A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  chips,
                                  const SizedBox(height: 12),
                                  selector,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                chips,
                                const SizedBox(width: 24),
                                Expanded(child: selector),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Active Preview Container
              _buildActiveFormatPreview(
                entries: entries,
                college: college,
                activeVersion: activeVersion,
                sections: sections,
                staffList: staffList,
                rooms: rooms,
                timeSlots: timeSlots,
                subjects: subjects,
                staffMap: staffMap,
                sectionMap: sectionMap,
                roomMap: roomMap,
                subjectMap: subjectMap,
                slotMap: slotMap,
              ),
            ],

            // Step Navigation Controls
            WorkflowBottomBar(
              backLabel: '← Back to Conflict Center',
              onBack: () => context.go('/conflicts'),
              nextLabel: 'All Workflow Steps Completed',
              isNextEnabled: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    List<TimetableEntry> entries,
    College? college,
    TimetableVersion? version,
    List<TimeSlot> timeSlots,
    Map<String, Staff> staffMap,
    Map<String, Section> sectionMap,
    Map<String, Room> roomMap,
    Map<String, Subject> subjectMap,
    Map<String, TimeSlot> slotMap,
  ) {
    switch (_selectedFormat) {
      case ExportFormat.printView:
        return ElevatedButton.icon(
          onPressed: () async {
            try {
              await PdfExportService.printTimetable(
                college: college,
                version: version,
                entries: entries,
                timeSlots: timeSlots,
                staffMap: staffMap,
                sectionMap: sectionMap,
                roomMap: roomMap,
                subjectMap: subjectMap,
                targetView: _targetView,
                selectedSectionId: _selectedSectionId,
                selectedTeacherId: _selectedTeacherId,
                selectedSubjectId: _selectedSubjectId,
                selectedRoomId: _selectedRoomId,
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Print error: $e')),
                );
              }
            }
          },
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Print Now'),
        );
      case ExportFormat.pdf:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await PdfExportService.printTimetable(
                    college: college,
                    version: version,
                    entries: entries,
                    timeSlots: timeSlots,
                    staffMap: staffMap,
                    sectionMap: sectionMap,
                    roomMap: roomMap,
                    subjectMap: subjectMap,
                    targetView: _targetView,
                    selectedSectionId: _selectedSectionId,
                    selectedTeacherId: _selectedTeacherId,
                    selectedSubjectId: _selectedSubjectId,
                    selectedRoomId: _selectedRoomId,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PDF export error: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Print / Save PDF'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preparing PDF for sharing / download...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  await PdfExportService.shareTimetablePdf(
                    college: college,
                    version: version,
                    entries: entries,
                    timeSlots: timeSlots,
                    staffMap: staffMap,
                    sectionMap: sectionMap,
                    roomMap: roomMap,
                    subjectMap: subjectMap,
                    targetView: _targetView,
                    selectedSectionId: _selectedSectionId,
                    selectedTeacherId: _selectedTeacherId,
                    selectedSubjectId: _selectedSubjectId,
                    selectedRoomId: _selectedRoomId,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Share error: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share PDF'),
            ),
          ],
        );
      case ExportFormat.csv:
        return Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                final filteredEntries = entries.where((e) {
                  if (_targetView == 'section') return e.sectionId == _selectedSectionId;
                  if (_targetView == 'teacher') return e.teacherId == _selectedTeacherId;
                  if (_targetView == 'course') return e.subjectId == _selectedSubjectId;
                  if (_targetView == 'room') return e.roomId == _selectedRoomId;
                  return true;
                }).toList();
                final currentTeacher = staffMap[_selectedTeacherId];
                final currentSubject = subjectMap[_selectedSubjectId];
                ProfessorWorkloadSummary? workloadSummary;
                if (_targetView == 'teacher' && currentTeacher != null) {
                  workloadSummary = calculateProfessorWorkload(
                    teacher: currentTeacher,
                    allSubjects: subjectMap.values.toList(),
                    sectionMap: sectionMap,
                    entries: entries,
                    subjectMap: subjectMap,
                  );
                }
                final csvText = _generateCsvString(
                  filteredEntries,
                  staffMap,
                  sectionMap,
                  roomMap,
                  subjectMap,
                  slotMap,
                  targetView: _targetView,
                  selectedTeacher: currentTeacher,
                  selectedSubject: currentSubject,
                  workloadSummary: workloadSummary,
                );
                Clipboard.setData(ClipboardData(text: csvText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'CSV copied to clipboard! Paste directly into Excel or Google Sheets.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy CSV Data'),
            ),
          ],
        );
      case ExportFormat.json:
        return ElevatedButton.icon(
          onPressed: () {
            final jsonStr = _generateJsonString(
              entries,
              college,
              version,
              staffMap,
              sectionMap,
              roomMap,
              subjectMap,
            );
            Clipboard.setData(ClipboardData(text: jsonStr));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('JSON copied to clipboard!')),
            );
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy JSON'),
        );
    }
  }

  Widget _buildActiveFormatPreview({
    required List<TimetableEntry> entries,
    required College? college,
    required TimetableVersion? activeVersion,
    required List<Section> sections,
    required List<Staff> staffList,
    required List<Room> rooms,
    required List<TimeSlot> timeSlots,
    required List<Subject> subjects,
    required Map<String, Staff> staffMap,
    required Map<String, Section> sectionMap,
    required Map<String, Room> roomMap,
    required Map<String, Subject> subjectMap,
    required Map<String, TimeSlot> slotMap,
  }) {
    switch (_selectedFormat) {
      case ExportFormat.printView:
        if (_targetView == 'course') {
          return _buildCourseSchedulePreview(
            entries: entries,
            college: college,
            version: activeVersion,
            timeSlots: timeSlots,
            staffMap: staffMap,
            sectionMap: sectionMap,
            roomMap: roomMap,
            subjectMap: subjectMap,
          );
        }
        return _buildPrintMatrixPreview(
          entries,
          college,
          activeVersion,
          timeSlots,
          staffMap,
          sectionMap,
          roomMap,
          subjectMap,
        );
      case ExportFormat.csv:
        final filteredEntries = entries.where((e) {
          if (_targetView == 'section') return e.sectionId == _selectedSectionId;
          if (_targetView == 'teacher') return e.teacherId == _selectedTeacherId;
          if (_targetView == 'course') return e.subjectId == _selectedSubjectId;
          if (_targetView == 'room') return e.roomId == _selectedRoomId;
          return true;
        }).toList();
        final currentTeacher = staffMap[_selectedTeacherId];
        final currentSubject = subjectMap[_selectedSubjectId];
        ProfessorWorkloadSummary? workloadSummary;
        if (_targetView == 'teacher' && currentTeacher != null) {
          workloadSummary = calculateProfessorWorkload(
            teacher: currentTeacher,
            allSubjects: subjectMap.values.toList(),
            sectionMap: sectionMap,
            entries: entries,
            subjectMap: subjectMap,
          );
        }
        return _buildCsvPreview(
          filteredEntries,
          staffMap,
          sectionMap,
          roomMap,
          subjectMap,
          slotMap,
          targetView: _targetView,
          selectedTeacher: currentTeacher,
          selectedSubject: currentSubject,
          workloadSummary: workloadSummary,
        );
      case ExportFormat.pdf:
        return _buildPdfDocumentPreview(
          entries,
          college,
          activeVersion,
          timeSlots,
          staffMap,
          sectionMap,
          roomMap,
          subjectMap,
        );
      case ExportFormat.json:
        return _buildJsonPreview(
          entries,
          college,
          activeVersion,
          staffMap,
          sectionMap,
          roomMap,
          subjectMap,
        );
    }
  }

  // 1. Print Matrix Preview
  Widget _buildPrintMatrixPreview(
    List<TimetableEntry> entries,
    College? college,
    TimetableVersion? version,
    List<TimeSlot> timeSlots,
    Map<String, Staff> staffMap,
    Map<String, Section> sectionMap,
    Map<String, Room> roomMap,
    Map<String, Subject> subjectMap,
  ) {
    final days =
        college?.workingDays ??
        ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final sortedSlots = getEffectiveTimeSlots(timeSlots, college, entries);

    final currentTeacherId = (_selectedTeacherId != null &&
            staffMap.containsKey(_selectedTeacherId))
        ? _selectedTeacherId
        : staffMap.keys.firstOrNull;

    final filteredEntries = entries.where((e) {
      if (_targetView == 'section') return e.sectionId == _selectedSectionId;
      if (_targetView == 'teacher') return e.teacherId == currentTeacherId;
      if (_targetView == 'room') return e.roomId == _selectedRoomId;
      return true;
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_targetView == 'teacher' &&
                currentTeacherId != null &&
                staffMap[currentTeacherId] != null) ...[
              _buildProfessorWorkloadHeader(
                professor: staffMap[currentTeacherId]!,
                college: college,
                version: version,
                entries: entries,
                allSubjects: subjectMap.values.toList(),
                sectionMap: sectionMap,
                subjectMap: subjectMap,
              ),
            ] else ...[
              // 1. Timetable title/header & 2. Section / Semester information
              Center(
                child: Column(
                  children: [
                    Text(
                      college?.name ?? 'COLLEGE TIMETABLE',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_targetView == 'section' &&
                        sectionMap[_selectedSectionId] != null) ...[
                      Text(
                        'Section: ${sectionMap[_selectedSectionId]!.sectionName} • Semester: ${sectionMap[_selectedSectionId]!.semester}${sectionMap[_selectedSectionId]!.academicYear.isNotEmpty ? ' • ${sectionMap[_selectedSectionId]!.academicYear}' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Academic Session ${college?.academicYear ?? "2026-2027"} • ${_getTargetTitle(sectionMap, staffMap, roomMap, subjectMap)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'Version: ${version?.name ?? "Draft"} • Generated with TimePilot Engine',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24, thickness: 1.5),
            ],

            // 3. ACTUAL TIMETABLE MATRIX
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Builder(
                builder: (context) {
                  final middleDayIndex = days.length ~/ 2;

                  final Map<int, TableColumnWidth> columnWidths = {
                    0: const FixedColumnWidth(100),
                  };
                  for (int i = 0; i < sortedSlots.length; i++) {
                    final slot = sortedSlots[i];
                    if (slot.isBreak) {
                      columnWidths[i + 1] = const FixedColumnWidth(115);
                    } else {
                      columnWidths[i + 1] = const FixedColumnWidth(180);
                    }
                  }

                  String getCourseShortName(Subject? s) {
                    return s?.shortName ?? 'SUB';
                  }

                  return Table(
                    columnWidths: columnWidths,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      // Period Header Row (Row 0)
                      TableRow(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              border: Border(
                                top: BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                                bottom: BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                                left: BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                                right: BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Day',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF0F172A),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          ...sortedSlots.map((slot) {
                            if (slot.isBreak) {
                              final isLunch =
                                  slot.breakTitle?.toLowerCase().contains(
                                    'lunch',
                                  ) ==
                                  true;
                              final headerTitle = isLunch
                                  ? 'Lunch'
                                  : (slot.breakTitle?.toLowerCase().contains(
                                              'break',
                                            ) ==
                                            true
                                        ? 'Break'
                                        : (slot.breakTitle ?? 'Break'));
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isLunch
                                      ? const Color(0xFFFED7AA)
                                      : const Color(0xFFFDE68A),
                                  border: Border(
                                    top: BorderSide(
                                      color: isLunch
                                          ? const Color(0xFFF97316)
                                          : const Color(0xFFF59E0B),
                                      width: 1,
                                    ),
                                    bottom: BorderSide(
                                      color: isLunch
                                          ? const Color(0xFFF97316)
                                          : const Color(0xFFF59E0B),
                                      width: 1,
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
                                      fontSize: 11,
                                      color: isLunch
                                          ? const Color(0xFF9A3412)
                                          : const Color(0xFF92400E),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            // Academic Slot Header
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 10,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(
                                  top: BorderSide(
                                    color: Color(0xFFCBD5E1),
                                    width: 1,
                                  ),
                                  bottom: BorderSide(
                                    color: Color(0xFFCBD5E1),
                                    width: 1,
                                  ),
                                  left: BorderSide(
                                    color: Color(0xFFCBD5E1),
                                    width: 1,
                                  ),
                                  right: BorderSide(
                                    color: Color(0xFFCBD5E1),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Period ${slot.periodNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
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
                              horizontal: 6,
                              vertical: 6,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                                left: BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                                right: BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'From',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: Color(0xFF475569),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          ...sortedSlots.map((slot) {
                            final isLunch =
                                slot.isBreak &&
                                slot.breakTitle?.toLowerCase().contains(
                                      'lunch',
                                    ) ==
                                    true;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
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
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: slot.isBreak
                                        ? (isLunch
                                              ? const Color(0xFF9A3412)
                                              : const Color(0xFF92400E))
                                        : const Color(0xFF334155),
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
                              horizontal: 6,
                              vertical: 6,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                                left: BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                                right: BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'To',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: Color(0xFF475569),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          ...sortedSlots.map((slot) {
                            final isLunch =
                                slot.isBreak &&
                                slot.breakTitle?.toLowerCase().contains(
                                      'lunch',
                                    ) ==
                                    true;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
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
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: slot.isBreak
                                        ? (isLunch
                                              ? const Color(0xFF9A3412)
                                              : const Color(0xFF92400E))
                                        : const Color(0xFF334155),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),

                      // Day Rows
                      ...List.generate(days.length, (dayIndex) {
                        final day = days[dayIndex];
                        final isLastDay = dayIndex == days.length - 1;

                        return TableRow(
                          children: [
                            Container(
                              constraints: const BoxConstraints(minHeight: 56),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border(
                                  left: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                    width: 1,
                                  ),
                                  right: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                    width: 1,
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
                                    fontSize: 11,
                                    color: Color(0xFF1E293B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            ...sortedSlots.map((slot) {
                              if (slot.isBreak) {
                                final isLunch =
                                    slot.breakTitle?.toLowerCase().contains(
                                      'lunch',
                                    ) ==
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
                                final breakTitle =
                                    slot.breakTitle ??
                                    (isLunch ? 'Lunch Break' : 'Tea Break');

                                return TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.fill,
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
                                      vertical: 8,
                                    ),
                                    child: Center(
                                      child: dayIndex == middleDayIndex
                                          ? Text(
                                              breakTitle,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                                color: breakTextColor,
                                              ),
                                              textAlign: TextAlign.center,
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ),
                                );
                              }

                              final matches = filteredEntries
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

                              if (matches.isEmpty) {
                                return TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 56,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                        bottom: bottomBorderSide,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(8.0),
                                    child: Center(
                                      child: Text(
                                        _targetView == 'room' ? 'FREE' : '—',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _targetView == 'room'
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFFCBD5E1),
                                          fontWeight: _targetView == 'room'
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          fontSize: _targetView == 'room' ? 11 : 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              if (_targetView == 'teacher') {
                                return _buildTeacherMatrixCell(
                                  matches: matches,
                                  subjectMap: subjectMap,
                                  sectionMap: sectionMap,
                                  roomMap: roomMap,
                                  bottomBorderSide: bottomBorderSide,
                                );
                              }

                              // Render all allocations faithfully without hardcoded batch shortcuts

                              // Single lab or theory entries
                              return TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 56,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                      bottom: bottomBorderSide,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(4.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (matches.length > 1 &&
                                          matches.every(
                                            (match) => match.batch != null,
                                          ))
                                        const Text(
                                          'PARALLEL LAB BATCHES',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ...matches.asMap().entries.map((item) {
                                        final index = item.key;
                                        final match = item.value;
                                        final subj =
                                            subjectMap[match.subjectId];
                                        final prof = staffMap[match.teacherId];
                                        final room = roomMap[match.roomId];
                                        final isLab =
                                            subj?.isLab == true ||
                                            match.batch != null;
                                        final shortName = getCourseShortName(
                                          subj,
                                        );
                                        final rName =
                                            room?.roomNumber ?? 'Room';

                                        final card = Container(
                                          color: isLab
                                              ? const Color(0xFFEFF6FF)
                                              : Colors.white,
                                          padding: const EdgeInsets.all(4.0),
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 1.0,
                                          ),
                                          child: isLab
                                              ? Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      shortName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 10,
                                                        color: Color(
                                                          0xFF1E3A8A,
                                                        ),
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    if (match.batch != null)
                                                      Text(
                                                        match.batch!,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 9,
                                                          color: Color(
                                                            0xFF2563EB,
                                                          ),
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    Text(
                                                      prof?.name ?? 'Teacher',
                                                      style: const TextStyle(
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF0F172A,
                                                        ),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    if (_targetView == 'room' || _targetView == 'master')
                                                      Text(
                                                        sectionMap[match.sectionId]?.displayName ?? match.sectionId,
                                                        style: const TextStyle(
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF1D4ED8),
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    if (_targetView != 'room')
                                                      Text(
                                                        rName,
                                                        style: const TextStyle(
                                                          fontSize: 8.5,
                                                          color: Color(
                                                            0xFF475569,
                                                         ),
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                  ],
                                                )
                                              : Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      shortName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 10,
                                                        color: Color(
                                                          0xFF15803D,
                                                        ),
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    Text(
                                                      subj?.subjectName ?? '',
                                                      style: const TextStyle(
                                                        fontSize: 8.5,
                                                        color: Color(
                                                          0xFF475569,
                                                        ),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      prof?.name ?? '',
                                                      style: const TextStyle(
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF0F172A,
                                                        ),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    if (_targetView == 'room' || _targetView == 'master')
                                                      Text(
                                                        sectionMap[match.sectionId]?.displayName ?? match.sectionId,
                                                        style: const TextStyle(
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF1D4ED8),
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    if (_targetView != 'room')
                                                      Text(
                                                        rName,
                                                        style: const TextStyle(
                                                          fontSize: 8,
                                                          color: Color(
                                                            0xFF64748B,
                                                          ),
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                  ],
                                                ),
                                        );

                                        if (index > 0 &&
                                            matches.length > 1 &&
                                            matches.every((e) => e.batch != null)) {
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 2,
                                                ),
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: const [
                                                      SizedBox(
                                                        width: 16,
                                                        child: Divider(
                                                          height: 1,
                                                          thickness: 0.5,
                                                          color: Color(0xFFBFDBFE),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 4,
                                                            ),
                                                        child: Text(
                                                          'and simultaneously:',
                                                          style: TextStyle(
                                                            fontSize: 7.5,
                                                            fontStyle:
                                                                FontStyle.italic,
                                                            color: Color(
                                                              0xFF3B82F6,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 16,
                                                        child: Divider(
                                                          height: 1,
                                                          thickness: 0.5,
                                                          color: Color(0xFFBFDBFE),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
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
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 4. Course / Faculty / Venue Information table
            if (_targetView == 'teacher')
              _buildFacultyCourseWorkloadTable(
                teacher: staffMap[currentTeacherId],
                entries: filteredEntries,
                allSubjects: subjectMap.values.toList(),
                sectionMap: sectionMap,
                roomMap: roomMap,
              )
            else
              _buildExportCourseFacultyVenueTable(
                entries: filteredEntries,
                subjects: subjectMap.values.toList(),
                staffMap: staffMap,
                roomMap: roomMap,
                targetSection: _targetView == 'section'
                    ? sectionMap[_selectedSectionId]
                    : null,
              ),
            const SizedBox(height: 32),

            // 5. Signature/footer area
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _signatureBox(_targetView == 'teacher'
                    ? 'Faculty Signature'
                    : 'Timetable Coordinator'),
                _signatureBox('Head of Department'),
                _signatureBox('Principal / Dean of Academics'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCourseFacultyVenueTable({
    required List<TimetableEntry> entries,
    required List<Subject> subjects,
    required Map<String, Staff> staffMap,
    required Map<String, Room> roomMap,
    required Section? targetSection,
  }) {
    final infoItems = extractCourseFacultyVenueInfo(
      entries: entries,
      subjects: subjects,
      staffMap: staffMap,
      roomMap: roomMap,
      targetSection: targetSection,
      viewMode: _targetView,
    );

    if (infoItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            border: Border(
              top: BorderSide(color: Color(0xFFCBD5E1), width: 1),
              bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
              left: BorderSide(color: Color(0xFFCBD5E1), width: 1),
              right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.table_view_outlined,
                size: 16,
                color: Color(0xFF1E293B),
              ),
              const SizedBox(width: 8),
              const Text(
                'Course / Faculty / Venue Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (targetSection != null) ...[
                const SizedBox(width: 6),
                Text(
                  '• ${targetSection.displayName}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(110), // Course Code
              1: FixedColumnWidth(130), // Course Short Name
              2: FixedColumnWidth(230), // Course Name
              3: FixedColumnWidth(180), // Faculty
              4: FixedColumnWidth(180), // Venue
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header Row
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                children: [
                  _buildExportTableHeaderCell('Course Code'),
                  _buildExportTableHeaderCell('Course Short Name'),
                  _buildExportTableHeaderCell('Course Name'),
                  _buildExportTableHeaderCell('Faculty'),
                  _buildExportTableHeaderCell('Venue'),
                ],
              ),
              // Data Rows
              ...List.generate(infoItems.length, (idx) {
                final item = infoItems[idx];
                final isLast = idx == infoItems.length - 1;
                final rowBg = idx.isEven
                    ? Colors.white
                    : const Color(0xFFF8FAFC);

                return TableRow(
                  decoration: BoxDecoration(color: rowBg),
                  children: [
                    _buildExportTableCell(
                      item.courseCode,
                      isLast: isLast,
                      isBold: true,
                    ),
                    _buildExportTableCell(
                      item.courseShortName,
                      isLast: isLast,
                      isBold: true,
                      textColor: const Color(0xFF1D4ED8),
                    ),
                    _buildExportTableCell(item.courseName, isLast: isLast),
                    _buildExportTableCell(item.faculty, isLast: isLast),
                    _buildExportTableCell(item.venue, isLast: isLast),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExportTableHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
          left: BorderSide(color: Color(0xFFCBD5E1), width: 1),
          right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildExportTableCell(
    String text, {
    required bool isLast,
    bool isBold = false,
    Color textColor = const Color(0xFF334155),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          left: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
          right: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }

  // ==================== PROFESSOR VIEW HELPERS ====================

  Widget _buildProfessorWorkloadHeader({
    required Staff professor,
    required College? college,
    required TimetableVersion? version,
    required List<TimetableEntry> entries,
    required List<Subject> allSubjects,
    required Map<String, Section> sectionMap,
    required Map<String, Subject> subjectMap,
  }) {
    final summary = calculateProfessorWorkload(
      teacher: professor,
      allSubjects: allSubjects,
      sectionMap: sectionMap,
      entries: entries,
      subjectMap: subjectMap,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // College and Timetable Title
          Center(
            child: Column(
              children: [
                Text(
                  college?.name ?? 'COLLEGE TIMETABLE',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'FACULTY WORKLOAD & TIME-TABLE • ${college?.academicYear ?? "2026-2027"}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version: ${version?.name ?? "Draft"} • Generated with TimePilot Engine',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 14),

          // Professor Name & Status Badge Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Professor: ${professor.name}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${professor.designation} • Department: ${professor.departmentId.isNotEmpty ? professor.departmentId : "Computer Science & Engineering"}${professor.employeeId.isNotEmpty ? " • Emp ID: ${professor.employeeId}" : ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: summary.remaining == 0
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: summary.remaining == 0
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFFCD34D),
                  ),
                ),
                child: Text(
                  summary.remaining == 0
                      ? (summary.isOverload
                          ? 'OVERLOAD (+${summary.overload}h)'
                          : 'WORKLOAD COMPLETE')
                      : '${summary.remaining} HRS REMAINING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: summary.remaining == 0
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Three Metric Cards (Excel / KPI format)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final cards = [
                _buildWorkloadKpiCard(
                  title: 'Required Workload',
                  value: '${summary.requiredWorkload} hrs',
                  subtitle: 'Target weekly hours',
                  icon: Icons.assignment_outlined,
                  color: const Color(0xFF2563EB),
                ),
                _buildWorkloadKpiCard(
                  title: 'Scheduled Workload',
                  value: '${summary.scheduledTotal} hrs',
                  subtitle:
                      'Theory: ${summary.scheduledTheory} hrs • Lab: ${summary.scheduledLab} hrs',
                  icon: Icons.calendar_month_outlined,
                  color: const Color(0xFF10B981),
                ),
                _buildWorkloadKpiCard(
                  title: 'Remaining Workload',
                  value: summary.remaining == 0 && summary.isOverload
                      ? '0 hrs (+${summary.overload})'
                      : '${summary.remaining} hrs',
                  subtitle: summary.remaining == 0
                      ? 'Full workload scheduled'
                      : 'Pending class allocation',
                  icon: Icons.hourglass_bottom_outlined,
                  color: summary.remaining > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF059669),
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: cards
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: c,
                          ))
                      .toList(),
                );
              }

              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[2]),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Workload Breakdown Strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 14,
              runSpacing: 6,
              children: [
                _buildBreakdownChip('Theory', '${summary.scheduledTheory} hrs'),
                const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                _buildBreakdownChip('Lab', '${summary.scheduledLab} hrs'),
                const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                _buildBreakdownChip('Total Scheduled', '${summary.scheduledTotal} hrs'),
                const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                _buildBreakdownChip('Required', '${summary.requiredWorkload} hrs'),
                const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                _buildBreakdownChip(
                  'Remaining',
                  summary.remaining == 0 && summary.isOverload
                      ? '0 hrs (+${summary.overload}h)'
                      : '${summary.remaining} hrs',
                  color: summary.remaining > 0
                      ? const Color(0xFFB45309)
                      : const Color(0xFF15803D),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkloadKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownChip(String label, String value, {Color? color}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherMatrixCell({
    required List<TimetableEntry> matches,
    required Map<String, Subject> subjectMap,
    required Map<String, Section> sectionMap,
    required Map<String, Room> roomMap,
    required BorderSide bottomBorderSide,
  }) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            right: const BorderSide(
              color: Color(0xFFCBD5E1),
              width: 1,
            ),
            bottom: bottomBorderSide,
          ),
        ),
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: matches.map((match) {
            final subj = subjectMap[match.subjectId];
            final sec = sectionMap[match.sectionId];
            final room = roomMap[match.roomId];
            final isLab = subj?.isLab == true || match.batch != null;

            final shortName = subj?.shortName ?? 'SUB';
            final secName = sec?.displayName ?? sec?.sectionName ?? 'Section';
            final roomName = room?.roomNumber ?? (isLab ? 'Lab' : 'Room');
            final batchStr = match.batch;

            if (isLab) {
              // Lab Cell
              // Format:
              // DSA LAB
              // CSE(AIML)
              // B1
              // Lab 108
              final displayTitle = shortName.toUpperCase().contains('LAB')
                  ? shortName.toUpperCase()
                  : '$shortName LAB';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  border: Border.all(color: const Color(0xFF93C5FD), width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      displayTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Color(0xFF1E3A8A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      secName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                        color: Color(0xFF1D4ED8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (batchStr != null && batchStr.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: const Color(0xFF60A5FA), width: 0.5),
                          ),
                          child: Text(
                            batchStr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 8.5,
                              color: Color(0xFF1D4ED8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    Text(
                      roomName,
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFF475569),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            } else {
              // Theory Cell
              // Format:
              // DSA
              // CSE(AIML)
              // Room 102
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      shortName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      secName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                        color: Color(0xFF2563EB),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      roomName,
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFacultyCourseWorkloadTable({
    required Staff? teacher,
    required List<TimetableEntry> entries,
    required List<Subject> allSubjects,
    required Map<String, Section> sectionMap,
    required Map<String, Room> roomMap,
  }) {
    if (teacher == null) return const SizedBox.shrink();

    final teacherSubjs = allSubjects
        .where((s) => s.assignedTeacherIds.contains(teacher.id))
        .toList();

    final entrySubjIds = entries
        .where((e) => e.teacherId == teacher.id)
        .map((e) => e.subjectId)
        .toSet();
    for (final s in allSubjects) {
      if (entrySubjIds.contains(s.id) && !teacherSubjs.any((ts) => ts.id == s.id)) {
        teacherSubjs.add(s);
      }
    }

    teacherSubjs.sort((a, b) => a.shortName.compareTo(b.shortName));

    if (teacherSubjs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            border: Border(
              top: BorderSide(color: Color(0xFFCBD5E1), width: 1),
              bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
              left: BorderSide(color: Color(0xFFCBD5E1), width: 1),
              right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 16, color: Color(0xFF1E293B)),
              const SizedBox(width: 8),
              Text(
                'Teaching Course Allocations • ${teacher.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(100), // Code
              1: FixedColumnWidth(110), // Short Name
              2: FixedColumnWidth(210), // Subject Name
              3: FixedColumnWidth(90),  // Type
              4: FixedColumnWidth(180), // Section & Batches
              5: FixedColumnWidth(110), // Weekly Load
              6: FixedColumnWidth(140), // Venue
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                children: [
                  _buildExportTableHeaderCell('Course Code'),
                  _buildExportTableHeaderCell('Short Name'),
                  _buildExportTableHeaderCell('Subject Name'),
                  _buildExportTableHeaderCell('Type'),
                  _buildExportTableHeaderCell('Section & Batches'),
                  _buildExportTableHeaderCell('Weekly Load'),
                  _buildExportTableHeaderCell('Assigned Venue'),
                ],
              ),
              ...List.generate(teacherSubjs.length, (idx) {
                final sub = teacherSubjs[idx];
                final isLast = idx == teacherSubjs.length - 1;
                final subEntries = entries
                    .where((e) => e.teacherId == teacher.id && e.subjectId == sub.id)
                    .toList();
                final sec = sectionMap[sub.sectionId];
                final batches = subEntries
                    .map((e) => e.batch)
                    .whereType<String>()
                    .toSet()
                    .toList()
                  ..sort();
                final batchStr =
                    batches.isNotEmpty ? ' (Batch ${batches.join(', ')})' : '';
                final secDisplayName = sec != null
                    ? '${sec.displayName}$batchStr'
                    : (batches.isNotEmpty ? 'Batch ${batches.join(', ')}' : '—');

                final venues = subEntries
                    .map((e) => roomMap[e.roomId]?.roomNumber)
                    .whereType<String>()
                    .toSet()
                    .toList();
                final venueStr = venues.isNotEmpty
                    ? venues.join(', ')
                    : (sub.requiredRoomType.isNotEmpty
                        ? sub.requiredRoomType
                        : 'Room');

                final rowBg = idx.isEven ? Colors.white : const Color(0xFFF8FAFC);
                final isLab = sub.isLab;

                return TableRow(
                  decoration: BoxDecoration(color: rowBg),
                  children: [
                    _buildExportTableCell(
                      sub.subjectCode.isNotEmpty ? sub.subjectCode : '—',
                      isLast: isLast,
                      isBold: true,
                    ),
                    _buildExportTableCell(
                      sub.shortName,
                      isLast: isLast,
                      isBold: true,
                      textColor: isLab
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF15803D),
                    ),
                    _buildExportTableCell(sub.subjectName, isLast: isLast),
                    _buildExportTableCell(
                      isLab ? 'Lab' : 'Theory',
                      isLast: isLast,
                      textColor: isLab
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF334155),
                    ),
                    _buildExportTableCell(secDisplayName, isLast: isLast),
                    _buildExportTableCell(
                      '${subEntries.length} hrs/wk',
                      isLast: isLast,
                      isBold: true,
                    ),
                    _buildExportTableCell(venueStr, isLast: isLast),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== COURSE VIEW HELPERS ====================

  Widget _buildCourseSchedulePreview({
    required List<TimetableEntry> entries,
    required College? college,
    required TimetableVersion? version,
    required List<TimeSlot> timeSlots,
    required Map<String, Staff> staffMap,
    required Map<String, Section> sectionMap,
    required Map<String, Room> roomMap,
    required Map<String, Subject> subjectMap,
  }) {
    final sub = subjectMap[_selectedSubjectId];
    final courseEntries = entries.where((e) => e.subjectId == _selectedSubjectId).toList();
    final days = college?.workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final dayIndexMap = {for (int i = 0; i < days.length; i++) days[i]: i};

    final sortedEntries = [...courseEntries]..sort((a, b) {
      final da = dayIndexMap[a.dayOfWeek] ?? 99;
      final db = dayIndexMap[b.dayOfWeek] ?? 99;
      if (da != db) return da.compareTo(db);
      if (a.periodNumber != b.periodNumber) return a.periodNumber.compareTo(b.periodNumber);
      return (a.batch ?? '').compareTo(b.batch ?? '');
    });

    final slotMap = {for (final s in timeSlots) s.periodNumber: s};

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub != null ? '${sub.subjectName} (${sub.subjectCode})' : 'Course Schedule',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: ${sub?.subjectType ?? "Theory"} • Required Hours/Wk: ${sub?.hoursPerWeek ?? 0} • Total Scheduled: ${sortedEntries.length} sessions',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Text(
                    'OFFICIAL COURSE SCHEDULE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            if (sortedEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Text(
                    'No scheduled sessions found for this course.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Day', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Period', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Section', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Batch', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Faculty', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Room', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: sortedEntries.map((e) {
                    final slot = slotMap[e.periodNumber];
                    final timeStr = slot != null ? '${slot.startTime} - ${slot.endTime}' : '-';
                    final sec = sectionMap[e.sectionId];
                    final teacher = staffMap[e.teacherId];
                    final room = roomMap[e.roomId];
                    final isLab = (sub?.isLab ?? false) || e.batch != null;

                    return DataRow(
                      cells: [
                        DataCell(Text(e.dayOfWeek, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text('Period ${e.periodNumber}')),
                        DataCell(Text(timeStr)),
                        DataCell(Text(sec?.displayName ?? e.sectionId)),
                        DataCell(
                          e.batch != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF93C5FD)),
                                  ),
                                  child: Text(
                                    e.batch!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                )
                              : const Text('Whole Section', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ),
                        DataCell(Text(teacher?.name ?? e.teacherId)),
                        DataCell(Text(room != null ? '${room.roomNumber} (${room.roomType})' : e.roomId)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isLab ? const Color(0xFFF3E8FF) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isLab ? const Color(0xFFD8B4FE) : const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Text(
                              isLab ? 'Lab' : 'Theory',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                color: isLab ? const Color(0xFF6B21A8) : const Color(0xFF166534),
                              ),
                            ),
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
    );
  }

  // 2. CSV Preview
  Widget _buildCsvPreview(
    List<TimetableEntry> entries,
    Map<String, Staff> staffMap,
    Map<String, Section> sectionMap,
    Map<String, Room> roomMap,
    Map<String, Subject> subjectMap,
    Map<String, TimeSlot> slotMap, {
    String? targetView,
    Staff? selectedTeacher,
    Subject? selectedSubject,
    ProfessorWorkloadSummary? workloadSummary,
  }) {
    final csvContent = _generateCsvString(
      entries,
      staffMap,
      sectionMap,
      roomMap,
      subjectMap,
      slotMap,
      targetView: targetView,
      selectedTeacher: selectedTeacher,
      selectedSubject: selectedSubject,
      workloadSummary: workloadSummary,
    );

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
                const Text(
                  'RFC-4180 Standard CSV Representation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: csvContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CSV Copied!')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy to Clipboard'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 300,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  csvContent,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. PDF Preview
  Widget _buildPdfDocumentPreview(
    List<TimetableEntry> entries,
    College? college,
    TimetableVersion? version,
    List<TimeSlot> timeSlots,
    Map<String, Staff> staffMap,
    Map<String, Section> sectionMap,
    Map<String, Room> roomMap,
    Map<String, Subject> subjectMap,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      college?.name ?? 'COLLEGE TIMETABLE',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      college?.academicYear != null
                          ? 'ACADEMIC SCHEDULE • ${college!.academicYear}'
                          : 'OFFICIAL ACADEMIC SCHEDULE',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Text(
                        'VERIFIED • 0 CONFLICTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await PdfExportService.printTimetable(
                            college: college,
                            version: version,
                            entries: entries,
                            timeSlots: timeSlots,
                            staffMap: staffMap,
                            sectionMap: sectionMap,
                            roomMap: roomMap,
                            subjectMap: subjectMap,
                            targetView: _targetView,
                            selectedSectionId: _selectedSectionId,
                            selectedTeacherId: _selectedTeacherId,
                            selectedSubjectId: _selectedSubjectId,
                            selectedRoomId: _selectedRoomId,
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Print error: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('Print / Save PDF'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preparing PDF for sharing / download...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          await PdfExportService.shareTimetablePdf(
                            college: college,
                            version: version,
                            entries: entries,
                            timeSlots: timeSlots,
                            staffMap: staffMap,
                            sectionMap: sectionMap,
                            roomMap: roomMap,
                            subjectMap: subjectMap,
                            targetView: _targetView,
                            selectedSectionId: _selectedSectionId,
                            selectedTeacherId: _selectedTeacherId,
                            selectedSubjectId: _selectedSubjectId,
                            selectedRoomId: _selectedRoomId,
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Share error: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Share PDF'),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 28),

            Text(
              'OFFICIAL TIMETABLE: ${_getTargetTitle(sectionMap, staffMap, roomMap, subjectMap)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),

            _targetView == 'course'
                ? _buildCourseSchedulePreview(
                    entries: entries,
                    college: college,
                    version: version,
                    timeSlots: timeSlots,
                    staffMap: staffMap,
                    sectionMap: sectionMap,
                    roomMap: roomMap,
                    subjectMap: subjectMap,
                  )
                : _buildPrintMatrixPreview(
                    entries,
                    college,
                    version,
                    timeSlots,
                    staffMap,
                    sectionMap,
                    roomMap,
                    subjectMap,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _signatureBox(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(width: 180, height: 1, color: const Color(0xFF94A3B8)),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  // 4. JSON Preview
  Widget _buildJsonPreview(
    List<TimetableEntry> entries,
    College? college,
    TimetableVersion? version,
    Map<String, Staff> staffMap,
    Map<String, Section> sectionMap,
    Map<String, Room> roomMap,
    Map<String, Subject> subjectMap,
  ) {
    final jsonText = _generateJsonString(
      entries,
      college,
      version,
      staffMap,
      sectionMap,
      roomMap,
      subjectMap,
    );

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
                const Text(
                  'Structured JSON Payload',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: jsonText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON Copied!')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy JSON'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 350,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF4ADE80),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTargetTitle(
    Map<String, Section> sectionMap,
    Map<String, Staff> staffMap,
    Map<String, Room> roomMap, [
    Map<String, Subject>? subjectMap,
  ]) {
    if (_targetView == 'section') {
      return sectionMap[_selectedSectionId]?.displayName ?? 'Section Timetable';
    } else if (_targetView == 'teacher') {
      return 'Faculty: ${staffMap[_selectedTeacherId]?.name ?? "Teacher"}';
    } else if (_targetView == 'course') {
      final sub = subjectMap?[_selectedSubjectId];
      return 'Course: ${sub != null ? "${sub.subjectName} (${sub.subjectCode})" : "Course"}';
    } else if (_targetView == 'room') {
      final r = roomMap[_selectedRoomId];
      return 'Room: ${r?.roomNumber ?? "Room"} (${r?.roomType ?? ""})';
    } else {
      return 'Master Timetable Schedule';
    }
  }

  String _generateCsvString(
    List<TimetableEntry> entries,
    Map<String, Staff> staffMap,
    Map<String, Section> sectionMap,
    Map<String, Room> roomMap,
    Map<String, Subject> subjectMap,
    Map<String, TimeSlot> slotMap, {
    String? targetView,
    Staff? selectedTeacher,
    Subject? selectedSubject,
    ProfessorWorkloadSummary? workloadSummary,
  }) {
    final buffer = StringBuffer();
    if (targetView == 'teacher' && selectedTeacher != null) {
      buffer.writeln('# Professor: ${selectedTeacher.name}');
      if (workloadSummary != null) {
        buffer.writeln('# Required Workload: ${workloadSummary.requiredWorkload} hrs');
        buffer.writeln(
          '# Scheduled Workload: ${workloadSummary.scheduledTotal} hrs (Theory: ${workloadSummary.scheduledTheory} hrs, Lab: ${workloadSummary.scheduledLab} hrs)',
        );
        buffer.writeln('# Remaining Workload: ${workloadSummary.remaining} hrs');
      }
      buffer.writeln('#');
    } else if (targetView == 'course' && selectedSubject != null) {
      buffer.writeln('# Course: ${selectedSubject.subjectName} (${selectedSubject.subjectCode})');
      buffer.writeln('# Type: ${selectedSubject.subjectType} | Required Hours/Week: ${selectedSubject.hoursPerWeek}');
      buffer.writeln('# Total Scheduled Sessions: ${entries.length}');
      buffer.writeln('#');
    }
    buffer.writeln(
      'Day,Period,Time,Section,Batch,Subject Code,Subject Name,Type,Professor,Room',
    );

    for (final e in entries) {
      final slot = slotMap[e.timeSlotId];
      final timeStr = slot != null ? '${slot.startTime} - ${slot.endTime}' : '';
      final sec = sectionMap[e.sectionId]?.sectionName ?? e.sectionId;
      final batchStr = e.batch ?? '';
      final sub = subjectMap[e.subjectId];
      final teacher = staffMap[e.teacherId]?.name ?? e.teacherId;
      final room = roomMap[e.roomId]?.roomNumber ?? e.roomId;

      buffer.writeln(
        '"${e.dayOfWeek}",${e.periodNumber},"$timeStr","$sec","$batchStr","${sub?.subjectCode ?? ""}","${sub?.subjectName ?? ""}","${sub?.subjectType ?? ""}","$teacher","$room"',
      );
    }
    return buffer.toString();
  }

  String _generateJsonString(
    List<TimetableEntry> entries,
    College? college,
    TimetableVersion? version,
    Map<String, Staff> staffMap,
    Map<String, Section> sectionMap,
    Map<String, Room> roomMap,
    Map<String, Subject> subjectMap,
  ) {
    final data = {
      'college': {
        'id': college?.id ?? '',
        'name': college?.name ?? '',
        'workingDays': college?.workingDays ?? [],
      },
      'version': {
        'id': version?.id ?? '',
        'name': version?.name ?? '',
        'status': version?.status ?? '',
      },
      'entriesCount': entries.length,
      'entries': entries.map((e) {
        final sub = subjectMap[e.subjectId];
        return {
          'id': e.id,
          'dayOfWeek': e.dayOfWeek,
          'periodNumber': e.periodNumber,
          'batch': e.batch,
          'section': sectionMap[e.sectionId]?.displayName ?? e.sectionId,
          'subject': {
            'code': sub?.subjectCode,
            'name': sub?.subjectName,
            'type': sub?.subjectType,
          },
          'teacher': staffMap[e.teacherId]?.name ?? e.teacherId,
          'room': roomMap[e.roomId]?.roomNumber ?? e.roomId,
        };
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
