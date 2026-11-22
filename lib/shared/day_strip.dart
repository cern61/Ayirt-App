import 'package:flutter/material.dart';

import '../core/formatters.dart';

/// Yatay kaydırılabilir gün seçici (Bugün · Cum 21 Kas · Cmt 22 Kas …)
class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.days, required this.selected, required this.onSelect});
  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = todayTr();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final isSel = d == selected;
          return InkWell(
            onTap: () => onSelect(d),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 62,
              decoration: BoxDecoration(
                color: isSel ? scheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSel ? scheme.primary : Colors.grey.shade300),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(d == today ? 'Bugün' : fmtWeekdayShort(d),
                    style: TextStyle(fontSize: 12, color: isSel ? Colors.white : Colors.grey.shade700)),
                const SizedBox(height: 2),
                Text(fmtCalendarDay(d),
                    style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.white : Colors.black87)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
