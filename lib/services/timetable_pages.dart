// Bảng giờ lật trang theo ngày hoặc theo tuần. Mỗi ngày được đánh một số
// tính từ một ngày thứ Hai làm mốc, nên trang của tuần luôn bắt đầu từ thứ Hai.
final DateTime _epochUtc = DateTime.utc(2000, 1, 3); // một ngày thứ Hai

// Số thứ tự của ngày (dùng UTC để không bị lệch giờ mùa hè)
int dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).difference(_epochUtc).inDays;

DateTime dateOfDayNumber(int n) => DateTime(2000, 1, 3 + n);

// Trang chứa ngày [d]: theo tuần (7 ngày một trang) hoặc theo ngày
int pageOfDay(DateTime d, {required bool week}) {
  final n = dayNumber(d);
  final safe = n < 0 ? 0 : n;
  return week ? safe ~/ 7 : safe;
}

int firstDayNumberOfPage(int page, {required bool week}) =>
    week ? page * 7 : page;

// Kẹp số nguyên vào [lo, hi]; nếu hi < lo thì trả về lo (không báo lỗi)
int clampInt(int v, int lo, int hi) {
  if (hi < lo) return lo;
  return v < lo ? lo : (v > hi ? hi : v);
}