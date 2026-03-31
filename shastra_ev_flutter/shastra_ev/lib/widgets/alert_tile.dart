import 'package:flutter/material.dart';
import '../models/vehicle_data.dart';
import '../theme/app_theme.dart';

class AlertTile extends StatefulWidget {
  final String label;
  final String statusText;
  final AlertLevel level;
  final IconData icon;
  final VoidCallback? onTap;

  const AlertTile({
    super.key,
    required this.label,
    required this.statusText,
    required this.level,
    required this.icon,
    this.onTap,
  });

  @override
  State<AlertTile> createState() => _AlertTileState();
}

class _AlertTileState extends State<AlertTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.level) {
        AlertLevel.ok => AppColors.green,
        AlertLevel.warning => AppColors.amber,
        AlertLevel.danger => AppColors.red,
      };

  Color get _bgColor => switch (widget.level) {
        AlertLevel.ok => AppColors.green.withOpacity(0.1),
        AlertLevel.warning => AppColors.amber.withOpacity(0.1),
        AlertLevel.danger => AppColors.red.withOpacity(0.12),
      };

  @override
  Widget build(BuildContext context) {
    final isDanger = widget.level == AlertLevel.danger;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDanger ? _color.withOpacity(0.5) : AppColors.border,
            width: isDanger ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _anim,
              builder: (_, child) => Opacity(
                opacity: isDanger ? _anim.value * 0.7 + 0.3 : 1.0,
                child: child,
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: _color, size: 20),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 1.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.statusText,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
