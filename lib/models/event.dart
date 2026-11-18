class Event {
  final int? id;
  final String name;
  final DateTime start;
  final DateTime end;
  final int? labelId; // null = không nhãn
  final String organizer;
  final String location;
  final String note;

  const Event({
    this.id,
    required this.name,
    required this.start,
    required this.end,
    this.labelId,
    this.organizer = '',
    this.location = '',
    this.note = '',
  });

  // Bản sao với một số trường mới (các trường khác giữ nguyên)
  Event copyWith({int? id, String? name, DateTime? start, DateTime? end}) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      labelId: labelId,
      organizer: organizer,
      location: location,
      note: note,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'start_time': start.millisecondsSinceEpoch,
      'end_time': end.millisecondsSinceEpoch,
      'label_id': labelId,
      'organizer': organizer,
      'location': location,
      'note': note,
    };
  }

  factory Event.fromMap(Map<String, Object?> map) {
    return Event(
      id: map['id'] as int?,
      name: map['name'] as String,
      start: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      end: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      labelId: map['label_id'] as int?,
      organizer: (map['organizer'] as String?) ?? '',
      location: (map['location'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
    );
  }
}
