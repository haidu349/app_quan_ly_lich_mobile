import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/models/event_label.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/utils/format.dart';
import 'package:quan_ly_lich/widgets/label_dialog.dart';

class AddEventScreen extends StatefulWidget {
  final Event? event; // null = thêm mới, có giá trị = đang sửa
  final DateTime? initialDate; // ngày chọn sẵn khi thêm mới

  const AddEventScreen({super.key, this.event, this.initialDate});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _organizerController;
  late final TextEditingController _locationController;
  late final TextEditingController _noteController;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  int? _labelId;

  bool get _isEditing => widget.event != null;

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
  bool get _timeInvalid => _minutes(_endTime) <= _minutes(_startTime);

  String _fmtTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _nameController = TextEditingController(text: e?.name ?? '');
    _organizerController = TextEditingController(text: e?.organizer ?? '');
    _locationController = TextEditingController(text: e?.location ?? '');
    _noteController = TextEditingController(text: e?.note ?? '');

    if (e != null) {
      _date = DateTime(e.start.year, e.start.month, e.start.day);
      _startTime = TimeOfDay.fromDateTime(e.start);
      _endTime = TimeOfDay.fromDateTime(e.end);
      _labelId = e.labelId;
    } else {
      final now = DateTime.now();
      final labels = context.read<AppData>().labels;
      _date = widget.initialDate ?? DateTime(now.year, now.month, now.day);
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _endTime = const TimeOfDay(hour: 9, minute: 0);
      _labelId = labels.isNotEmpty ? labels.first.id : null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _organizerController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addLabel() async {
    final data = context.read<AppData>();
    final result = await showDialog<EventLabel>(
      context: context,
      builder: (_) => const LabelDialog(),
    );
    if (result == null) return;

    final newId = await data.addLabel(result);
    if (!mounted) return;
    setState(() => _labelId = newId); // chọn luôn nhãn vừa tạo
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
        // Nếu giờ kết thúc không còn sau giờ bắt đầu thì tự dời +1 tiếng
        if (_minutes(_endTime) <= _minutes(_startTime)) {
          final newEnd = _minutes(_startTime) + 60;
          final capped = newEnd > 23 * 60 + 59 ? 23 * 60 + 59 : newEnd;
          _endTime = TimeOfDay(hour: capped ~/ 60, minute: capped % 60);
        }
      } else {
        _endTime = picked;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate() || _timeInvalid) return;

    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _endTime.hour,
      _endTime.minute,
    );

    final event = Event(
      id: widget.event?.id, // giữ nguyên id khi sửa
      name: _nameController.text.trim(),
      start: start,
      end: end,
      labelId: _labelId,
      organizer: _organizerController.text.trim(),
      location: _locationController.text.trim(),
      note: _noteController.text.trim(),
    );
    Navigator.pop(context, event);
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<AppData>().labels;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Sửa sự kiện' : 'Thêm sự kiện')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên sự kiện',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tên sự kiện'
                  : null,
            ),
            const SizedBox(height: 16),

            // Chọn nhãn
            Text('Nhãn', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Không nhãn'),
                  showCheckmark: false,
                  selected: _labelId == null,
                  onSelected: (_) => setState(() => _labelId = null),
                ),
                for (final l in labels)
                  ChoiceChip(
                    avatar: CircleAvatar(
                      backgroundColor: l.colorValue,
                      radius: 6,
                    ),
                    label: Text(l.name),
                    showCheckmark: false,
                    selectedColor: l.colorValue.withValues(alpha: 0.25),
                    selected: _labelId == l.id,
                    onSelected: (_) => setState(() => _labelId = l.id),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Nhãn mới'),
                  onPressed: _addLabel,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ngày
            _PickerField(
              label: 'Ngày',
              value: formatDate(_date),
              icon: Icons.calendar_today,
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            // Giờ bắt đầu - kết thúc
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: 'Bắt đầu',
                    value: _fmtTime(_startTime),
                    icon: Icons.access_time,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerField(
                    label: 'Kết thúc',
                    value: _fmtTime(_endTime),
                    icon: Icons.access_time_filled,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            if (_timeInvalid)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Giờ kết thúc phải sau giờ bắt đầu',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Địa điểm (không bắt buộc)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _organizerController,
              decoration: const InputDecoration(
                labelText: 'Người tổ chức (không bắt buộc)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (không bắt buộc)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Cập nhật' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}

// Ô bấm để chọn ngày/giờ, trông giống ô nhập liệu
class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: Text(value),
      ),
    );
  }
}
