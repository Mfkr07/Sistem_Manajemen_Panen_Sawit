import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

// Conditional import for web download
import 'export_helper_stub.dart'
    if (dart.library.html) 'export_helper_web.dart' as export_helper;

class ExportService {
  /// Export to PDF using the printing package (works on web + mobile + desktop)
  static Future<void> exportToPDF(
    BuildContext context,
    List<HarvestModel> harvests,
    String timeRange,
    Map<String, String> landNameMap,
  ) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Laporan Rekapitulasi Panen Sawit',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Periode: $timeRange', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Dicetak: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}', 
                style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(),
              pw.SizedBox(height: 8),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: ['No', 'Tanggal Panen', 'Nama Lahan', 'Berat (Kg)', 'Waktu Upload', 'Terakhir Diedit'],
              data: List.generate(harvests.length, (i) {
                final h = harvests[i];
                return [
                  '${i + 1}',
                  DateFormat('dd MMM yyyy').format(h.harvestDate),
                  landNameMap[h.landId] ?? h.landName ?? h.landId,
                  '${h.weightKg}',
                  DateFormat('dd MMM yyyy HH:mm').format(h.createdAt),
                  DateFormat('dd MMM yyyy HH:mm').format(h.updatedAt),
                ];
              }),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Berat: ${harvests.fold(0.0, (sum, h) => sum + h.weightKg).toStringAsFixed(1)} Kg',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ];
        },
      ),
    );

    // Use the printing package to preview/download (works everywhere including web)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rekapitulasi_Panen_$timeRange',
    );
  }

  /// Export to Excel — generates bytes, then downloads via platform-specific helper
  static Future<void> exportToExcel(
    List<HarvestModel> harvests,
    String timeRange,
    Map<String, String> landNameMap,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Rekapitulasi Panen'];

    // Header
    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Tanggal Panen'),
      TextCellValue('Nama Lahan'),
      TextCellValue('Berat Panen (Kg)'),
      TextCellValue('Waktu Upload'),
      TextCellValue('Terakhir Diedit'),
    ]);

    // Data rows
    for (int i = 0; i < harvests.length; i++) {
      final h = harvests[i];
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(DateFormat('yyyy-MM-dd').format(h.harvestDate)),
        TextCellValue(landNameMap[h.landId] ?? h.landName ?? h.landId),
        DoubleCellValue(h.weightKg),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(h.createdAt)),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(h.updatedAt)),
      ]);
    }

    // Remove default Sheet1 if exists
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Gagal membuat file Excel');

    export_helper.downloadExcelBytes(fileBytes, 'Rekapitulasi_Panen_$timeRange.xlsx');
  }
}
