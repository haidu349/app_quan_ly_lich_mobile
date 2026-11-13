String formatDate(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '$day/$month/${d.year}';
}

String formatTime(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String formatTimeRange(DateTime start, DateTime end) {
  return '${formatTime(start)} - ${formatTime(end)}';
}

const _weekdays = ['Th 2', 'Th 3', 'Th 4', 'Th 5', 'Th 6', 'Th 7', 'CN'];

String formatWeekday(DateTime d) => _weekdays[d.weekday - 1];

String formatDayHeader(DateTime d) => '${formatWeekday(d)}, ${formatDate(d)}';