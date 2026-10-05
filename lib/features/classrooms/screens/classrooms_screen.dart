import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/workflow_progress_bar.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class ClassroomsScreen extends ConsumerWidget {
  const ClassroomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomListProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkflowProgressBar(currentStep: WorkflowStep.roomsAndLabs),
            const SizedBox(height: 20),

            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 750;
                final titleWidget = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Classrooms & Specialized Laboratories',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Configure physical spaces, seating capacities, lab equipment, and maintenance schedules',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                );

                final addBtn = ElevatedButton.icon(
                  onPressed: () => _showRoomDialog(context, ref, null),
                  icon: const Icon(Icons.add_location_alt, size: 18),
                  label: const Text('Add Classroom / Lab'),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 12),
                      addBtn,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    addBtn,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            roomsAsync.when(
              data: (rooms) {
                if (rooms.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: Text('No classrooms or laboratories configured yet.')),
                    ),
                  );
                }

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: DataTable(
                    columnSpacing: 24,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('Venue Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Facility Type', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Building & Floor', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Seating Capacity', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status / Maintenance', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: rooms.map((r) {
                      final isMaintenance = r.isUnderMaintenance;

                      return DataRow(
                        cells: [
                          DataCell(Text(r.roomNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Chip(
                                label: Text(r.roomType, style: const TextStyle(fontSize: 11)),
                                backgroundColor: r.roomType.contains('Lab') ? Colors.blue.shade50 : Colors.grey.shade100,
                                visualDensity: VisualDensity.compact,
                              ),
                              if (r.compatibleSubjects.isNotEmpty)
                                Text(
                                  'Compatible: ${r.compatibleSubjects.join(", ")}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          )),
                          DataCell(Text('${r.building}, Floor ${r.floor}')),
                          DataCell(Text('${r.capacity} seats', style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isMaintenance ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isMaintenance ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
                              ),
                              child: Text(
                                isMaintenance ? 'Under Maintenance' : 'Operational',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isMaintenance ? const Color(0xFF991B1B) : const Color(0xFF166534),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.build_circle,
                                    size: 20,
                                    color: isMaintenance ? AppTheme.errorColor : Colors.amber.shade700,
                                  ),
                                  tooltip: 'Maintenance & Impact Analysis',
                                  onPressed: () => _showMaintenanceDialog(context, ref, r),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showRoomDialog(context, ref, r),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Room?'),
                                        content: Text('Remove ${r.roomNumber}?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        await ref.read(roomControllerProvider.notifier).deleteRoom(r.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Room ${r.roomNumber} deleted.')),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to delete room: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
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
              error: (e, _) => Text('Error loading rooms: $e'),
            ),

            // Step Navigation Controls
            WorkflowBottomBar(
              backLabel: '← Sections & Subjects',
              onBack: () => context.go('/sections-subjects'),
              nextLabel: 'Continue to Timetable Generation →',
              onNext: () async {
                final rooms = ref.read(roomListProvider).value ?? [];
                final activeRooms = rooms.where((r) => r.active && !r.isUnderMaintenance).toList();
                if (activeRooms.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please configure at least one active classroom or laboratory before proceeding.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                context.go('/workflow');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomDialog(BuildContext context, WidgetRef ref, Room? existing) {
    final numberCtrl = TextEditingController(text: existing?.roomNumber ?? '');
    final buildingCtrl = TextEditingController(text: existing?.building ?? '');
    final floorCtrl = TextEditingController(text: existing != null ? '${existing.floor}' : '');
    final capacityCtrl = TextEditingController(text: existing != null ? '${existing.capacity}' : '');
    final compatibleCtrl = TextEditingController(text: existing?.compatibleSubjects.join(', ') ?? '');
    String selectedType = existing?.roomType ?? 'Classroom';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Classroom / Lab' : 'Edit Room Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Room / Lab Identifier',
                  hintText: 'e.g. 101, Lab A',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Facility Type'),
                items: Room.roomTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedType = val);
                },
              ),
              if (selectedType.contains('Lab')) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: compatibleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Compatible Subjects / Facilities (comma-separated)',
                    hintText: 'e.g. OOP Lab, DSA Lab, Python Lab',
                    helperText: 'Leave empty to allow all subjects matching this facility type',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: buildingCtrl,
                      decoration: const InputDecoration(labelText: 'Building Block', hintText: 'e.g. Block A'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: floorCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Floor Number', hintText: 'e.g. 1'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Seating Capacity', hintText: 'e.g. 60'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            if (existing == null)
              OutlinedButton(
                onPressed: () async {
                  if (numberCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter Room / Lab Identifier'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  final collegeId = ref.read(activeCollegeIdProvider);
                  final cap = int.tryParse(capacityCtrl.text) ?? 60;
                  final flr = int.tryParse(floorCtrl.text) ?? 1;
                  final compSubjs = compatibleCtrl.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();

                  try {
                    final newRoom = Room(
                      id: 'room_${const Uuid().v4().substring(0, 8)}',
                      collegeId: collegeId,
                      roomNumber: numberCtrl.text.trim(),
                      building: buildingCtrl.text.trim(),
                      floor: flr,
                      capacity: cap,
                      roomType: selectedType,
                      compatibleSubjects: compSubjs,
                    );
                    await ref.read(roomControllerProvider.notifier).addRoom(newRoom);
                    setDialogState(() {
                      numberCtrl.clear();
                      buildingCtrl.clear();
                      floorCtrl.clear();
                      capacityCtrl.clear();
                      compatibleCtrl.clear();
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Room added! Enter another room or click Save & Close.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save room: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Add Another'),
              ),
            ElevatedButton(
              onPressed: () async {
                if (numberCtrl.text.isNotEmpty) {
                  final collegeId = ref.read(activeCollegeIdProvider);
                  final cap = int.tryParse(capacityCtrl.text) ?? 60;
                  final flr = int.tryParse(floorCtrl.text) ?? 1;
                  final compSubjs = compatibleCtrl.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();

                  try {
                    if (existing == null) {
                      final newRoom = Room(
                        id: 'room_${const Uuid().v4().substring(0, 8)}',
                        collegeId: collegeId,
                        roomNumber: numberCtrl.text.trim(),
                        building: buildingCtrl.text.trim(),
                        floor: flr,
                        capacity: cap,
                        roomType: selectedType,
                        compatibleSubjects: compSubjs,
                      );
                      await ref.read(roomControllerProvider.notifier).addRoom(newRoom);
                    } else {
                      final updated = existing.copyWith(
                        roomNumber: numberCtrl.text.trim(),
                        building: buildingCtrl.text.trim(),
                        floor: flr,
                        capacity: cap,
                        roomType: selectedType,
                        compatibleSubjects: compSubjs,
                      );
                      await ref.read(roomControllerProvider.notifier).updateRoom(updated);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(existing == null ? 'Room created successfully.' : 'Room updated successfully.'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save room: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(existing == null ? 'Save & Close' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceDialog(BuildContext context, WidgetRef ref, Room room) async {
    final reasonCtrl = TextEditingController(text: room.maintenanceReason ?? '');
    bool isUnderMaint = room.isUnderMaintenance;

    // Check affected entries
    final db = ref.read(databaseRepositoryProvider);
    final collegeId = ref.read(activeCollegeIdProvider);
    final entries = await db.getTimetableEntries(collegeId, roomId: room.id, status: 'published');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Maintenance Management: ${room.roomNumber}'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Under Maintenance / Unavailable', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Prevents classes from being scheduled in this room'),
                    value: isUnderMaint,
                    onChanged: (val) => setDialogState(() => isUnderMaint = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(labelText: 'Reason for Maintenance'),
                  ),
                  const SizedBox(height: 16),

                  // Impact Analysis
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: entries.isNotEmpty ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: entries.isNotEmpty ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              entries.isNotEmpty ? Icons.warning : Icons.check_circle,
                              size: 18,
                              color: entries.isNotEmpty ? AppTheme.errorColor : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Impact Analysis: ${entries.length} Classes Assigned to this Room',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: entries.isNotEmpty ? AppTheme.errorColor : const Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                        if (entries.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Marking this room under maintenance will raise hard conflicts in the Conflict Center until these classes are transferred to alternative operational rooms.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await ref.read(roomControllerProvider.notifier).setMaintenance(
                  roomId: room.id,
                  underMaintenance: isUnderMaint,
                  reason: reasonCtrl.text.trim(),
                  from: DateTime.now(),
                  to: DateTime.now().add(const Duration(days: 7)),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${room.roomNumber} maintenance state updated.')),
                  );
                }
              },
              child: const Text('Save Status'),
            ),
          ],
        ),
      ),
    );
  }
}
