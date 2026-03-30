import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Mobile/Desktop implementation — saves file to temp directory and opens share dialog
void downloadExcelBytes(List<int> bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);

  // Use the printing package's share functionality
  await Printing.sharePdf(
    bytes: Uint8List.fromList(bytes),
    filename: fileName,
  );
}
