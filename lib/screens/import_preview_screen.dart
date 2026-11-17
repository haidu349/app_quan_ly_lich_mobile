import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/models/event_label.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/services/import_parser.dart';
import 'package:quan_ly_lich/utils/format.dart';
import 'package:quan_ly_lich/utils/palette.dart';
import 'package:quan_ly_lich/widgets/free_slot_sheet.dart';

enum _Filter { all, conflict, error }

const Color _orange = Color(0xFFE65100);

String _hm(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:${(minuteOfDay % 60).toString().padLeft(2, '0')}';

Widget _h24(BuildContext context, Widget? child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
  child: child!,
);

class ImportPreviewScreen extends StatefulWidget {
  final String fileName;
  final List<List<Object?>> rawRows;

  const ImportPreviewScreen({
    super.key,
    required this.fileName,
    required this.rawRows,
  });

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  int _defaultStart = 8 * 60;
  int _defaultEnd = 9 * 60;
  List<ImportRow> _rows = [];
  Set<int> _skipped = {}; // chỉ số các dòng bị bỏ chọn
  Set<int> _duplicates = {}; // chỉ số các dòng đã có sẵn trong lịch
  _Filter _filter = _Filter.all;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  // Đọc file theo giờ mặc định hiện tại; dòng đã có trong lịch thì tự bỏ chọn
  void _parse() {
    final existing = context.read<AppData>().events;
    final result = parseImportRows(
      widget.rawRows,
      defaultStartMinute: _defaultStart,
      defaultEndMinute: _defaultEnd,
    );

    final seen = <String>{};
    final dups = <int>{};
    for (var i = 0; i < result.rows.length; i++) {
      final r = result.rows[i];
      if (!r.isValid) continue;
      final key =
          '${normalizeText(r.name)}|${r.start!.millisecondsSinceEpoch}|${r.end!.millisecondsSinceEpoch}';
      final repeatedInFile = !seen.add(key);
      if (repeatedInFile || isDuplicateOfExisting(r, existing)) dups.add(i);
    }

    _rows = List<ImportRow>.of(result.rows);
    _duplicates = dups;
    _skipped = {...dups};
  }

  Future<void> _changeDefaultTime() async {
    final start = await showTimePicker(
      context: context,
      helpText: 'GIỜ BẮT ĐẦU MẶC ĐỊNH',
      initialTime: TimeOfDay(
        hour: _defaultStart ~/ 60,
        minute: _defaultStart % 60,
      ),
      builder: _h24,
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: 'GIỜ KẾT THÚC MẶC ĐỊNH',
      initialTime: TimeOfDay(hour: _defaultEnd ~/ 60, minute: _defaultEnd % 60),
      builder: _h24,
    );
    if (end == null || !mounted) return;

    final s = start.hour * 60 + start.minute;
    final e = end.hour * 60 + end.minute;
    if (e <= s) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giờ kết thúc phải sau giờ bắt đầu')),
      );
      return;
    }
    setState(() {
      _defaultStart = s;
      _defaultEnd = e;
      _parse(); // nạp lại danh sách theo giờ mặc định mới
    });
  }

  // Dời một dòng sang khoảng trống do người dùng chọn
  Future<void> _move(int index) async {
    final row = _rows[index];
    final others = <Event>[
      for (var j = 0; j < _rows.length; j++)
        if (j != index && _rows[j].isValid && !_skipped.contains(j))
          _rows[j].toEvent(),
    ];
    final slot = await showFreeSlotSheet(
      context,
      initialDay: row.start!,
      durationMinutes: row.durationMinutes,
      extraEvents: others,
    );
    if (slot == null || !mounted) return;
    setState(() {
      _rows[index] = row.copyWith(
        start: slot.start,
        end: slot.start.add(Duration(minutes: row.durationMinutes)),
        usedDefaultTime: false,
        moved: true,
      );
      _duplicates.remove(index);
    });
  }

  Future<void> _import(
    List<int> indices,
    Map<String, EventLabel> byName,
  ) async {
    final data = context.read<AppData>();
    setState(() => _saving = true);
    try {
      // Nhãn có sẵn: tra theo tên. Nhãn chưa có: tạo mới với màu lần lượt trong bảng màu.
      final idByKey = <String, int>{
        for (final e in byName.entries) e.key: e.value.id!,
      };
      for (final i in indices) {
        final labelName = _rows[i].labelName;
        if (labelName.isEmpty) continue;
        final key = normalizeText(labelName);
        if (idByKey.containsKey(key)) continue;
        final color = labelPalette[data.labels.length % labelPalette.length];
        idByKey[key] = await data.addLabel(
          EventLabel(name: labelName, color: color.toARGB32()),
        );
      }

      final events = <Event>[
        for (final i in indices)
          _rows[i].toEvent(
            labelId: _rows[i].labelName.isEmpty
                ? null
                : idByKey[normalizeText(_rows[i].labelName)],
          ),
      ];
      await data.addEvents(events);
      if (!mounted) return;
      Navigator.pop(context, events.length);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không nhập được: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final existing = data.events;
    final byName = <String, EventLabel>{
      for (final l in data.labels) normalizeText(l.name): l,
    };

    // Phân tích từng dòng: trùng với ai, có được nhập không
    final conflicts = <int, List<Event>>{};
    final importable = <int>[];
    for (var i = 0; i < _rows.length; i++) {
      if (!_rows[i].isValid || _skipped.contains(i)) continue;
      importable.add(i);
      final c = conflictsForRow(i, _rows, _skipped, existing);
      if (c.isNotEmpty) conflicts[i] = c;
    }
    final errorCount = _rows.where((r) => !r.isValid).length;
    final defaultTimeCount = _rows
        .where((r) => r.isValid && r.usedDefaultTime)
        .length;

    final visible = <int>[
      for (var i = 0; i < _rows.length; i++)
        if (switch (_filter) {
          _Filter.all => true,
          _Filter.conflict => conflicts.containsKey(i),
          _Filter.error => !_rows[i].isValid,
        })
          i,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Xem trước khi nhập')),
      body: _rows.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'File không có dòng dữ liệu nào bên dưới dòng tiêu đề.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                // Tóm tắt
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${widget.fileName}\n'
                      '${_rows.length} dòng • ${importable.length} sẽ nhập • '
                      '${conflicts.length} trùng lịch • $errorCount lỗi',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey[700]),
                    ),
                  ),
                ),

                // Giờ mặc định cho các dòng không có giờ
                if (defaultTimeCount > 0)
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text('$defaultTimeCount dòng không có giờ'),
                      subtitle: Text(
                        'Dùng giờ mặc định ${_hm(_defaultStart)} - ${_hm(_defaultEnd)}. '
                        'Đổi giờ sẽ nạp lại danh sách.',
                      ),
                      trailing: TextButton(
                        onPressed: _changeDefaultTime,
                        child: const Text('Đổi'),
                      ),
                    ),
                  ),

                // Bộ lọc
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _chip(
                        'Tất cả (${_rows.length})',
                        _filter == _Filter.all,
                        () => setState(() => _filter = _Filter.all),
                      ),
                      _chip(
                        'Trùng lịch (${conflicts.length})',
                        _filter == _Filter.conflict,
                        () => setState(() => _filter = _Filter.conflict),
                      ),
                      _chip(
                        'Lỗi ($errorCount)',
                        _filter == _Filter.error,
                        () => setState(() => _filter = _Filter.error),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text(
                            'Không có dòng nào trong mục này',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: visible.length,
                          itemBuilder: (context, k) {
                            final i = visible[k];
                            final row = _rows[i];
                            final key = normalizeText(row.labelName);
                            final label = row.labelName.isEmpty
                                ? null
                                : byName[key];
                            return _RowCard(
                              key: ValueKey('row_$i'),
                              row: row,
                              label: label,
                              labelIsNew:
                                  row.labelName.isNotEmpty && label == null,
                              included: !_skipped.contains(i),
                              duplicate: _duplicates.contains(i),
                              conflicts: conflicts[i] ?? const [],
                              onIncludedChanged: (v) => setState(() {
                                if (v) {
                                  _skipped.remove(i);
                                } else {
                                  _skipped.add(i);
                                }
                              }),
                              onMove: () => _move(i),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (conflicts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${conflicts.length} dòng đang trùng lịch. Bạn có thể dời, bỏ chọn, hoặc vẫn nhập.',
                    style: const TextStyle(color: _orange, fontSize: 12),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (importable.isEmpty || _saving)
                      ? null
                      : () => _import(importable, byName),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_done),
                  label: Text('Nhập ${importable.length} sự kiện'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

// Thẻ một dòng của file
class _RowCard extends StatelessWidget {
  final ImportRow row;
  final EventLabel? label;
  final bool labelIsNew;
  final bool included;
  final bool duplicate;
  final List<Event> conflicts;
  final ValueChanged<bool> onIncludedChanged;
  final VoidCallback onMove;

  const _RowCard({
    super.key,
    required this.row,
    required this.label,
    required this.labelIsNew,
    required this.included,
    required this.duplicate,
    required this.conflicts,
    required this.onIncludedChanged,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final data = context.read<AppData>();
    final isError = !row.isValid;
    final hasConflict = conflicts.isNotEmpty;

    final Color? borderColor = isError
        ? scheme.error
        : (hasConflict ? _orange : null);

    final details = [
      if (row.location.isNotEmpty) row.location,
      if (row.organizer.isNotEmpty) row.organizer,
    ].join(' • ');

    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor ?? Colors.transparent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ô chọn (dòng lỗi không chọn được)
            SizedBox(
              width: 44,
              child: isError
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Icon(Icons.error_outline, color: scheme.error),
                    )
                  : Checkbox(
                      value: included,
                      onChanged: (v) => onIncludedChanged(v ?? false),
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Dòng ${row.rowNumber}',
                        style: textTheme.labelMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                      if (duplicate)
                        _MiniBadge('Đã có trong lịch', Colors.grey.shade700),
                      if (row.moved) _MiniBadge('Đã dời', scheme.primary),
                      if (row.isValid && row.usedDefaultTime)
                        _MiniBadge('Giờ mặc định', Colors.grey.shade700),
                      if (row.labelName.isNotEmpty)
                        _LabelPill(
                          name: row.labelName,
                          color: label?.colorValue ?? Colors.grey,
                          isNew: labelIsNew,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    row.name.isEmpty ? '(chưa có tên)' : row.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (row.isValid) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${formatDate(row.start!)}  •  ${formatTimeRange(row.start!, row.end!)}',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                  if (details.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        details,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ),

                  // Lý do lỗi
                  if (isError)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        row.error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),

                  // Các sự kiện đang bị trùng + nút dời
                  if (hasConflict)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: _orange,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Trùng với ${conflicts.length} sự kiện',
                                  style: const TextStyle(
                                    color: _orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (final e in conflicts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: CircleAvatar(
                                      radius: 4,
                                      backgroundColor:
                                          data.labelOf(e)?.colorValue ??
                                          Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${e.name}${e.id == null ? ' (trong file)' : ''}\n'
                                      '${formatDate(e.start)} • ${formatTimeRange(e.start, e.end)}',
                                      style: textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: onMove,
                              icon: const Icon(
                                Icons.lightbulb_outline,
                                size: 18,
                              ),
                              label: const Text('Dời lịch'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Dòng bị bỏ chọn thì mờ đi
    return (!included && row.isValid)
        ? Opacity(opacity: 0.55, child: card)
        : card;
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniBadge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Nhãn của dòng; nhãn chưa có trong app có thêm chữ "mới"
class _LabelPill extends StatelessWidget {
  final String name;
  final Color color;
  final bool isNew;

  const _LabelPill({
    required this.name,
    required this.color,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 6),
          Text(
            isNew ? '$name (nhãn mới)' : name,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
