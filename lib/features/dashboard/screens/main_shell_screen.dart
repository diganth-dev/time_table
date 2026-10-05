import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../providers/providers.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  final Widget child;

  const MainShellScreen({super.key, required this.child});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final conflicts = ref.watch(conflictsListProvider).value ?? [];
    final hardConflictsCount = conflicts.where((c) => c.isHard).length;
    final currentUser = ref.watch(currentProfileProvider);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryContainer.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.table_chart, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TimePilot',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A), letterSpacing: -0.3),
                  ),
                  Text(
                    'Automated College Timetable Generator',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600, letterSpacing: 0.2),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Academic Year / Session Pill
          if (isDesktop)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFDCE9FF)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF0051D5)),
                  SizedBox(width: 5),
                  Text(
                    'AY 2026-27',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0051D5)),
                  ),
                ],
              ),
            ),

          // Conflicts alert badge
          if (hardConflictsCount > 0)
            IconButton(
              icon: Badge(
                label: Text('$hardConflictsCount'),
                backgroundColor: AppTheme.errorColor,
                child: const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
              ),
              tooltip: '$hardConflictsCount Conflict(s) Detected',
              onPressed: () => context.go('/conflicts'),
            ),

          // Primary "CREATE TIMETABLE" Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 1,
              ),
              onPressed: () => context.go('/workflow'),
              icon: const Icon(Icons.auto_awesome, size: 15),
              label: const Text(
                'CREATE TIMETABLE',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.4),
              ),
            ),
          ),

          // Notification icon
          if (isDesktop) ...[
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined, size: 20, color: Color(0xFF64748B)),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0051D5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              tooltip: 'Notifications',
              onPressed: () {},
            ),
            const SizedBox(width: 4),

            // Profile Avatar with Dropdown Menu
            PopupMenuButton<String>(
              tooltip: 'Account Profile',
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) async {
                if (value == 'settings') {
                  context.go('/settings');
                } else if (value == 'logout') {
                  await ref.read(authControllerProvider.notifier).signOut();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentUser?.name.isNotEmpty == true ? currentUser!.name : 'Administrator',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        currentUser?.email.isNotEmpty == true ? currentUser!.email : 'admin@timepilot.edu',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          currentUser?.role.displayName ?? 'College Admin',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0051D5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 18, color: Color(0xFF475569)),
                      SizedBox(width: 10),
                      Text('College Settings', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
                      SizedBox(width: 10),
                      Text('Sign Out', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(right: 16, left: 4),
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFF0F172A),
                  child: Text(
                    (currentUser?.name.isNotEmpty == true)
                        ? currentUser!.name.substring(0, 1).toUpperCase()
                        : 'AD',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      drawer: isDesktop ? null : _buildDrawer(context),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(context),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: _buildNavItems(context),
            ),
          ),
          _buildAppFooter(),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0F172A)),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.table_chart, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'TimePilot',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Automated College Timetable Generator',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: _buildNavItems(context),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
            title: const Text('Sign Out', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.of(context).pop();
              await ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return [
      _sectionHeader('OVERVIEW & GENERATION'),
      _navTile(context, Icons.dashboard_outlined, Icons.dashboard, '1. Dashboard', '/dashboard', location),
      _navTile(context, Icons.play_circle_outline, Icons.play_circle, '6. Generate Timetable', '/workflow', location, isAccent: true),

      const SizedBox(height: 12),
      _sectionHeader('INPUT CONFIGURATION'),
      _navTile(context, Icons.calendar_today_outlined, Icons.calendar_today, '2. College Schedule', '/schedule', location),
      _navTile(context, Icons.person_outline, Icons.person, '3. Professors', '/professors', location),
      _navTile(context, Icons.menu_book_outlined, Icons.menu_book, '4. Sections & Subjects', '/sections-subjects', location),
      _navTile(context, Icons.meeting_room_outlined, Icons.meeting_room, '5. Rooms & Labs', '/rooms', location),

      const SizedBox(height: 12),
      _sectionHeader('TIMETABLE & VERIFICATION'),
      _navTile(context, Icons.calendar_view_week_outlined, Icons.calendar_view_week, '7. Timetable Matrix', '/timetable', location),
      _navTile(context, Icons.rule_folder_outlined, Icons.rule_folder, '8. Conflict Center', '/conflicts', location),
      _navTile(context, Icons.download_outlined, Icons.download, '9. Export Timetable', '/export', location),
    ];
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context,
    IconData icon,
    IconData activeIcon,
    String label,
    String route,
    String currentRoute, {
    bool isAccent = false,
  }) {
    final selected = currentRoute == route || (route != '/dashboard' && currentRoute.startsWith(route));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
              Navigator.of(context).pop();
            }
            context.go(route);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  color: selected
                      ? Colors.white
                      : (isAccent ? AppTheme.secondaryColor : const Color(0xFF64748B)),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : (isAccent ? const Color(0xFF0F172A) : const Color(0xFF334155)),
                      fontWeight: selected ? FontWeight.w600 : (isAccent ? FontWeight.bold : FontWeight.w500),
                      fontSize: 12.5,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6FFBBE),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FF),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFF009668),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF009668).withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Engine Idle • Ready',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Academic Core v2.4',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
