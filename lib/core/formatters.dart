import 'package:intl/intl.dart';

/// Türkiye saati (UTC+3, yaz/kış saati uygulaması yok).
DateTime toTr(DateTime dt) => dt.toUtc().add(const Duration(hours: 3));

/// Bugünün tarihi (Türkiye'ye göre), saatsiz
DateTime todayTr() {
  final now = toTr(DateTime.now());
  return DateTime(now.year, now.month, now.day);
}

String fmtTime(DateTime dt) => DateFormat('HH:mm', 'tr_TR').format(toTr(dt));

String fmtDayLong(DateTime dt) => DateFormat('d MMMM EEEE', 'tr_TR').format(toTr(dt));

String fmtDateTime(DateTime dt) => DateFormat('d MMM y, HH:mm', 'tr_TR').format(toTr(dt));


String fmtCalendarDay(DateTime day) => DateFormat('d MMM', 'tr_TR').format(day);
String fmtWeekdayShort(DateTime day) => DateFormat('EEE', 'tr_TR').format(day);


String toSqlDate(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

String fmtPrice(double? price) {
  if (price == null) return '';
  final f = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: price % 1 == 0 ? 0 : 2);
  return f.format(price);
}
