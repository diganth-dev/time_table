import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/workflow_progress_bar.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class PeriodSettingsScreen extends ConsumerWidget {
  const PeriodSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final college = ref.watch(currentCollegeProvider).value;
    final activeDaysAsync = ref.watch(workingDaysProvider);
    final activeDays = activeDaysAsync.value ?? college?.workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    const allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final inactiveDays = allDays.where((d) => !activeDays.contains(d)).toList();
    final timeSlotsAsync = ref.watch(timeSlotsProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkflowProgressBar(currentStep: WorkflowStep.schedule),
            const SizedBox(height: 20),

            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 750;
                final titleWidget = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Period Slots & Break Timing Configuration',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Set daily academic period schedule, morning recess, and lunch break',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                );

                final actionsWidget = Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _resetToStandardSchedule(context, ref),
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Standard Schedule (6 Periods + Breaks)'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showSlotDialog(context, ref, null),
                      icon: const Icon(Icons.add_alarm, size: 18),
                      label: const Text('Add Slot / Break'),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 12),
                      actionsWidget,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    actionsWidget,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Working Days Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Configured Working Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    const SizedBox(height: 6),
                    const Text(
                      'Timetable generation distributes classes across active days. Click active days to deactivate, or inactive days to activate.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),

                    // ACTIVE DAYS SECTION
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Text(
                          'ACTIVE (${activeDays.length}):',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D), letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (activeDays.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          'No active working days selected. Timetable cannot be scheduled.',
                          style: TextStyle(fontSize: 13, color: Color(0xFFDC2626), fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: activeDays.map((day) {
                          return FilterChip(
                            avatar: const Icon(Icons.check, size: 16, color: Colors.white),
                            label: Text(day, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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

                    const SizedBox(height: 16),

                    // INACTIVE DAYS SECTION
                    Row(
                      children: [
                        const Icon(Icons.pause_circle_outline, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'INACTIVE (${inactiveDays.length}):',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (inactiveDays.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          'All days are currently active.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: inactiveDays.map((day) {
                          return ActionChip(
                            avatar: const Icon(Icons.add, size: 16, color: Color(0xFF475569)),
                            label: Text(day, style: const TextStyle(color: Color(0xFF475569))),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Time Slots Table
            timeSlotsAsync.when(
              data: (slots) {
                if (slots.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: Text('No time slots configured.')),
                    ),
                  );
                }

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: DataTable(
                    columnSpacing: 24,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('Order', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Slot Label', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Time Interval', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Scheduling Restriction', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: slots.map((slot) {
                      return DataRow(
                        color: slot.isBreak ? WidgetStateProperty.all(const Color(0xFFF1F5F9)) : null,
                        cells: [
                          DataCell(Text('${slot.order}')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: slot.isBreak ? Colors.brown.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: slot.isBreak ? Colors.brown.shade200 : Colors.blue.shade200),
                              ),
                              child: Text(
                                slot.isBreak ? 'Break / Recess' : 'Academic Class',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: slot.isBreak ? Colors.brown.shade800 : Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(slot.label, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(slot.timeRange)),
                          DataCell(Text(
                            slot.isBreak ? 'Blocked (No classes permitted)' : 'Schedulable for Lectures & Labs',
                            style: TextStyle(
                              fontSize: 12,
                              color: slot.isBreak ? AppTheme.errorColor : const Color(0xFF166534),
                              fontWeight: FontWeight.w600,
                            ),
                          )),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showSlotDialog(context, ref, slot),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () async {
                                    await ref.read(timeSlotControllerProvider.notifier).deleteSlot(slot.id);
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
              error: (e, _) => Text('Error loading slots: $e'),
            ),

            // Step Navigation Controls
            WorkflowBottomBar(
              nextLabel: 'Continue to Professors →',
              onNext: () async {
                final workingDays = ref.read(workingDaysProvider).value ?? college?.workingDays ?? [];
                if (workingDays.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select at least one active working day.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final slots = ref.read(timeSlotsProvider).value ?? [];
                final academicSlots = slots.where((s) => !s.isBreak).toList();
                if (academicSlots.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please configure at least one academic period slot before proceeding.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final breaks = slots.where((s) => s.isBreak).toList();
                  await ref.read(databaseRepositoryProvider).saveCollegeScheduleSettings(
                    workingDays: workingDays,
                    periodsPerDay: academicSlots.length,
                    periods: academicSlots.map((s) => {
                      'id': s.id,
                      'periodNumber': s.periodNumber,
                      'startTime': s.startTime,
                      'endTime': s.endTime,
                      'label': s.label,
                      'order': s.order,
                    }).toList(),
                    breaks: breaks.map((b) => {
                      'id': b.id,
                      'name': b.breakTitle ?? 'Break',
                      'startTime': b.startTime,
                      'endTime': b.endTime,
                      'order': b.order,
                    }).toList(),
                  );
                  if (context.mounted) {
                    context.go('/professors');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save schedule to Firestore: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSlotDialog(BuildContext context, WidgetRef ref, TimeSlot? existing) {
    final startCtrl = TextEditingController(text: existing?.startTime ?? '09:00');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '10:00');
    final periodCtrl = TextEditingController(text: '${existing?.periodNumber ?? 1}');
    final titleCtrl = TextEditingController(text: existing?.breakTitle ?? 'Lunch Break');
    final orderCtrl = TextEditingController(text: '${existing?.order ?? 1}');
    bool isBreak = existing?.isBreak ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Period / Break' : 'Edit Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Is this a Break / Lunch?'),
                value: isBreak,
                onChanged: (val) => setDialogState(() => isBreak = val),
              ),
              const SizedBox(height: 12),
              if (isBreak)
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Break Title (e.g. Morning Break, Lunch)'))
              else
                TextField(controller: periodCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Period Number (1, 2, 3...)')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start Time (HH:mm)'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End Time (HH:mm)'))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: orderCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Display Order in Schedule Grid')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            if (existing == null)
              OutlinedButton(
                onPressed: () async {
                  final collegeId = ref.read(activeCollegeIdProvider);
                  final pNum = isBreak ? 0 : (int.tryParse(periodCtrl.text) ?? 1);
                  final ord = int.tryParse(orderCtrl.text) ?? 1;

                  final newSlot = TimeSlot(
                    id: 'ts_${const Uuid().v4().substring(0, 8)}',
                    collegeId: collegeId,
                    periodNumber: pNum,
                    startTime: startCtrl.text.trim(),
                    endTime: endCtrl.text.trim(),
                    isBreak: isBreak,
                    breakTitle: isBreak ? titleCtrl.text.trim() : null,
                    order: ord,
                  );
                  try {
                    await ref.read(timeSlotControllerProvider.notifier).addSlot(newSlot);
                    setDialogState(() {
                      if (!isBreak) {
                        periodCtrl.text = '${pNum + 1}';
                      }
                      orderCtrl.text = '${ord + 1}';
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Slot added! Enter another slot or click Save & Close.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add slot: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Add Another'),
              ),
            ElevatedButton(
              onPressed: () async {
                final collegeId = ref.read(activeCollegeIdProvider);
                final pNum = isBreak ? 0 : (int.tryParse(periodCtrl.text) ?? 1);
                final ord = int.tryParse(orderCtrl.text) ?? 1;

                try {
                  if (existing == null) {
                    final newSlot = TimeSlot(
                      id: 'ts_${const Uuid().v4().substring(0, 8)}',
                      collegeId: collegeId,
                      periodNumber: pNum,
                      startTime: startCtrl.text.trim(),
                      endTime: endCtrl.text.trim(),
                      isBreak: isBreak,
                      breakTitle: isBreak ? titleCtrl.text.trim() : null,
                      order: ord,
                    );
                    await ref.read(timeSlotControllerProvider.notifier).addSlot(newSlot);
                  } else {
                    final updated = existing.copyWith(
                      periodNumber: pNum,
                      startTime: startCtrl.text.trim(),
                      endTime: endCtrl.text.trim(),
                      isBreak: isBreak,
                      breakTitle: isBreak ? titleCtrl.text.trim() : null,
                      order: ord,
                    );
                    await ref.read(timeSlotControllerProvider.notifier).updateSlot(updated);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save slot: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(existing == null ? 'Save & Close' : 'Save Slot'),
            ),
          ],
        ),
      ),
    );
  }

  void _resetToStandardSchedule(BuildContext context, WidgetRef ref) async {
    final collegeId = ref.read(activeCollegeIdProvider);
    final slots = [
      TimeSlot(id: 'ts_1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
      TimeSlot(id: 'ts_2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
      TimeSlot(id: 'ts_b1', collegeId: collegeId, periodNumber: 0, startTime: '11:00', endTime: '11:15', isBreak: true, breakTitle: 'Morning Break', order: 3),
      TimeSlot(id: 'ts_3', collegeId: collegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 4),
      TimeSlot(id: 'ts_4', collegeId: collegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 5),
      TimeSlot(id: 'ts_lunch', collegeId: collegeId, periodNumber: 0, startTime: '13:15', endTime: '14:00', isBreak: true, breakTitle: 'Lunch Break', order: 6),
      TimeSlot(id: 'ts_5', collegeId: collegeId, periodNumber: 5, startTime: '14:00', endTime: '15:00', order: 7),
      TimeSlot(id: 'ts_6', collegeId: collegeId, periodNumber: 6, startTime: '15:00', endTime: '16:00', order: 8),
    ];
    await ref.read(timeSlotControllerProvider.notifier).saveSlots(slots);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Standard schedule configured with 6 periods, Morning Break and Lunch!')),
      );
    }
  }
}
