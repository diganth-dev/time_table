import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = subtitle != null &&
        (subtitle!.contains('✓') ||
            subtitle!.toLowerCase().contains('verified') ||
            subtitle!.toLowerCase().contains('ready') ||
            subtitle!.toLowerCase().contains('zero'));

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hasBoundedHeight = constraints.hasBoundedHeight;
            final isCompact = hasBoundedHeight && constraints.maxHeight < 125;
            final isUltraCompact = hasBoundedHeight && constraints.maxHeight < 100;

            final horizontalPadding = isUltraCompact ? 12.0 : 16.0;
            final verticalPadding = isUltraCompact
                ? 8.0
                : (isCompact ? 10.0 : 14.0);

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: hasBoundedHeight
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.start,
                mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontSize: isUltraCompact ? 11 : (isCompact ? 12 : 12.5),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.all(isUltraCompact ? 4 : (isCompact ? 6 : 7)),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: isUltraCompact ? 16 : (isCompact ? 18 : 20),
                        ),
                      ),
                    ],
                  ),
                  if (!hasBoundedHeight) const SizedBox(height: 8),
                  if (hasBoundedHeight)
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: isUltraCompact ? 20 : (isCompact ? 22 : 26),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  if (subtitle != null) ...[
                    if (!hasBoundedHeight) const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isUltraCompact ? 10 : (isCompact ? 11 : 11.5),
                        fontWeight: isPositive ? FontWeight.w600 : FontWeight.normal,
                        color: isPositive ? const Color(0xFF009668) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
