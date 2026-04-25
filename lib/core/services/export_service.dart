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
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: ['No', 'Tanggal Panen', 'Nama Lahan', 'Berat (Kg)', 'Tandan', 'Rata-rata/Tandan', 'Waktu Upload', 'Terakhir Diedit'],
              data: List.generate(harvests.length, (i) {
                final h = harvests[i];
                return [
                  '${i + 1}',
                  DateFormat('dd MMM yyyy').format(h.harvestDate),
                  landNameMap[h.landId] ?? h.landName ?? h.landId,
                  '${h.weightKg}',
                  h.bunchCount > 0 ? '${h.bunchCount}' : '-',
                  h.bunchCount > 0 ? '${h.avgWeightPerBunch.toStringAsFixed(2)}' : '-',
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
                  'Total: ${harvests.fold(0.0, (sum, h) => sum + h.weightKg).toStringAsFixed(1)} Kg  |  ${harvests.fold(0, (sum, h) => sum + h.bunchCount)} Tandan',
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
      TextCellValue('Jumlah Tandan'),
      TextCellValue('Rata-rata/Tandan (Kg)'),
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
        IntCellValue(h.bunchCount),
        DoubleCellValue(h.bunchCount > 0 ? h.avgWeightPerBunch : 0),
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

  // ===============================================
  // EXPORT LAPORAN KEUANGAN & MARGIN (PER LAHAN)
  // ===============================================
  static Future<void> exportFinanceToPDF(
    BuildContext context,
    LandModel land,
    LandFinanceModel finance,
    List<HarvestModel> harvests,
  ) async {
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    double totalTonnage = harvests.fold(0.0, (sum, h) => sum + h.weightKg);
    double pestMonthly = finance.pesticideYearlyCost / 12;
    double prunMonthly = finance.pruningYearlyCost / 12;
    double totalMonthlyCost = finance.fertilizerCost + finance.workerCost + pestMonthly + prunMonthly;
    double grossRevenue = totalTonnage * finance.pricePerKg; 
    double margin = grossRevenue - totalMonthlyCost; 

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Laporan Keuangan & Margin Laba Lahan',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Lahan: ${land.name} (${land.sizeHectares} Ha)'),
              pw.Text('Periode: Bulan ${finance.periodMonth} / Tahun ${finance.periodYear}'),
              pw.Text('Dicetak: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}', 
                style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(),
              pw.SizedBox(height: 8),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Text('A. Ringkasan Pengeluaran & Pemasukan', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              cellAlignment: pw.Alignment.centerLeft,
              data: [
                ['Pendapatan Kotor (Tonase x Harga/kg)', fmt.format(grossRevenue)],
                ['Biaya Pupuk (Bulan Ini)', '- ${fmt.format(finance.fertilizerCost)}'],
                ['Biaya Pekerja (Bulan Ini)', '- ${fmt.format(finance.workerCost)}'],
                ['Biaya Pestisida (Tahunan dibagi 12)', '- ${fmt.format(pestMonthly)}'],
                ['Biaya Pruning (Tahunan dibagi 12)', '- ${fmt.format(prunMonthly)}'],
                ['TOTAL PENGELUARAN', '- ${fmt.format(totalMonthlyCost)}'],
                ['MARGIN LABA BERSIH', fmt.format(margin)],
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Text('B. Rincian Histori Panen Bulan Ini', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            if (harvests.isEmpty) 
               pw.Text('Tidak ada rekaman panen pada bulan ini.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic))
            else
               pw.TableHelper.fromTextArray(
                 headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                 cellStyle: const pw.TextStyle(fontSize: 10),
                 headers: ['No', 'Tanggal Panen', 'Berat (Kg)', 'Estimasi Nilai (berdasarkan harga rata-rata)'],
                 data: List.generate(harvests.length, (i) {
                   final h = harvests[i];
                   return [
                     '${i + 1}',
                     DateFormat('dd MMM yyyy').format(h.harvestDate),
                     '${h.weightKg} Kg',
                     fmt.format(h.weightKg * finance.pricePerKg),
                   ];
                 }),
               ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Keuangan_${land.name}_${finance.periodMonth}_${finance.periodYear}',
    );
  }

  static Future<void> exportFinanceToExcel(
    LandModel land,
    LandFinanceModel finance,
    List<HarvestModel> harvests,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Laporan Margin & Panen'];
    
    // Header Info
    sheet.appendRow([TextCellValue('Laporan Keuangan & Margin Laba Lahan')]);
    sheet.appendRow([TextCellValue('Lahan:'), TextCellValue('${land.name} (${land.sizeHectares} Ha)')]);
    sheet.appendRow([TextCellValue('Periode:'), TextCellValue('Bulan ${finance.periodMonth} / Tahun ${finance.periodYear}')]);
    
    sheet.appendRow([]); // Empty
    
    // Keuangan
    double totalTonnage = harvests.fold(0.0, (sum, h) => sum + h.weightKg);
    double pestMonthly = finance.pesticideYearlyCost / 12;
    double prunMonthly = finance.pruningYearlyCost / 12;
    double totalMonthlyCost = finance.fertilizerCost + finance.workerCost + pestMonthly + prunMonthly;
    double grossRevenue = totalTonnage * finance.pricePerKg; 
    double margin = grossRevenue - totalMonthlyCost; 

    sheet.appendRow([TextCellValue('Pemasukan Kotor'), DoubleCellValue(grossRevenue)]);
    sheet.appendRow([TextCellValue('Biaya Pupuk'), DoubleCellValue(finance.fertilizerCost)]);
    sheet.appendRow([TextCellValue('Biaya Pekerja'), DoubleCellValue(finance.workerCost)]);
    sheet.appendRow([TextCellValue('Biaya Pestisida (Pembagian Bulanan)'), DoubleCellValue(pestMonthly)]);
    sheet.appendRow([TextCellValue('Biaya Pruning (Pembagian Bulanan)'), DoubleCellValue(prunMonthly)]);
    sheet.appendRow([TextCellValue('Total Pengeluaran'), DoubleCellValue(totalMonthlyCost)]);
    sheet.appendRow([TextCellValue('Margin Laba Bersih'), DoubleCellValue(margin)]);

    sheet.appendRow([]); // Empty
    sheet.appendRow([TextCellValue('Rincian Panen Bulan Ini')]);
    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Tanggal Panen'),
      TextCellValue('Berat (Kg)'),
      TextCellValue('Estimasi Nilai')
    ]);

    for (int i = 0; i < harvests.length; i++) {
      final h = harvests[i];
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(DateFormat('yyyy-MM-dd').format(h.harvestDate)),
        DoubleCellValue(h.weightKg),
        DoubleCellValue(h.weightKg * finance.pricePerKg)
      ]);
    }

    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Gagal membuat file Excel');

    export_helper.downloadExcelBytes(fileBytes, 'Laporan_Keuangan_${land.name}_${finance.periodMonth}_${finance.periodYear}.xlsx');
  }
}
