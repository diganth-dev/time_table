import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../services/conflict_validator.dart';
import '../../../services/timetable_generator.dart';

class TimetableEditorDialog extends ConsumerStatefulWidget {
  final TimetableEntry? entry;
  final String? initialDay;
  final int? initialPeriod;
  final String? initialSectionId;
  final String? versionId;

  const TimetableEditorDialog({
    super.key,
    this.entry,
    this.initialDay,
    this.initialPeriod,
    this.initialSectionId,
    this.versionId,
  });

  @override
  ConsumerState<TimetableEditorDialog> createState() => _TimetableEditorDialogState();
}

class _TimetableEditorDialogState extends ConsumerState<TimetableEditorDialog> {
  static const _uuid = Uuid();

  late bool _isEdit;
  String _selectedClassType = 'class'; // 'class' or 'activity'
  final _activityNameCtrl = TextEditingController();
  final _activityDescCtrl = TextEditingController();
  late String _selectedDay;
  late int _selectedPeriod;
  String? _selectedSectionId;
  String? _selectedSubjectId;
  String? _selectedBatch;
  String? _selectedTeacherId;
  String? _selectedRoomId;

  List<TimetableEntry> _companionEntries = [];
  ValidationResult? _validationResult;
  bool _isValidating = false;
  bool _isSaving = false;
  String? _saveErrorMessage;

  @override
  void dispose() {
    _activityNameCtrl.dispose();
    _activityDescCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _isEdit = widget.entry != null;
    if (_isEdit) {
      final e = widget.entry!;
      _selectedClassType = e.isActivity ? 'activity' : 'class';
      _activityNameCtrl.text = e.activityName ?? '';
      _activityDescCtrl.text = e.description ?? '';
      _selectedDay = e.dayOfWeek;
      _selectedPeriod = e.periodNumber;
      _selectedSectionId = e.sectionId;
      _selectedSubjectId = e.isActivity ? null : e.subjectId;
      _selectedBatch = e.batch;
      _selectedTeacherId = e.isActivity ? null : e.teacherId;
      _selectedRoomId = e.roomId.isNotEmpty ? e.roomId : null;
    } else {
      _selectedClassType = 'class';
      _selectedDay = widget.initialDay ?? 'Monday';
      _selectedPeriod = widget.initialPeriod ?? 1;
      _selectedSectionId = widget.initialSectionId;
      _selectedSubjectId = null;
      _selectedBatch = null;
      _selectedTeacherId = null;
      _selectedRoomId = null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStateAndValidate();
    });
  }

  List<Subject> _getSubjectsForSection(Section? section, List<Subject> allSubjects) {
    if (section == null) return [];
    return allSubjects.where((sub) {
      if (!sub.active) return false;
      if (sub.sectionId != null && sub.sectionId!.isNotEmpty) {
        return sub.sectionId == section.id;
      }
      final deptMatch = sub.departmentId.isEmpty || sub.departmentId == section.departmentId;
      final semMatch = sub.semester == section.semester;
      return deptMatch && semMatch;
    }).toList();
  }

  List<Staff> _getEligibleStaff(Subject? subject, List<Staff> allStaff) {
    if (subject == null) return allStaff.where((s) => s.active).toList();
    final eligible = allStaff.where((s) {
      if (!s.active) return false;
      return s.isEligibleForSubject(
        subjectName: subject.subjectName,
        subjectCode: subject.subjectCode,
        courseShortName: subject.courseShortName,
        subjectId: subject.id,
      );
    }).toList();

    for (final tId in subject.assignedTeacherIds) {
      final teacher = allStaff.firstWhereOrNull((s) => s.id == tId && s.active);
      if (teacher != null && !eligible.any((s) => s.id == teacher.id)) {
        eligible.add(teacher);
      }
    }
    return eligible.isNotEmpty ? eligible : allStaff.where((s) => s.active).toList();
  }

  List<Room> _getCompatibleRooms(Subject? subject, Section? section, String? batch, List<Room> allRooms) {
    if (subject == null) return allRooms.where((r) => r.active && !r.isUnderMaintenance).toList();
    final int reqCapacity;
    if (batch != null && section != null && section.batches.isNotEmpty) {
      reqCapacity = (section.studentCount / section.batches.length).ceil();
    } else if (section != null) {
      reqCapacity = section.studentCount;
    } else {
      reqCapacity = 1;
    }

    return allRooms.where((r) {
      if (!TimetableGenerator.isRoomEligibleForSubject(room: r, subject: subject, section: section)) {
        return false;
      }
      if (r.capacity < reqCapacity) return false;
      return true;
    }).toList();
  }

  int _getRequiredDuration(Subject? subject) {
    if (subject == null) return 1;
    if (subject.isLab) {
      return subject.consecutivePeriods >= 2 ? subject.consecutivePeriods : 2;
    }
    return 1;
  }

  List<int>? _getConsecutivePeriods({
    required int startPeriod,
    required int duration,
    required List<TimeSlot> allSlots,
  }) {
    if (duration <= 1) return [startPeriod];

    final sortedSlots = List<TimeSlot>.from(allSlots)..sort((a, b) => a.order.compareTo(b.order));
    final startIdx = sortedSlots.indexWhere((s) => !s.isBreak && s.periodNumber == startPeriod);
    if (startIdx == -1) return null;

    final periods = <int>[];
    for (var offset = 0; offset < duration; offset++) {
      final currentIdx = startIdx + offset;
      if (currentIdx >= sortedSlots.length) return null;
      final slot = sortedSlots[currentIdx];
      if (slot.isBreak) return null;
      periods.add(slot.periodNumber);
    }
    return periods;
  }

  String _resolveCollegeId() {
    final activeCollegeId = ref.read(activeCollegeIdProvider);
    if (activeCollegeId.trim().isNotEmpty) {
      return activeCollegeId.trim();
    }
    if (widget.entry != null && widget.entry!.collegeId.trim().isNotEmpty) {
      return widget.entry!.collegeId.trim();
    }
    final user = ref.read(currentProfileProvider);
    if (user?.collegeId != null && user!.collegeId!.trim().isNotEmpty) {
      return user.collegeId!.trim();
    }
    return 'user_college';
  }

  Future<String> _resolveTargetVersionId(String collegeId) async {
    if (widget.entry != null && widget.entry!.versionId.trim().isNotEmpty) {
      return widget.entry!.versionId.trim();
    }
    if (widget.versionId != null && widget.versionId!.trim().isNotEmpty) {
      return widget.versionId!.trim();
    }
    final selectedVer = ref.read(selectedVersionIdProvider);
    if (selectedVer != null && selectedVer.trim().isNotEmpty) {
      return selectedVer.trim();
    }
    final db = ref.read(databaseRepositoryProvider);
    final user = ref.read(currentProfileProvider);
    final versions = await db.getTimetableVersions(collegeId);
    if (user?.role == UserRole.student || user?.role == UserRole.teacher) {
      final activePub = await db.getActivePublishedVersion(collegeId);
      if (activePub != null && activePub.id.isNotEmpty) return activePub.id;
    } else {
      final draft = versions.firstWhereOrNull((v) => v.status == 'draft');
      if (draft != null && draft.id.isNotEmpty) return draft.id;
    }
    if (versions.isNotEmpty && versions.first.id.isNotEmpty) {
      return versions.first.id;
    }
    final college = ref.read(currentCollegeProvider).value;
    final newVerId = 'ver_${DateTime.now().millisecondsSinceEpoch}';
    final newVersion = TimetableVersion(
      id: newVerId,
      collegeId: collegeId,
      versionNumber: 1,
      name: 'Draft Version 1',
      academicYear: college?.academicYear ?? '2026-2027',
      semester: college?.currentSemester ?? 'Odd 2026',
      status: 'draft',
    );
    await db.createTimetableVersion(newVersion);
    ref.invalidate(timetableVersionsProvider);
    return newVerId;
  }

  Future<void> _initializeStateAndValidate() async {
    final collegeId = _resolveCollegeId();
    final db = ref.read(databaseRepositoryProvider);

    final sections = await db.getSections(collegeId);
    final allSubjects = await db.getSubjects(collegeId);
    final allStaff = await db.getStaffList(collegeId);
    final allRooms = await db.getRooms(collegeId);

    if (!mounted) return;

    if (_selectedSectionId == null || !sections.any((s) => s.id == _selectedSectionId)) {
      _selectedSectionId = sections.isNotEmpty ? sections.first.id : null;
    }

    final currentSec = sections.firstWhereOrNull((s) => s.id == _selectedSectionId);
    final subjectsForSec = _getSubjectsForSection(currentSec, allSubjects);

    if (_selectedClassType == 'class') {
      if (_selectedSubjectId == null || !subjectsForSec.any((s) => s.id == _selectedSubjectId)) {
        _selectedSubjectId = subjectsForSec.isNotEmpty ? subjectsForSec.first.id : null;
      }

      final currentSubj = subjectsForSec.firstWhereOrNull((s) => s.id == _selectedSubjectId);
      final isBatchApplicable = currentSubj?.isLab == true && currentSec != null && currentSec.batches.isNotEmpty;

      if (isBatchApplicable) {
        if (_selectedBatch == null || !currentSec.batches.contains(_selectedBatch)) {
          _selectedBatch = currentSec.batches.first;
        }
      } else {
        _selectedBatch = null;
      }

      final eligibleTeachers = _getEligibleStaff(currentSubj, allStaff);
      if (_selectedTeacherId == null || !eligibleTeachers.any((s) => s.id == _selectedTeacherId)) {
        _selectedTeacherId = eligibleTeachers.isNotEmpty ? eligibleTeachers.first.id : null;
      }

      final compatibleRooms = _getCompatibleRooms(currentSubj, currentSec, _selectedBatch, allRooms);
      if (_selectedRoomId == null || !compatibleRooms.any((r) => r.id == _selectedRoomId)) {
        _selectedRoomId = compatibleRooms.isNotEmpty ? compatibleRooms.first.id : null;
      }

      if (_isEdit && widget.entry != null) {
        final targetVersionId = await _resolveTargetVersionId(collegeId);
        final existingEntries = await db.getTimetableEntries(collegeId, versionId: targetVersionId);
        final e = widget.entry!;
        final duration = _getRequiredDuration(currentSubj);

        if (duration > 1) {
          _companionEntries = existingEntries.where((other) {
            if (other.id == e.id) return false;
            if (other.sectionId != e.sectionId) return false;
            if (other.subjectId != e.subjectId) return false;
            if (other.batch != e.batch) return false;
            if (other.dayOfWeek != e.dayOfWeek) return false;
            return (other.periodNumber - e.periodNumber).abs() < duration;
          }).toList();
        }
      }
    }

    if (mounted) {
      setState(() {});
      _runValidation();
    }
  }

  void _onClassTypeChanged(String newType) {
    if (newType == _selectedClassType) return;
    setState(() {
      _selectedClassType = newType;
      _saveErrorMessage = null;
      if (newType == 'activity') {
        _selectedSubjectId = null;
        _selectedTeacherId = null;
        _selectedBatch = null;
      } else {
        final allSubjects = ref.read(subjectListProvider).value ?? [];
        final sections = ref.read(sectionListProvider).value ?? [];
        final allStaff = ref.read(staffListProvider).value ?? [];
        final allRooms = ref.read(roomListProvider).value ?? [];
        final sec = sections.firstWhereOrNull((s) => s.id == _selectedSectionId);
        final subjs = _getSubjectsForSection(sec, allSubjects);
        final firstSubj = subjs.isNotEmpty ? subjs.first : null;
        _selectedSubjectId = firstSubj?.id;
        final isBatch = firstSubj?.isLab == true && sec != null && sec.batches.isNotEmpty;
        _selectedBatch = isBatch ? sec.batches.first : null;
        final eligibleTeachers = _getEligibleStaff(firstSubj, allStaff);
        _selectedTeacherId = eligibleTeachers.isNotEmpty ? eligibleTeachers.first.id : null;
        final compatibleRooms = _getCompatibleRooms(firstSubj, sec, _selectedBatch, allRooms);
        if (_selectedRoomId == null || !compatibleRooms.any((r) => r.id == _selectedRoomId)) {
          _selectedRoomId = compatibleRooms.isNotEmpty ? compatibleRooms.first.id : null;
        }
      }
    });
    _runValidation();
  }

  void _onSectionChanged(String? newSectionId) {
    if (newSectionId == null || newSectionId == _selectedSectionId) return;

    final allSubjects = ref.read(subjectListProvider).value ?? [];
    final sections = ref.read(sectionListProvider).value ?? [];
    final allStaff = ref.read(staffListProvider).value ?? [];
    final allRooms = ref.read(roomListProvider).value ?? [];

    final sec = sections.firstWhereOrNull((s) => s.id == newSectionId);
    final subjs = _getSubjectsForSection(sec, allSubjects);
    final firstSubj = subjs.isNotEmpty ? subjs.first : null;

    final isBatch = firstSubj?.isLab == true && sec != null && sec.batches.isNotEmpty;
    final newBatch = isBatch ? sec.batches.first : null;

    final eligibleTeachers = _getEligibleStaff(firstSubj, allStaff);
    final compatibleRooms = _getCompatibleRooms(firstSubj, sec, newBatch, allRooms);

    setState(() {
      _selectedSectionId = newSectionId;
      _selectedSubjectId = firstSubj?.id;
      _selectedBatch = newBatch;
      _selectedTeacherId = eligibleTeachers.isNotEmpty ? eligibleTeachers.first.id : null;
      _selectedRoomId = compatibleRooms.isNotEmpty ? compatibleRooms.first.id : null;
      _saveErrorMessage = null;
    });

    _runValidation();
  }

  void _onSubjectChanged(String? newSubjectId) {
    if (newSubjectId == null || newSubjectId == _selectedSubjectId) return;

    final allSubjects = ref.read(subjectListProvider).value ?? [];
    final sections = ref.read(sectionListProvider).value ?? [];
    final allStaff = ref.read(staffListProvider).value ?? [];
    final allRooms = ref.read(roomListProvider).value ?? [];

    final sec = sections.firstWhereOrNull((s) => s.id == _selectedSectionId);
    final subj = allSubjects.firstWhereOrNull((s) => s.id == newSubjectId);

    final isBatch = subj?.isLab == true && sec != null && sec.batches.isNotEmpty;
    final newBatch = isBatch ? (sec.batches.contains(_selectedBatch) ? _selectedBatch : sec.batches.first) : null;

    final eligibleTeachers = _getEligibleStaff(subj, allStaff);
    final compatibleRooms = _getCompatibleRooms(subj, sec, newBatch, allRooms);

    setState(() {
      _selectedSubjectId = newSubjectId;
      _selectedBatch = newBatch;
      if (!eligibleTeachers.any((s) => s.id == _selectedTeacherId)) {
        _selectedTeacherId = eligibleTeachers.isNotEmpty ? eligibleTeachers.first.id : null;
      }
      if (!compatibleRooms.any((r) => r.id == _selectedRoomId)) {
        _selectedRoomId = compatibleRooms.isNotEmpty ? compatibleRooms.first.id : null;
      }
      _saveErrorMessage = null;
    });

    _runValidation();
  }

  Future<void> _runValidation() async {
    if (_selectedSectionId == null) {
      setState(() {
        _validationResult = null;
        _isValidating = false;
      });
      return;
    }

    if (_selectedClassType == 'activity') {
      if (_activityNameCtrl.text.trim().isEmpty) {
        setState(() {
          _validationResult = null;
          _isValidating = false;
        });
        return;
      }
    } else {
      if (_selectedSubjectId == null ||
          _selectedTeacherId == null ||
          _selectedRoomId == null) {
        setState(() {
          _validationResult = null;
          _isValidating = false;
        });
        return;
      }
    }

    setState(() => _isValidating = true);

    final db = ref.read(databaseRepositoryProvider);
    final collegeId = _resolveCollegeId();
    final college = ref.read(currentCollegeProvider).value;
    final workingDays = college?.workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    final sections = await db.getSections(collegeId);
    final subjects = await db.getSubjects(collegeId);
    final staffList = await db.getStaffList(collegeId);
    final rooms = await db.getRooms(collegeId);
    final timeSlots = await db.getTimeSlots(collegeId);
    final availabilities = await db.getTeacherAvailability(collegeId);

    final targetVersionId = await _resolveTargetVersionId(collegeId);

    final existingEntries = await db.getTimetableEntries(collegeId, versionId: targetVersionId);

    final proposedEntries = <TimetableEntry>[];

    if (_selectedClassType == 'activity') {
      final matchingSlot = timeSlots.firstWhereOrNull((s) => s.periodNumber == _selectedPeriod);
      final entryId = (_isEdit && widget.entry != null) ? widget.entry!.id : _uuid.v4();
      proposedEntries.add(
        TimetableEntry(
          id: entryId,
          collegeId: collegeId,
          versionId: targetVersionId,
          dayOfWeek: _selectedDay,
          periodNumber: _selectedPeriod,
          timeSlotId: matchingSlot?.id,
          sectionId: _selectedSectionId!,
          subjectId: '',
          teacherId: '',
          roomId: _selectedRoomId ?? '',
          entryType: 'activity',
          activityName: _activityNameCtrl.text.trim(),
          description: _activityDescCtrl.text.trim().isNotEmpty
              ? _activityDescCtrl.text.trim()
              : null,
          status: 'draft',
        ),
      );
    } else {
      final selectedSubj = subjects.firstWhereOrNull((s) => s.id == _selectedSubjectId);
      final selectedSec = sections.firstWhereOrNull((s) => s.id == _selectedSectionId);
      final isBatchApplicable = selectedSubj?.isLab == true && selectedSec != null && selectedSec.batches.isNotEmpty;
      final duration = _getRequiredDuration(selectedSubj);

      final consecutivePeriods = _getConsecutivePeriods(
        startPeriod: _selectedPeriod,
        duration: duration,
        allSlots: timeSlots,
      );

      if (consecutivePeriods == null) {
        final breakConflict = ConflictItem(
          id: 'lab_break_duration_conflict',
          collegeId: collegeId,
          type: 'labDurationConflict',
          severity: 'hard',
          title: 'Invalid Consecutive Period Block',
          description: '${selectedSubj?.subjectName ?? "Lab"} requires $duration consecutive periods. Starting at Period $_selectedPeriod crosses a break/lunch or exceeds available academic periods on $_selectedDay.',
          suggestion: 'Select a starting period with $duration consecutive academic periods that do not cross breaks.',
          dayOfWeek: _selectedDay,
          periodNumber: _selectedPeriod,
        );
        if (mounted) {
          setState(() {
            _validationResult = ValidationResult(
              hardConflicts: [breakConflict],
              warnings: const [],
            );
            _isValidating = false;
          });
        }
        return;
      }

      for (var i = 0; i < consecutivePeriods.length; i++) {
        final p = consecutivePeriods[i];
        final matchingSlot = timeSlots.firstWhereOrNull((s) => s.periodNumber == p);

        String entryId;
        if (_isEdit && widget.entry != null) {
          if (i == 0) {
            entryId = widget.entry!.id;
          } else if (_companionEntries.isNotEmpty && i - 1 < _companionEntries.length) {
            entryId = _companionEntries[i - 1].id;
          } else {
            entryId = _uuid.v4();
          }
        } else {
          entryId = _uuid.v4();
        }

        proposedEntries.add(
          TimetableEntry(
            id: entryId,
            collegeId: collegeId,
            versionId: targetVersionId,
            dayOfWeek: _selectedDay,
            periodNumber: p,
            timeSlotId: matchingSlot?.id,
            sectionId: _selectedSectionId!,
            subjectId: _selectedSubjectId!,
            teacherId: _selectedTeacherId!,
            roomId: _selectedRoomId!,
            batch: isBatchApplicable ? _selectedBatch : null,
            status: 'draft',
          ),
        );
      }
    }

    final result = ConflictValidator.validateProposedEntries(
      collegeId: collegeId,
      proposedEntries: proposedEntries,
      existingEntries: existingEntries,
      sections: sections,
      subjects: subjects,
      staffList: staffList,
      rooms: rooms,
      timeSlots: timeSlots,
      availabilities: availabilities,
      workingDays: workingDays,
    );

    if (mounted) {
      setState(() {
        _validationResult = result;
        _isValidating = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _saveErrorMessage = null);

    if (_selectedClassType == 'activity') {
      if (_activityNameCtrl.text.trim().isEmpty) {
        setState(() => _saveErrorMessage = 'Please enter an activity name.');
        return;
      }
    }

    if (_validationResult == null || !_validationResult!.isValid) {
      setState(() {
        final conflictReason = _validationResult?.hardConflicts.isNotEmpty == true
            ? _validationResult!.hardConflicts.first.description
            : 'Unresolved conflicts detected with the proposed assignment.';
        _saveErrorMessage = 'Cannot save: $conflictReason\nPlease resolve all conflicts before saving.';
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseRepositoryProvider);
      final collegeId = _resolveCollegeId();
      final timeSlots = await db.getTimeSlots(collegeId);
      final subjects = await db.getSubjects(collegeId);
      final sections = await db.getSections(collegeId);

      final targetVersionId = await _resolveTargetVersionId(collegeId);

      debugPrint('EDIT SAVE:\n'
          'day = $_selectedDay\n'
          'period = $_selectedPeriod\n'
          'sectionId = $_selectedSectionId\n'
          'subjectId = $_selectedSubjectId\n'
          'teacherId = $_selectedTeacherId\n'
          'roomId = $_selectedRoomId\n'
          'versionId = $targetVersionId\n'
          'collegeId = $collegeId');

      final proposedEntries = <TimetableEntry>[];
      final entriesToDelete = <String>[];

      if (_selectedClassType == 'activity') {
        final matchingSlot = timeSlots.firstWhereOrNull((s) => s.periodNumber == _selectedPeriod);
        final entryId = (_isEdit && widget.entry != null) ? widget.entry!.id : _uuid.v4();
        proposedEntries.add(
          TimetableEntry(
            id: entryId,
            collegeId: collegeId,
            versionId: targetVersionId,
            dayOfWeek: _selectedDay,
            periodNumber: _selectedPeriod,
            timeSlotId: matchingSlot?.id,
            sectionId: _selectedSectionId!,
            subjectId: '',
            teacherId: '',
            roomId: _selectedRoomId ?? '',
            entryType: 'activity',
            activityName: _activityNameCtrl.text.trim(),
            description: _activityDescCtrl.text.trim().isNotEmpty
                ? _activityDescCtrl.text.trim()
                : null,
            status: 'draft',
          ),
        );
        if (_isEdit && _companionEntries.isNotEmpty) {
          entriesToDelete.addAll(_companionEntries.map((e) => e.id));
        }
      } else {
        final selectedSubj = subjects.firstWhereOrNull((s) => s.id == _selectedSubjectId);
        final selectedSec = sections.firstWhereOrNull((s) => s.id == _selectedSectionId);
        final isBatchApplicable = selectedSubj?.isLab == true && selectedSec != null && selectedSec.batches.isNotEmpty;
        final duration = _getRequiredDuration(selectedSubj);

        final consecutivePeriods = _getConsecutivePeriods(
          startPeriod: _selectedPeriod,
          duration: duration,
          allSlots: timeSlots,
        );

        if (consecutivePeriods == null) {
          setState(() {
            _saveErrorMessage = 'Cannot save: Period block crosses break or exceeds academic schedule.';
            _isSaving = false;
          });
          return;
        }

        for (var i = 0; i < consecutivePeriods.length; i++) {
          final p = consecutivePeriods[i];
          final matchingSlot = timeSlots.firstWhereOrNull((s) => s.periodNumber == p);

          String entryId;
          if (_isEdit && widget.entry != null) {
            if (i == 0) {
              entryId = widget.entry!.id;
            } else if (_companionEntries.isNotEmpty && i - 1 < _companionEntries.length) {
              entryId = _companionEntries[i - 1].id;
            } else {
              entryId = _uuid.v4();
            }
          } else {
            entryId = _uuid.v4();
          }

          proposedEntries.add(
            TimetableEntry(
              id: entryId,
              collegeId: collegeId,
              versionId: targetVersionId,
              dayOfWeek: _selectedDay,
              periodNumber: p,
              timeSlotId: matchingSlot?.id,
              sectionId: _selectedSectionId!,
              subjectId: _selectedSubjectId!,
              teacherId: _selectedTeacherId!,
              roomId: _selectedRoomId!,
              batch: isBatchApplicable ? _selectedBatch : null,
              status: 'draft',
            ),
          );
        }

        if (_isEdit && _companionEntries.length >= consecutivePeriods.length) {
          for (var i = consecutivePeriods.length - 1; i < _companionEntries.length; i++) {
            entriesToDelete.add(_companionEntries[i].id);
          }
        }
      }

      await ref.read(timetableControllerProvider.notifier).saveEntries(
        proposedEntries,
        entriesToDelete: entriesToDelete.isNotEmpty ? entriesToDelete : null,
      );

      ref.invalidate(timetableVersionsProvider);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveErrorMessage = 'Error saving timetable class: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffList = ref.watch(staffListProvider).value ?? [];
    final rooms = ref.watch(roomListProvider).value ?? [];
    final sections = ref.watch(sectionListProvider).value ?? [];
    final allSubjects = ref.watch(subjectListProvider).value ?? [];
    final timeSlots = ref.watch(academicSlotsProvider);
    final college = ref.watch(currentCollegeProvider).value;
    final workingDays = college?.workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    final selectedSec = sections.firstWhereOrNull((s) => s.id == _selectedSectionId);
    final subjectsForSec = _getSubjectsForSection(selectedSec, allSubjects);
    final selectedSubj = subjectsForSec.firstWhereOrNull((s) => s.id == _selectedSubjectId) ??
        allSubjects.firstWhereOrNull((s) => s.id == _selectedSubjectId);

    final isBatchApplicable = selectedSubj?.isLab == true && selectedSec != null && selectedSec.batches.isNotEmpty;
    final eligibleStaff = _getEligibleStaff(selectedSubj, staffList);
    final compatibleRooms = _getCompatibleRooms(selectedSubj, selectedSec, _selectedBatch, rooms);
    final duration = _getRequiredDuration(selectedSubj);

    final titleText = _isEdit
        ? (_selectedClassType == 'activity'
            ? 'Edit / Reassign Activity'
            : (_selectedBatch != null
                ? 'Edit / Reassign Class ($_selectedBatch)'
                : 'Edit / Reassign Class'))
        : (_selectedClassType == 'activity'
            ? 'Add Activity / Event'
            : 'Add Class');

    final selectedSlot = timeSlots.firstWhereOrNull((s) => s.periodNumber == _selectedPeriod);
    final contextSubtitle = selectedSlot != null
        ? '$_selectedDay • ${selectedSlot.label} (${selectedSlot.timeRange})'
        : '$_selectedDay • Period $_selectedPeriod';

    return AlertDialog(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(
              _selectedClassType == 'activity'
                  ? Icons.event_note
                  : (isBatchApplicable ? Icons.biotech : Icons.edit_calendar),
              color: _selectedClassType == 'activity'
                  ? const Color(0xFF7C3AED)
                  : (isBatchApplicable ? const Color(0xFF2563EB) : AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  contextSubtitle,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class Type Selector
              const Text('Class Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  ChoiceChip(
                    key: const Key('editor_type_class'),
                    label: const Text('Subject Class'),
                    selected: _selectedClassType == 'class',
                    onSelected: (selected) {
                      if (selected) _onClassTypeChanged('class');
                    },
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _selectedClassType == 'class' ? AppTheme.primaryColor : Colors.grey.shade700,
                      fontWeight: _selectedClassType == 'class' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    key: const Key('editor_type_activity'),
                    label: const Text('Activity / Event'),
                    selected: _selectedClassType == 'activity',
                    onSelected: (selected) {
                      if (selected) _onClassTypeChanged('activity');
                    },
                    selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _selectedClassType == 'activity' ? const Color(0xFF7C3AED) : Colors.grey.shade700,
                      fontWeight: _selectedClassType == 'activity' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Class Section Selector
              const Text('Class Section', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              if (_isEdit)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    selectedSec?.displayName ?? 'Section',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: const Key('editor_section_dropdown'),
                  initialValue: sections.any((s) => s.id == _selectedSectionId) ? _selectedSectionId : null,
                  isExpanded: true,
                  items: sections
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName)))
                      .toList(),
                  onChanged: _onSectionChanged,
                ),
              const SizedBox(height: 16),

              if (_selectedClassType == 'activity') ...[
                // Activity Name
                const Text('Activity Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('editor_activity_name_field'),
                  controller: _activityNameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Placement Training, Seminar, Sports, Club Activity',
                    prefixIcon: Icon(Icons.event_note, size: 20),
                  ),
                  onChanged: (_) => _runValidation(),
                ),
                const SizedBox(height: 16),

                // Description (Optional)
                const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('editor_activity_description_field'),
                  controller: _activityDescCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Optional instructions, speaker details, or room notes',
                    prefixIcon: Icon(Icons.notes, size: 20),
                  ),
                ),
                const SizedBox(height: 16),

                // Day of Week
                const Text('Day of Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: const Key('editor_day_dropdown'),
                  initialValue: workingDays.contains(_selectedDay) ? _selectedDay : null,
                  isExpanded: true,
                  items: workingDays.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDay = val;
                        _saveErrorMessage = null;
                      });
                      _runValidation();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Academic Period
                const Text('Academic Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  key: const Key('editor_period_dropdown'),
                  initialValue: timeSlots.any((s) => s.periodNumber == _selectedPeriod) ? _selectedPeriod : null,
                  isExpanded: true,
                  items: timeSlots.map((s) => DropdownMenuItem(
                    value: s.periodNumber,
                    child: Text('${s.label} (${s.timeRange})'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPeriod = val;
                        _saveErrorMessage = null;
                      });
                      _runValidation();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Venue (Optional)
                const Text('Venue (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  key: const Key('editor_activity_venue_dropdown'),
                  initialValue: rooms.any((r) => r.id == _selectedRoomId) ? _selectedRoomId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.meeting_room_outlined, size: 20),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No Venue / Off-Campus (Optional)', style: TextStyle(color: Colors.grey)),
                    ),
                    ...rooms.where((r) => r.active).map((r) => DropdownMenuItem<String?>(
                      value: r.id,
                      child: Text('${r.roomNumber} - ${r.roomType} (Cap: ${r.capacity})'),
                    )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedRoomId = val;
                      _saveErrorMessage = null;
                    });
                    _runValidation();
                  },
                ),
                const SizedBox(height: 20),
              ] else ...[
                // Subject Selector
                const Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                if (_isEdit)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedSubj?.subjectName ?? "Subject"} (${selectedSubj?.subjectCode ?? ""})',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (selectedSubj?.isLab == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Text('LAB', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                          ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: const Key('editor_subject_dropdown'),
                    initialValue: subjectsForSec.any((s) => s.id == _selectedSubjectId) ? _selectedSubjectId : null,
                    isExpanded: true,
                    items: subjectsForSec
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text('${s.subjectName} (${s.subjectCode})${s.isLab ? " [LAB]" : ""}'),
                            ))
                        .toList(),
                    onChanged: _onSubjectChanged,
                  ),
                const SizedBox(height: 16),

                // Lab Batch Selector (Requirement 6: Appears ONLY when class is batch-applicable)
                if (isBatchApplicable) ...[
                  const Text('Lab Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: const Key('editor_batch_dropdown'),
                    initialValue: selectedSec.batches.contains(_selectedBatch) ? _selectedBatch : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.badge, size: 18),
                    ),
                    items: selectedSec.batches
                        .map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedBatch = val;
                          _saveErrorMessage = null;
                        });
                        _runValidation();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Day of Week
                const Text('Day of Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: const Key('editor_day_dropdown'),
                  initialValue: workingDays.contains(_selectedDay) ? _selectedDay : null,
                  isExpanded: true,
                  items: workingDays.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDay = val;
                        _saveErrorMessage = null;
                      });
                      _runValidation();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Period Slot
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Academic Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    if (duration > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '$duration Consecutive Periods',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  key: const Key('editor_period_dropdown'),
                  initialValue: timeSlots.any((s) => s.periodNumber == _selectedPeriod) ? _selectedPeriod : null,
                  isExpanded: true,
                  items: timeSlots.map((s) => DropdownMenuItem(
                    value: s.periodNumber,
                    child: Text('${s.label} (${s.timeRange})'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPeriod = val;
                        _saveErrorMessage = null;
                      });
                      _runValidation();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Assigned Teacher (Filtered: Requirement 11)
                const Text('Assigned Teacher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: const Key('editor_teacher_dropdown'),
                  initialValue: eligibleStaff.any((s) => s.id == _selectedTeacherId) ? _selectedTeacherId : null,
                  isExpanded: true,
                  items: eligibleStaff.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.name} (${s.designation})'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedTeacherId = val;
                        _saveErrorMessage = null;
                      });
                      _runValidation();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Assigned Room (Filtered: Requirement 11)
                const Text('Classroom / Laboratory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: const Key('editor_room_dropdown'),
                  initialValue: compatibleRooms.any((r) => r.id == _selectedRoomId) ? _selectedRoomId : null,
                  isExpanded: true,
                  items: compatibleRooms.map((r) => DropdownMenuItem(
                    value: r.id,
                    child: Text('${r.roomNumber} - ${r.roomType} (Cap: ${r.capacity})'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRoomId = val;
                        _saveErrorMessage = null;
                      });
                      _runValidation();
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Save Error / Validation Feedback
              if (_saveErrorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade400),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveErrorMessage!,
                          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Live Validation Box
              if (_isValidating)
                const LinearProgressIndicator()
              else if (_validationResult != null) ...[
                if (_validationResult!.isValid)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedClassType == 'activity'
                                ? 'Valid activity placement: No section or venue conflicts detected.'
                                : (isBatchApplicable
                                    ? 'Valid lab placement: No teacher, room, batch, break, or section conflicts detected for $_selectedBatch.'
                                    : 'Valid placement: No teacher, room, or section conflicts detected.'),
                            style: const TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error, color: AppTheme.errorColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${_validationResult!.hardConflicts.length} Conflict(s) Detected:',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ..._validationResult!.hardConflicts.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text('• ${c.description}', style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
                        )),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_isEdit)
          TextButton(
            key: const Key('editor_delete_button'),
            onPressed: () async {
              final isAct = _selectedClassType == 'activity';
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(isAct ? 'Cancel / Remove Activity?' : 'Cancel / Remove Class?'),
                  content: Text(
                    isAct
                        ? 'This will remove this activity entry from the timetable.'
                        : (_companionEntries.isNotEmpty
                            ? 'This will remove all ${_companionEntries.length + 1} periods of this lab block from the timetable.'
                            : 'This will remove this class entry from the timetable.'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(isAct ? 'Remove Activity' : 'Remove Class'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final idsToDelete = [widget.entry!.id, ..._companionEntries.map((e) => e.id)];
                await ref.read(timetableControllerProvider.notifier).deleteEntries(idsToDelete);
                if (context.mounted) Navigator.pop(context, true);
              }
            },
            child: Text(
              _selectedClassType == 'activity' ? 'Delete Activity' : 'Delete Class',
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
        TextButton(
          key: const Key('editor_cancel_button'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('editor_save_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _validationResult?.isValid == false
                ? Colors.grey.shade400
                : AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _saveChanges,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Save Changes' : 'Save'),
        ),
      ],
    );
  }
}
