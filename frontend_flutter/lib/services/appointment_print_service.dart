import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AppointmentPrintService {
  static Future<void> printDailyAppointments({
    required DateTime selectedDate,
    required String doctorName,
    required List<Map<String, dynamic>> appointments,
  }) async {
    final doc = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final dateStr =
        '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
    final now = DateTime.now();
    final printedAtStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Sort by turn number or start time
    final sortedList = List<Map<String, dynamic>>.from(appointments);
    sortedList.sort((a, b) {
      final turnA = a['turn_number'] is int ? a['turn_number'] as int : 0;
      final turnB = b['turn_number'] is int ? b['turn_number'] as int : 0;
      return turnA.compareTo(turnB);
    });

    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontOblique = pw.Font.helveticaOblique();

    const primaryColor = PdfColor.fromInt(0xFF0F4C81);
    const secondaryColor = PdfColor.fromInt(0xFF00A896);
    const darkTextColor = PdfColor.fromInt(0xFF0B2545);
    const lightGrey = PdfColor.fromInt(0xFFF1F5F9);
    const borderGrey = PdfColor.fromInt(0xFFCBD5E1);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, width: 44, height: 44),
                        pw.SizedBox(width: 10),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Salud Now',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 22,
                              color: primaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'LISTA DE CITAS DEL DÍA',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 11,
                              color: secondaryColor,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Fecha: $dateStr',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 13,
                          color: darkTextColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Emitido: $printedAtStr',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderGrey, width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Profesional / Especialista: $doctorName',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 11,
                        color: darkTextColor,
                      ),
                    ),
                    pw.Text(
                      'Total Pacientes: ${sortedList.length}',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 11,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderGrey, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Salud Now · Documento de Control y Asistencia Clínica · Confidencial',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          if (sortedList.isEmpty) {
            return [
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(32),
                child: pw.Text(
                  'No hay citas registradas para este día.',
                  style: pw.TextStyle(
                    font: fontOblique,
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ];
          }

          return [
            pw.Table(
              border: pw.TableBorder.all(
                color: borderGrey,
                width: 0.6,
              ),
              columnWidths: const {
                0: pw.FixedColumnWidth(42),  // Turno
                1: pw.FixedColumnWidth(55),  // Hora
                2: pw.FlexColumnWidth(3.2),  // Paciente
                3: pw.FlexColumnWidth(2.0),  // Teléfono
                4: pw.FlexColumnWidth(3.0),  // Motivo
                5: pw.FlexColumnWidth(1.6),  // Estado
                6: pw.FlexColumnWidth(2.2),  // Notas / Firma
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: primaryColor,
                  ),
                  children: [
                    _buildHeaderCell('Turno', fontBold),
                    _buildHeaderCell('Hora', fontBold),
                    _buildHeaderCell('Paciente', fontBold),
                    _buildHeaderCell('Teléfono', fontBold),
                    _buildHeaderCell('Motivo / Consulta', fontBold),
                    _buildHeaderCell('Estado', fontBold),
                    _buildHeaderCell('Asistencia / Firma', fontBold),
                  ],
                ),
                // Data rows
                ...sortedList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;

                  final isEven = idx % 2 == 0;
                  final rowBg = isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF8FAFC);

                  final turn = item['turn_number']?.toString() ?? '-';
                  final time = item['time_block']?.toString() ?? '-';
                  
                  final patientName = (item['patient_name'] ?? item['doctor_name'] ?? 'Paciente').toString();
                  final cedula = item['patient_cedula']?.toString() ?? '';
                  final patientDisplay = cedula.isNotEmpty ? '$patientName\n(C.I. $cedula)' : patientName;

                  final phone = (item['patient_phone']?.toString().isNotEmpty == true)
                      ? item['patient_phone'].toString()
                      : '-';

                  final reason = (item['appointment_reason'] ?? item['reason'] ?? 'Consulta Médica').toString();
                  
                  final rawStatus = (item['status'] ?? 'scheduled').toString().toLowerCase();
                  String statusStr = 'PROGRAMADA';
                  if (rawStatus == 'completed') statusStr = 'ATENDIDA';
                  if (rawStatus == 'cancelled') statusStr = 'CANCELADA';

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowBg),
                    children: [
                      _buildDataCell('#$turn', fontBold, align: pw.TextAlign.center),
                      _buildDataCell(time, fontRegular, align: pw.TextAlign.center),
                      _buildDataCell(patientDisplay, fontBold),
                      _buildDataCell(phone, fontRegular),
                      _buildDataCell(reason, fontRegular),
                      _buildDataCell(statusStr, fontBold, align: pw.TextAlign.center),
                      _buildDataCell('', fontRegular), // Empty space for signature or checked
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Citas_${doctorName.replaceAll(" ", "_")}_$dateStr.pdf',
    );
  }

  static pw.Widget _buildHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: 8.5,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildDataCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 8.5,
          color: const PdfColor.fromInt(0xFF1E293B),
        ),
      ),
    );
  }
}
