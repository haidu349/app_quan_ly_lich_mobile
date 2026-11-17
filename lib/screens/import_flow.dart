import 'package:flutter/material.dart';
import 'package:quan_ly_lich/screens/import_preview_screen.dart';
import 'package:quan_ly_lich/services/excel_reader.dart';
import 'package:quan_ly_lich/services/file_pick_service.dart';
import 'package:quan_ly_lich/services/import_parser.dart';

// Hướng dẫn định dạng -> chọn file -> đọc file -> màn hình xem trước
Future<void> startExcelImport(BuildContext context) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (_) => const _FormatDialog(),
  );
  if (proceed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  PickedExcel? picked;
  try {
    picked = await pickExcelFile();
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Không mở được trình chọn file: $e')),
    );
    return;
  }
  if (picked == null) return;
  final file = picked;

  List<ExcelSheetData> sheets;
  try {
    sheets = readExcelSheets(file.bytes);
  } catch (e, st) {
    debugPrint('Lỗi đọc Excel: $e\n$st');
    if (!context.mounted) return;
    await _showMessage(
      context,
      'Không đọc được file',
      'File "${file.name}" (${file.bytes.length} byte).\n\n'
          'Chi tiết lỗi: $e\n\n'
          'Nếu là file .xls cũ, hãy mở bằng Excel rồi lưu lại thành .xlsx.',
    );
    return;
  }

  // Lấy sheet đầu tiên có dòng tiêu đề hợp lệ
  List<List<Object?>>? raw;
  for (final s in sheets) {
    if (hasImportHeader(s.rows)) {
      raw = s.rows;
      break;
    }
  }
  if (raw == null) {
    if (!context.mounted) return;
    await _showMessage(
      context,
      'Không tìm thấy dòng tiêu đề',
      'Cần có dòng tiêu đề chứa ít nhất hai cột: "Tên sự kiện" và "Ngày tổ chức".',
    );
    return;
  }
  final rows = raw;

  final count = await navigator.push<int>(
    MaterialPageRoute(
      builder: (_) => ImportPreviewScreen(fileName: file.name, rawRows: rows),
    ),
  );
  if (count != null) {
    messenger.showSnackBar(SnackBar(content: Text('Đã nhập $count sự kiện')));
  }
}

Future<void> _showMessage(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}

class _FormatDialog extends StatelessWidget {
  const _FormatDialog();

  @override
  Widget build(BuildContext context) {
    final bold = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return AlertDialog(
      icon: const Icon(Icons.upload_file),
      title: const Text('Nhập từ file Excel'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File .xlsx, dòng đầu là tiêu đề các cột.'),
            const SizedBox(height: 12),
            Text('Bắt buộc', style: bold),
            const Text('• Tên sự kiện\n• Ngày tổ chức (ví dụ 30/11/2026)'),
            const SizedBox(height: 12),
            Text('Không bắt buộc', style: bold),
            const Text(
              '• Giờ bắt đầu, Giờ kết thúc (ví dụ 8:30)\n'
              '• Tên người tổ chức\n'
              '• Địa điểm\n'
              '• Nhãn\n'
              '• Ghi chú\n'
              '• STT (bỏ qua)',
            ),
            const SizedBox(height: 12),
            const Text(
              'Không có cột giờ thì dùng giờ mặc định 08:00 - 09:00, đổi được ở '
              'bước xem trước. Chưa có gì được lưu cho tới khi bạn bấm Nhập.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Chọn file Excel'),
        ),
      ],
    );
  }
}
