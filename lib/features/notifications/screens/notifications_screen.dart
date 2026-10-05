import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campus Announcements & Notifications',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Real-time alerts regarding timetable releases, classroom venue movements, and faculty substitution',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            notifsAsync.when(
              data: (notifs) {
                if (notifs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(60.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text('No announcements or notifications at this time.'),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notifs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final item = notifs[idx];
                    final dateStr = DateFormat('MMM d, y • h:mm a').format(item.timestamp);

                    return Card(
                      color: item.isRead ? Colors.white : const Color(0xFFF0F9FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: item.isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBAE6FD)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                              child: const Icon(Icons.campaign, color: AppTheme.primaryColor),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: item.isRead ? const Color(0xFF0F172A) : AppTheme.primaryColor,
                                        ),
                                      ),
                                      Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.message,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                  ),
                                ],
                              ),
                            ),
                            if (!item.isRead)
                              IconButton(
                                icon: const Icon(Icons.mark_email_read, size: 18, color: Colors.teal),
                                tooltip: 'Mark as read',
                                onPressed: () {
                                  ref.read(notificationControllerProvider.notifier).markAsRead(item.id);
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading notifications: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
