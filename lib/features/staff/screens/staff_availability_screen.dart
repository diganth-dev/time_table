import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class StaffAvailabilityScreen extends ConsumerStatefulWidget {
  final Staff? staff;

  const StaffAvailabilityScreen({super.key, this.staff});

  @override
  ConsumerState<StaffAvailabilityScreen> createState() => _StaffAvailabilityScreenState();
}

class _StaffAvailabilityScreenState extends ConsumerState<StaffAvailabilityScreen> {
  // Map: "$day_$period" -> bool (true = available, false = unavailable)
  final Map<String, bool> _availabilityGrid = {};
  Staff? _activeStaff;
  String? _lastStaffId;
  List<UnavailableTime>? _lastUnavailableTimes;
  List<TimeSlot>? _lastTimeSlots;
  List<String>? _lastWorkingDays;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _activeStaff = widget.staff;
  }

  bool _areUnavailableTimesEqual(List<UnavailableTime>? a, List<UnavailableTime>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].dayOfWeek.trim().toLowerCase() != b[i].dayOfWeek.trim().toLowerCase() ||
          a[i].startTime.trim() != b[i].startTime.trim() ||
          a[i].endTime.trim() != b[i].endTime.trim()) {
        return false;
      }
    }
    return true;
  }

  bool _areTimeSlotsEqual(List<TimeSlot>? a, List<TimeSlot>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].periodNumber != b[i].periodNumber ||
          a[i].startTime.trim() != b[i].startTime.trim() ||
          a[i].endTime.trim() != b[i].endTime.trim()) {
        return false;
      }
    }
    return true;
  }

  bool _areWorkingDaysEqual(List<String>? a, List<String>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].trim().toLowerCase() != b[i].trim().toLowerCase()) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentProfileProvider);
    final staffList = ref.watch(staffListProvider).value ?? [];
    final college = ref.watch(currentCollegeProvider).value;
    final workingDays = college?.workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final timeSlots = ref.watch(academicSlotsProvider);

    Staff? currentStaff;
    if (_activeStaff != null) {
      currentStaff = staffList.cast<Staff?>().firstWhere(
        (s) => s?.id == _activeStaff!.id,
        orElse: () => _activeStaff,
      );
    } else if (widget.staff != null) {
      currentStaff = staffList.cast<Staff?>().firstWhere(
        (s) => s?.id == widget.staff!.id,
        orElse: () => widget.staff,
      );
    } else if (staffList.isNotEmpty) {
      if (user?.staffId != null) {
        currentStaff = staffList.cast<Staff?>().firstWhere(
          (s) => s?.id == user?.staffId || s?.email.toLowerCase() == user?.email.toLowerCase(),
          orElse: () => staffList.first,
        );
      } else {
        currentStaff = staffList.first;
      }
    }
    _activeStaff = currentStaff;

    // Check if we need to re-initialize grid from staff.unavailableTimes & timeSlots
    final shouldReinitialize = _lastStaffId != currentStaff?.id ||
        !_areUnavailableTimesEqual(_lastUnavailableTimes, currentStaff?.unavailableTimes) ||
        !_areTimeSlotsEqual(_lastTimeSlots, timeSlots) ||
        !_areWorkingDaysEqual(_lastWorkingDays, workingDays);

    if (shouldReinitialize) {
      _lastStaffId = currentStaff?.id;
      _lastUnavailableTimes = currentStaff?.unavailableTimes != null
          ? List.unmodifiable(currentStaff!.unavailableTimes)
          : null;
      _lastTimeSlots = List.unmodifiable(timeSlots);
      _lastWorkingDays = List.unmodifiable(workingDays);

      _availabilityGrid.clear();
      if (currentStaff != null) {
        for (final day in workingDays) {
          for (final slot in timeSlots) {
            final key = '${day}_${slot.periodNumber}';
            final isUnavailable = currentStaff.isUnavailableDuring(day: day, slot: slot);
            _availabilityGrid[key] = !isUnavailable;
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_activeStaff != null ? 'Faculty Availability: ${_activeStaff!.name}' : 'Faculty Availability'),
        actions: [
          if (_activeStaff != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                key: const Key('save_availability_button'),
                onPressed: _isSaving || timeSlots.isEmpty ? null : () => _saveAvailability(timeSlots, workingDays),
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 18),
                label: const Text('Save Availability'),
              ),
            ),
        ],
      ),
      body: staffList.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off_outlined, size: 56, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 16),
                    const Text(
                      'No professors registered yet.',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add professors in the Professors screen first to configure their availability.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Switch staff dropdown if admin
            if (user?.role == UserRole.collegeAdmin)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Text('Select Staff Member: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _activeStaff?.id,
                          isExpanded: true,
                          items: staffList.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.designation})'))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _activeStaff = staffList.firstWhere((s) => s.id == val);
                                _lastStaffId = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.touch_app, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Weekly Period Availability Grid',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Click on any period slot to toggle between Available (Green) and Unavailable (Red). The generation engine will never assign classes during unavailable periods.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const Divider(height: 24),

                    if (timeSlots.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: Text(
                            'No academic time slots configured yet.\nPlease configure College Schedule first.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          columns: [
                            const DataColumn(label: Text('Period / Time Slot', style: TextStyle(fontWeight: FontWeight.bold))),
                            ...workingDays.map((d) => DataColumn(label: Text(d, style: const TextStyle(fontWeight: FontWeight.bold)))),
                          ],
                          rows: timeSlots.map((slot) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Period ${slot.periodNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(slot.timeRange, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                ...workingDays.map((day) {
                                  final key = '${day}_${slot.periodNumber}';
                                  final isAvailable = _availabilityGrid[key] ?? true;

                                  return DataCell(
                                    InkWell(
                                      key: Key('cell_${day}_${slot.periodNumber}'),
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        setState(() {
                                          _availabilityGrid[key] = !isAvailable;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isAvailable ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isAvailable ? Icons.check_circle : Icons.cancel,
                                              size: 14,
                                              color: isAvailable ? const Color(0xFF16A34A) : AppTheme.errorColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isAvailable ? 'Available' : 'Unavailable',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isAvailable ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAvailability(List<TimeSlot> slots, List<String> days) async {
    if (_activeStaff == null) return;
    final collegeId = ref.read(activeCollegeIdProvider);

    setState(() => _isSaving = true);

    try {
      final newUnavailableTimes = <UnavailableTime>[];

      // Preserve any existing unavailable times on days NOT in the current workingDays
      for (final u in _activeStaff!.unavailableTimes) {
        final dayMatches = days.any((d) => d.toLowerCase() == u.dayOfWeek.trim().toLowerCase());
        if (!dayMatches) {
          newUnavailableTimes.add(u);
        }
      }

      // Convert grid states for each working day
      for (final day in days) {
        final unavailableSlots = slots.where((slot) {
          final key = '${day}_${slot.periodNumber}';
          return _availabilityGrid[key] == false;
        }).toList();

        if (unavailableSlots.isEmpty) continue;

        // Sort slots chronologically
        unavailableSlots.sort((a, b) {
          final aStart = UnavailableTime.parseTimeToMinutes(a.startTime) ?? 0;
          final bStart = UnavailableTime.parseTimeToMinutes(b.startTime) ?? 0;
          final cmp = aStart.compareTo(bStart);
          return cmp != 0 ? cmp : a.periodNumber.compareTo(b.periodNumber);
        });

        // Group contiguous slots
        int i = 0;
        while (i < unavailableSlots.length) {
          final startSlot = unavailableSlots[i];
          final rangeStart = startSlot.startTime;
          var rangeEnd = startSlot.endTime;
          var lastSlot = startSlot;

          var j = i + 1;
          while (j < unavailableSlots.length) {
            final nextSlot = unavailableSlots[j];
            final isTimeContiguous = nextSlot.startTime.trim() == rangeEnd.trim();
            final isConsecutivePeriod = nextSlot.periodNumber == lastSlot.periodNumber + 1;

            if (isTimeContiguous || isConsecutivePeriod) {
              rangeEnd = nextSlot.endTime;
              lastSlot = nextSlot;
              j++;
            } else {
              break;
            }
          }

          newUnavailableTimes.add(UnavailableTime(
            dayOfWeek: day,
            startTime: rangeStart,
            endTime: rangeEnd,
          ));

          i = j;
        }
      }

      final updatedStaff = _activeStaff!.copyWith(
        unavailableTimes: newUnavailableTimes,
      );

      final list = <TeacherAvailability>[];
      for (final day in days) {
        for (final slot in slots) {
          final key = '${day}_${slot.periodNumber}';
          final isAvail = _availabilityGrid[key] ?? true;
          list.add(TeacherAvailability(
            id: const Uuid().v4(),
            collegeId: collegeId,
            teacherId: _activeStaff!.id,
            dayOfWeek: day,
            periodNumber: slot.periodNumber,
            isAvailable: isAvail,
          ));
        }
      }

      final db = ref.read(databaseRepositoryProvider);
      await ref.read(staffControllerProvider.notifier).updateStaff(updatedStaff);
      await db.saveBulkAvailability(list);
      ref.invalidate(teacherAvailabilityProvider(_activeStaff!.id));

      _lastUnavailableTimes = List.unmodifiable(newUnavailableTimes);
      _activeStaff = updatedStaff;

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Availability matrix saved for ${_activeStaff!.name}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save availability: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
