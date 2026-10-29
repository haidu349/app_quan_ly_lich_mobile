class Event {
  final int? id;
  final String name;
  final DateTime date;
  final String organizer;

  const Event({
    this.id,
    required this.name,
    required this.date,
    required this.organizer,
  });

  // Event -> dữ liệu để lưu vào bảng
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date.millisecondsSinceEpoch,
      'organizer': organizer,
    };
  }

  // Dữ liệu đọc từ bảng -> Event
  factory Event.fromMap(Map<String, Object?> map) {
    return Event(
      id: map['id'] as int?,
      name: map['name'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      organizer: map['organizer'] as String,
    );
  }
}
