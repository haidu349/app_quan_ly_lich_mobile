import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedExcel {
  final String name;
  final Uint8List bytes;

  const PickedExcel(this.name, this.bytes);
}

// Mở trình chọn file .xlsx. Trả về null nếu người dùng đóng không chọn.
Future<PickedExcel?> pickExcelFile() async {
  // Dành cho file_picker bản 12 trở lên
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return PickedExcel(file.name, bytes);
}
