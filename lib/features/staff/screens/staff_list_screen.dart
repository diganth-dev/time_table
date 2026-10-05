import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/workflow_progress_bar.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import 'staff_absence_screen.dart';
import 'staff_availability_screen.dart';

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  String _searchQuery = '';
  String? _selectedDeptFilter;
  String? _selectedStatusFilter;

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);
    final depts = ref.watch(departmentListProvider).value ?? [];
    final deptMap = {for (var d in depts) d.id: d};
    ref.watch(timeSlotsProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkflowProgressBar(currentStep: WorkflowStep.professors),
            const SizedBox(height: 20),

            // Top Bar
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 750;
                final titleWidget = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Faculty & Staff Directory',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage professors, teaching limits, subject authorizations, and invitation statuses',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                );

                final addBtn = ElevatedButton.icon(
                  onPressed: () => _showStaffDialog(context, null, depts),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add Professor'),
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
            const SizedBox(height: 20),

            // Live 4-Card Metric Strip
            LayoutBuilder(
              builder: (context, constraints) {
                final allStaff = staffAsync.value ?? [];
                final totalFaculty = allStaff.length;
                final activeStaff = allStaff.where((s) => s.status == 'active').toList();
                final activeCount = activeStaff.length;
                final coveragePct = totalFaculty > 0 ? ((activeCount / totalFaculty) * 100).toInt() : 100;
                final unassignedCount = allStaff.where((s) => s.subjectsCanTeach.isEmpty).length;
                final totalMaxDaily = allStaff.fold<int>(0, (sum, s) => sum + s.maxClassesPerDay);
                final avgDaily = totalFaculty > 0 ? (totalMaxDaily / totalFaculty).toStringAsFixed(1) : '0';
                final hardClashes = ref.watch(conflictsListProvider).value?.where((c) => c.isHard).length ?? 0;

                final c1 = StatCard(
                  title: 'Total Faculty',
                  value: '$totalFaculty',
                  subtitle: 'All active & registered groups',
                  icon: Icons.groups_outlined,
                  iconColor: AppTheme.primaryColor,
                );
                final c2 = StatCard(
                  title: 'Scheduled Load',
                  value: '$avgDaily slots / d',
                  subtitle: 'Target capacity allocation',
                  icon: Icons.speed_outlined,
                  iconColor: AppTheme.secondaryColor,
                );
                final c3 = StatCard(
                  title: 'Active Coverage',
                  value: '$coveragePct%',
                  subtitle: unassignedCount == 0 ? '✓ Fully allocated' : '$unassignedCount flexible teaching',
                  icon: Icons.verified_outlined,
                  iconColor: const Color(0xFF009668),
                );
                final c4 = StatCard(
                  title: 'Hard Clashes',
                  value: '$hardClashes',
                  subtitle: hardClashes == 0 ? '✓ Ready for matrix run' : 'Requires resolution',
                  icon: Icons.event_available_outlined,
                  iconColor: hardClashes == 0 ? const Color(0xFF009668) : AppTheme.errorColor,
                  onTap: () => context.go('/conflicts'),
                );

                final w = constraints.maxWidth;
                if (w < 650) {
                  return Column(
                    children: [
                      Row(children: [Expanded(child: c1), const SizedBox(width: 10), Expanded(child: c2)]),
                      const SizedBox(height: 10),
                      Row(children: [Expanded(child: c3), const SizedBox(width: 10), Expanded(child: c4)]),
                    ],
                  );
                } else if (w < 1050) {
                  return Column(
                    children: [
                      Row(children: [Expanded(child: c1), const SizedBox(width: 14), Expanded(child: c2)]),
                      const SizedBox(height: 14),
                      Row(children: [Expanded(child: c3), const SizedBox(width: 14), Expanded(child: c4)]),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(child: c1),
                      const SizedBox(width: 14),
                      Expanded(child: c2),
                      const SizedBox(width: 14),
                      Expanded(child: c3),
                      const SizedBox(width: 14),
                      Expanded(child: c4),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 20),

            // Search and Filter Bar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 750;
                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search by faculty name, email, or employee ID...',
                              prefixIcon: Icon(Icons.search, size: 20),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _selectedDeptFilter,
                                  decoration: const InputDecoration(labelText: 'Filter Department'),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('All Departments')),
                                    ...depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                                  ],
                                  onChanged: (val) => setState(() => _selectedDeptFilter = val),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _selectedStatusFilter,
                                  decoration: const InputDecoration(labelText: 'Status'),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text('All Statuses')),
                                    DropdownMenuItem(value: 'active', child: Text('Active Only')),
                                    DropdownMenuItem(value: 'invited', child: Text('Invited / Pending Only')),
                                  ],
                                  onChanged: (val) => setState(() => _selectedStatusFilter = val),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.restart_alt, color: Color(0xFF64748B)),
                                tooltip: 'Reset filters',
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedDeptFilter = null;
                                    _selectedStatusFilter = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search by faculty name, email, or employee ID...',
                              prefixIcon: Icon(Icons.search, size: 20),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedDeptFilter,
                            decoration: const InputDecoration(labelText: 'Filter Department'),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Departments')),
                              ...depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                            ],
                            onChanged: (val) => setState(() => _selectedDeptFilter = val),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedStatusFilter,
                            decoration: const InputDecoration(labelText: 'Status'),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All Statuses')),
                              DropdownMenuItem(value: 'active', child: Text('Active Only')),
                              DropdownMenuItem(value: 'invited', child: Text('Invited / Pending Only')),
                            ],
                            onChanged: (val) => setState(() => _selectedStatusFilter = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.restart_alt, color: Color(0xFF64748B)),
                          tooltip: 'Reset filters',
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _selectedDeptFilter = null;
                              _selectedStatusFilter = null;
                            });
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Staff Table
            staffAsync.when(
              data: (staffList) {
                var filtered = staffList.where((s) {
                  final matchesSearch = s.name.toLowerCase().contains(_searchQuery) ||
                      s.email.toLowerCase().contains(_searchQuery) ||
                      s.employeeId.toLowerCase().contains(_searchQuery);
                  final matchesDept = _selectedDeptFilter == null || s.departmentId == _selectedDeptFilter;
                  final matchesStatus = _selectedStatusFilter == null || s.status == _selectedStatusFilter;
                  return matchesSearch && matchesDept && matchesStatus;
                }).toList();

                if (staffList.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: Text('No professors added yet. Click "Add Professor" to add your faculty.')),
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: Text('No faculty members found matching filters.')),
                    ),
                  );
                }

                final tableCard = Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            columnSpacing: 20,
                            horizontalMargin: 16,
                            dataRowMinHeight: 64,
                            dataRowMaxHeight: 88,
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Faculty Member', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Employee ID', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Max Load', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Account Status', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Availability', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: filtered.map((staff) {
                              final dept = deptMap[staff.departmentId]?.code ?? 'General';
                              final isActive = staff.status == 'active';

                              return DataRow(
                                cells: [
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(0xFFEFF4FF),
                                            child: Text(
                                              staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'T',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0051D5), fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Tooltip(
                                                  message: staff.name,
                                                  child: Text(
                                                    staff.name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Tooltip(
                                                  message: staff.email,
                                                  child: Text(
                                                    staff.email,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  staff.subjectsCanTeach.isEmpty
                                                      ? 'Can teach: All Subjects'
                                                      : 'Can teach: ${staff.subjectsCanTeach.join(", ")}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: staff.subjectsCanTeach.isEmpty ? const Color(0xFF15803D) : const Color(0xFF0284C7),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF4FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFDCE9FF)),
                                      ),
                                      child: Text(
                                        staff.employeeId,
                                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0051D5)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Chip(label: Text(dept, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)),
                                  DataCell(Text(staff.designation, overflow: TextOverflow.ellipsis)),
                                  DataCell(Text('${staff.maxClassesPerDay} / day')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isActive ? const Color(0xFFEFFDF5) : const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isActive ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: isActive ? const Color(0xFF009668) : const Color(0xFFD97706),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isActive ? 'Active' : 'Invited (Pending)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isActive ? const Color(0xFF005236) : const Color(0xFF92400E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(_buildAvailabilityCell(context, staff, depts)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.event_available, size: 18, color: Colors.teal),
                                          tooltip: 'Manage Availability',
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => StaffAvailabilityScreen(staff: staff)),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.event_busy, size: 18, color: AppTheme.errorColor),
                                          tooltip: 'Record Absence & Check Impact',
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => StaffAbsenceScreen(staff: staff)),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18),
                                          tooltip: 'Edit Details',
                                          onPressed: () => _showStaffDialog(context, staff, depts),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          tooltip: 'Delete Staff',
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (c) => AlertDialog(
                                                title: const Text('Delete Staff Member?'),
                                                content: Text('Are you sure you want to remove ${staff.name}?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                                                    onPressed: () => Navigator.pop(c, true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              try {
                                                await ref.read(staffControllerProvider.notifier).deleteStaff(staff.id);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Removed ${staff.name}')),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Failed to delete staff: $e'),
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
                        ),
                      );
                    },
                  ),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    tableCard,
                    const SizedBox(height: 24),
                    _buildBottomAnalytics(context, staffList, depts),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading staff: $e'),
            ),

            // Step Navigation Controls
            WorkflowBottomBar(
              backLabel: '← College Schedule',
              onBack: () => context.go('/schedule'),
              nextLabel: 'Continue to Sections & Subjects →',
              onNext: () async {
                final staffList = ref.read(staffListProvider).value ?? [];
                final activeStaff = staffList.where((s) => s.status != 'inactive').toList();
                if (activeStaff.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please add at least one professor before proceeding to Sections & Subjects.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                context.go('/sections-subjects');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAnalytics(BuildContext context, List<Staff> staffList, List<Department> depts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1180;

        final deptCard = Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Department Distribution',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'By Headcount',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (depts.isEmpty)
                  const Text('No departments defined yet.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
                else
                  ...depts.take(4).map((d) {
                    final count = staffList.where((s) => s.departmentId == d.id).length;
                    final pct = staffList.isNotEmpty ? ((count / staffList.length) * 100).toInt() : 0;
                    final ratio = staffList.isNotEmpty ? count / staffList.length : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  d.name,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('$count / ${staffList.length} ($pct%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0051D5))),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: const Color(0xFFEFF4FF),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0051D5)),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 4),
                const Divider(color: Color(0xFFE2E8F0), height: 16),
                const Row(
                  children: [
                    Icon(Icons.verified, size: 14, color: Color(0xFF009668)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Capacity limit: 6 lectures / day per staff • Zero Overlaps',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        final loadCard = Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Weekly Load Balance',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Text(
                        'Balanced',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF005236)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) {
                    return Column(
                      children: [
                        Container(
                          width: 22,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF4FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 22,
                            height: day == 'Sat' ? 24 : 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0051D5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(day, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE2E8F0), height: 16),
                const Text(
                  'Optimal distribution spread evenly across working days.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );

        final adminCard = Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: Color(0xFF0051D5)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Faculty Administration Center',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAdminTip('Role-Based Access', 'Faculty accounts can view personalized timetables when invited.'),
                const SizedBox(height: 8),
                _buildAdminTip('Load Distribution', 'Per-day lecture limits prevent excessive fatigue and clashes.'),
                const SizedBox(height: 8),
                _buildAdminTip('Availability Tracking', 'Specific unavailable time blocks are strictly honored.'),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/timetable'),
                    icon: const Icon(Icons.grid_view, size: 14),
                    label: const Text('View Timetable Matrix →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            children: [
              deptCard,
              const SizedBox(height: 16),
              loadCard,
              const SizedBox(height: 16),
              adminCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: deptCard),
            const SizedBox(width: 16),
            Expanded(child: loadCard),
            const SizedBox(width: 16),
            Expanded(child: adminCard),
          ],
        );
      },
    );
  }

  Widget _buildAdminTip(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 5,
          height: 5,
          decoration: const BoxDecoration(color: Color(0xFF0051D5), shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.4),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityCell(BuildContext context, Staff staff, List<Department> depts) {
    if (staff.unavailableTimes.isEmpty) {
      return Tooltip(
        message: 'Available for all timetable slots',
        child: InkWell(
          onTap: () => _showAvailabilityDetailsDialog(context, staff, depts),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'All slots available',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (staff.unavailableTimes.length == 1) {
      final u = staff.unavailableTimes.first;
      final dayAbbr = u.dayOfWeek.length > 3 ? u.dayOfWeek.substring(0, 3) : u.dayOfWeek;
      final label = 'Unavailable: $dayAbbr ${u.startTime}-${u.endTime}';
      return Tooltip(
        message: 'Click to view full availability details',
        child: InkWell(
          onTap: () => _showAvailabilityDetailsDialog(context, staff, depts),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 14, color: Colors.amber.shade900),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final count = staff.unavailableTimes.length;
    return Tooltip(
      message: 'Click to view all $count unavailable periods',
      child: InkWell(
        onTap: () => _showAvailabilityDetailsDialog(context, staff, depts),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.amber.shade900),
              const SizedBox(width: 5),
              Text(
                '$count unavailable periods',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade900,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 13, color: Colors.amber.shade800),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvailabilityDetailsDialog(BuildContext context, Staff staff, List<Department> depts) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'P',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      staff.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Availability & Schedule Constraints',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: staff.unavailableTimes.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No unavailable periods configured.\nThis professor is available for all timetable slots.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${staff.unavailableTimes.length} Unavailable Period${staff.unavailableTimes.length > 1 ? "s" : ""}:',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 10),
                        ...staff.unavailableTimes.map((u) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 8),
                                Text(
                                  u.dayOfWeek,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                                ),
                                const Spacer(),
                                Text(
                                  '${u.startTime} - ${u.endTime}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF78350F)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Professor'),
              onPressed: () {
                Navigator.pop(ctx);
                _showStaffDialog(context, staff, depts);
              },
            ),
          ],
        );
      },
    );
  }

  void _showStaffDialog(BuildContext context, Staff? existing, List<Department> depts) {
    final collegeId = ref.read(activeCollegeIdProvider);
    final timeSlots = ref.read(timeSlotsProvider).value ?? [];
    showDialog(
      context: context,
      builder: (ctx) => StaffAddEditDialog(
        existing: existing,
        depts: depts,
        collegeId: collegeId,
        timeSlots: timeSlots,
        onSave: (staff) async {
          if (existing == null) {
            await ref.read(staffControllerProvider.notifier).addStaff(staff);
          } else {
            await ref.read(staffControllerProvider.notifier).updateStaff(staff);
          }
        },
        onAddAnother: existing == null
            ? (staff) async {
                await ref.read(staffControllerProvider.notifier).addStaff(staff);
              }
            : null,
      ),
    );
  }
}

class ScheduleTimingOption {
  final String value;
  final String label;
  final int minutes;

  const ScheduleTimingOption({
    required this.value,
    required this.label,
    required this.minutes,
  });
}

String formatTimeTo12Hour(String raw) {
  final mins = UnavailableTime.parseTimeToMinutes(raw);
  if (mins == null) return raw;
  final h = (mins ~/ 60) % 24;
  final m = mins % 60;
  final period = h >= 12 ? 'PM' : 'AM';
  final displayHour = (h % 12 == 0) ? 12 : (h % 12);
  final displayMin = m.toString().padLeft(2, '0');
  return '$displayHour:$displayMin $period';
}

List<ScheduleTimingOption> buildScheduleTimingOptions(List<TimeSlot> slots) {
  if (slots.isEmpty) return const [];

  final validSlots = slots.where((s) {
    final startM = UnavailableTime.parseTimeToMinutes(s.startTime);
    final endM = UnavailableTime.parseTimeToMinutes(s.endTime);
    return startM != null && endM != null;
  }).toList();

  if (validSlots.isEmpty) return const [];

  validSlots.sort((a, b) {
    final aM = UnavailableTime.parseTimeToMinutes(a.startTime)!;
    final bM = UnavailableTime.parseTimeToMinutes(b.startTime)!;
    final cmp = aM.compareTo(bM);
    return cmp != 0 ? cmp : a.order.compareTo(b.order);
  });

  final Map<int, ScheduleTimingOption> optionsByMinute = {};

  // First pass: add start times for academic periods and breaks
  for (final slot in validSlots) {
    final startM = UnavailableTime.parseTimeToMinutes(slot.startTime)!;
    if (!optionsByMinute.containsKey(startM)) {
      final label = slot.isBreak
          ? '${slot.breakTitle ?? 'Break'} — ${formatTimeTo12Hour(slot.startTime)}'
          : 'Period ${slot.periodNumber} — ${formatTimeTo12Hour(slot.startTime)}';
      optionsByMinute[startM] = ScheduleTimingOption(
        value: slot.startTime,
        label: label,
        minutes: startM,
      );
    }
  }

  // Second pass: add end times that are not already covered
  for (final slot in validSlots) {
    final endM = UnavailableTime.parseTimeToMinutes(slot.endTime)!;
    if (!optionsByMinute.containsKey(endM)) {
      final label = slot.isBreak
          ? '${slot.breakTitle ?? 'Break'} End — ${formatTimeTo12Hour(slot.endTime)}'
          : 'Period ${slot.periodNumber} End — ${formatTimeTo12Hour(slot.endTime)}';
      optionsByMinute[endM] = ScheduleTimingOption(
        value: slot.endTime,
        label: label,
        minutes: endM,
      );
    }
  }

  final result = optionsByMinute.values.toList();
  result.sort((a, b) => a.minutes.compareTo(b.minutes));
  return result;
}

class StaffAddEditDialog extends StatefulWidget {
  final Staff? existing;
  final List<Department> depts;
  final String collegeId;
  final List<TimeSlot>? timeSlots;
  final Future<void> Function(Staff staff) onSave;
  final Future<void> Function(Staff staff)? onAddAnother;

  const StaffAddEditDialog({
    super.key,
    this.existing,
    required this.depts,
    required this.collegeId,
    this.timeSlots,
    required this.onSave,
    this.onAddAnother,
  });

  @override
  State<StaffAddEditDialog> createState() => _StaffAddEditDialogState();
}

class _StaffAddEditDialogState extends State<StaffAddEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _designationCtrl;
  late final TextEditingController _canTeachCtrl;
  late final TextEditingController _maxPerDayCtrl;

  String? _selectedFrom;
  String? _selectedTo;

  late final FocusNode _nameFocus;
  late final FocusNode _deptFocus;
  late final FocusNode _designationFocus;
  late final FocusNode _canTeachFocus;
  late final FocusNode _maxDailyFocus;

  late final FocusNode _dayFocus;
  late final FocusNode _fromFocus;
  late final FocusNode _toFocus;
  late final FocusNode _addTimeFocus;

  late String _selectedDeptId;
  String _selectedDay = 'Monday';
  late List<UnavailableTime> _unavailableTimes;
  String? _availabilityError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _designationCtrl = TextEditingController(text: e?.designation ?? '');
    _canTeachCtrl = TextEditingController(text: e != null ? e.subjectsCanTeach.join(', ') : '');
    _maxPerDayCtrl = TextEditingController(text: e != null ? '${e.maxClassesPerDay}' : '4');


    _nameFocus = FocusNode();
    _deptFocus = FocusNode();
    _designationFocus = FocusNode();
    _canTeachFocus = FocusNode();
    _maxDailyFocus = FocusNode();

    _dayFocus = FocusNode();
    _fromFocus = FocusNode();
    _toFocus = FocusNode();
    _addTimeFocus = FocusNode();

    _selectedDeptId = e?.departmentId ?? (widget.depts.isNotEmpty ? widget.depts.first.id : '');
    _unavailableTimes = e != null ? List<UnavailableTime>.from(e.unavailableTimes) : [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _designationCtrl.dispose();
    _canTeachCtrl.dispose();
    _maxPerDayCtrl.dispose();

    _nameFocus.dispose();
    _deptFocus.dispose();
    _designationFocus.dispose();
    _canTeachFocus.dispose();
    _maxDailyFocus.dispose();
    _dayFocus.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    _addTimeFocus.dispose();
    super.dispose();
  }

  void _addUnavailableTime() {
    final options = buildScheduleTimingOptions(widget.timeSlots ?? []);
    if (options.isEmpty) {
      setState(() {
        _availabilityError = 'No College Schedule timings found. Please configure College Schedule first.';
      });
      return;
    }

    if (_selectedFrom == null || _selectedFrom!.trim().isEmpty) {
      setState(() {
        _availabilityError = 'Please select a "From" time.';
      });
      return;
    }

    if (_selectedTo == null || _selectedTo!.trim().isEmpty) {
      setState(() {
        _availabilityError = 'Please select a "To" time.';
      });
      return;
    }

    final error = UnavailableTime.validateTimeRange(_selectedFrom!, _selectedTo!);
    if (error != null) {
      setState(() {
        _availabilityError = error;
      });
      return;
    }

    final newTime = UnavailableTime(
      dayOfWeek: _selectedDay,
      startTime: _selectedFrom!,
      endTime: _selectedTo!,
    );

    final exists = _unavailableTimes.any((u) =>
        u.dayOfWeek.toLowerCase() == newTime.dayOfWeek.toLowerCase() &&
        u.startTime == newTime.startTime &&
        u.endTime == newTime.endTime);

    if (exists) {
      setState(() {
        _availabilityError = 'This unavailable period is already added.';
      });
      return;
    }

    setState(() {
      _unavailableTimes.add(newTime);
      _selectedFrom = null;
      _selectedTo = null;
      _availabilityError = null;
    });

    _fromFocus.requestFocus();
  }

  Future<void> _saveStaff({required bool addAnother}) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter professor name.'), backgroundColor: Colors.red),
      );
      _nameFocus.requestFocus();
      return;
    }

    final maxDaily = int.tryParse(_maxPerDayCtrl.text) ?? 4;
    final parsedCanTeach = _canTeachCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _isSaving = true);
    try {
      if (widget.existing == null) {
        final newStaff = Staff(
          id: 'staff_${const Uuid().v4().substring(0, 8)}',
          collegeId: widget.collegeId,
          name: name,
          departmentId: _selectedDeptId,
          designation: _designationCtrl.text.trim().isNotEmpty ? _designationCtrl.text.trim() : 'Faculty',
          status: 'active',
          subjectsCanTeach: parsedCanTeach,
          maxClassesPerDay: maxDaily,
          unavailableTimes: List.from(_unavailableTimes),
        );

        if (addAnother && widget.onAddAnother != null) {
          await widget.onAddAnother!(newStaff);
          if (mounted) {
            setState(() {
              _nameCtrl.clear();
              _canTeachCtrl.clear();
              _selectedFrom = null;
              _selectedTo = null;
              _unavailableTimes.clear();
              _availabilityError = null;
              _isSaving = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Professor added! You can add another or click Save & Close.')),
            );
            _nameFocus.requestFocus();
          }
        } else {
          await widget.onSave(newStaff);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Professor added successfully.')),
            );
          }
        }
      } else {
        final updated = widget.existing!.copyWith(
          name: name,
          departmentId: _selectedDeptId,
          designation: _designationCtrl.text.trim(),
          subjectsCanTeach: parsedCanTeach,
          maxClassesPerDay: maxDaily,
          unavailableTimes: List.from(_unavailableTimes),
        );
        await widget.onSave(updated);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Professor updated successfully.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save professor: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleOptions = buildScheduleTimingOptions(widget.timeSlots ?? []);
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Professor' : 'Edit Professor Details'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _deptFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Professor Name',
                  hintText: 'e.g. Dr. Ravi',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                focusNode: _deptFocus,
                initialValue: _selectedDeptId.isNotEmpty ? _selectedDeptId : null,
                decoration: const InputDecoration(labelText: 'Department'),
                items: widget.depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDeptId = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _designationCtrl,
                focusNode: _designationFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _canTeachFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Designation',
                  hintText: 'e.g. Professor',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _canTeachCtrl,
                focusNode: _canTeachFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _maxDailyFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Subjects They Can Teach',
                  hintText: 'e.g. software, DBMS, OS (partial words supported)',
                  helperText: 'Comma-separated. Supports partial words (e.g. "software"). Leave empty for all subjects.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _maxPerDayCtrl,
                focusNode: _maxDailyFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _dayFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Max Classes Per Day',
                  hintText: 'e.g. 4',
                ),
              ),
              const SizedBox(height: 20),

              // === PROFESSOR AVAILABILITY SECTION ===
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.schedule, size: 18, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Professor Availability',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Optional: Specify any time windows when this professor is unavailable. If no unavailable periods are added, the professor remains available for all valid periods.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),

                    // Inputs: Day -> From -> To
                    DropdownButtonFormField<String>(
                      focusNode: _dayFocus,
                      initialValue: _selectedDay,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Day',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Monday', child: Text('Monday')),
                        DropdownMenuItem(value: 'Tuesday', child: Text('Tuesday')),
                        DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday')),
                        DropdownMenuItem(value: 'Thursday', child: Text('Thursday')),
                        DropdownMenuItem(value: 'Friday', child: Text('Friday')),
                        DropdownMenuItem(value: 'Saturday', child: Text('Saturday')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedDay = val);
                          _fromFocus.requestFocus();
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('dropdown_from_${_selectedFrom ?? "none"}'),
                            focusNode: _fromFocus,
                            initialValue: _selectedFrom,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'From',
                              isDense: true,
                            ),
                            hint: Text(scheduleOptions.isEmpty ? 'No schedule' : 'Select start'),
                            items: scheduleOptions.map((opt) {
                              return DropdownMenuItem<String>(
                                value: opt.value,
                                child: Text(
                                  opt.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: scheduleOptions.isEmpty
                                ? null
                                : (val) {
                                    setState(() {
                                      _selectedFrom = val;
                                      _availabilityError = null;
                                    });
                                    _toFocus.requestFocus();
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('dropdown_to_${_selectedTo ?? "none"}'),
                            focusNode: _toFocus,
                            initialValue: _selectedTo,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'To',
                              isDense: true,
                            ),
                            hint: Text(scheduleOptions.isEmpty ? 'No schedule' : 'Select end'),
                            items: scheduleOptions.map((opt) {
                              return DropdownMenuItem<String>(
                                value: opt.value,
                                child: Text(
                                  opt.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: scheduleOptions.isEmpty
                                ? null
                                : (val) {
                                    setState(() {
                                      _selectedTo = val;
                                      _availabilityError = null;
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Button: Add Unavailable Time
                    OutlinedButton.icon(
                      focusNode: _addTimeFocus,
                      onPressed: _addUnavailableTime,
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Add Unavailable Time'),
                    ),

                    if (_availabilityError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _availabilityError!,
                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ],

                    const SizedBox(height: 10),
                    if (_unavailableTimes.isEmpty)
                      const Text(
                        'No unavailable periods specified (available for all slots).',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _unavailableTimes.map((item) {
                          return Chip(
                            avatar: const Icon(Icons.block, size: 14, color: Colors.redAccent),
                            label: Text(
                              '${item.dayOfWeek}: ${item.startTime} - ${item.endTime}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() {
                                _unavailableTimes.remove(item);
                              });
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.existing == null)
          OutlinedButton(
            onPressed: _isSaving ? null : () => _saveStaff(addAnother: true),
            child: const Text('Add Another'),
          ),
        ElevatedButton(
          onPressed: _isSaving ? null : () => _saveStaff(addAnother: false),
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.existing == null ? 'Save & Close' : 'Save Changes'),
        ),
      ],
    );
  }
}
