import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'schedule.dart';

class TextPiece {
  const TextPiece(this.text, this.left, this.top, this.right, this.height);
  final String text;
  final double left, top, right, height;
}

/// Reconstruct rows by geometry rather than PDF/OCR block order (often columns).
String textRows(List<TextPiece> pieces) {
  final sorted =
      pieces.where((p) => p.text.trim().isNotEmpty && p.height > 0).toList()
        ..sort((a, b) => a.top.compareTo(b.top));
  final rows = <List<TextPiece>>[];
  for (final piece in sorted) {
    final center = piece.top + piece.height / 2;
    if (rows.isEmpty ||
        (center - (rows.last.first.top + rows.last.first.height / 2)).abs() >
            math.min(piece.height, rows.last.first.height) * 0.5) {
      rows.add([piece]);
    } else {
      rows.last.add(piece);
    }
  }
  return rows
      .map((row) {
        row.sort((a, b) => a.left.compareTo(b.left));
        final buffer = StringBuffer();
        for (final piece in row) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(piece.text);
        }
        return buffer.toString();
      })
      .join('\n');
}

Future<String> extractPdfPageText(PdfPage page) async {
  final raw = await page.loadText();
  // PDFium preserves the original table rows and punctuation in these PDFs.
  return raw?.fullText ?? '';
}

Future<ScheduleData> importSchedule(
  Uint8List bytes,
  String name, {
  void Function(String)? onProgress,
}) async {
  if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
    throw const FormatException('El archivo debe ocupar entre 1 byte y 20 MB.');
  }
  if (name.toLowerCase().endsWith('.csv')) {
    return parseScheduleCsv(utf8.decode(bytes), source: name);
  }
  if (!name.toLowerCase().endsWith('.pdf') ||
      !ascii
          .decode(bytes.take(5).toList(), allowInvalid: true)
          .startsWith('%PDF-')) {
    throw const FormatException(
      'Selecciona un PDF de Plan Horario o un CSV generado por el OCR.',
    );
  }
  final catalog = Map<String, String>.from(
    jsonDecode(await rootBundle.loadString('OCR_horario/data/materias.json'))
        as Map,
  );
  await pdfrxFlutterInitialize();
  final document = await PdfDocument.openData(bytes, sourceName: name);
  final pages = <String>[];
  var usedOcr = false;
  TextRecognizer? recognizer;
  Directory? temporary;
  try {
    if (document.pages.length > 10) {
      throw const FormatException('El horario no puede superar 10 páginas.');
    }
    for (final page in document.pages) {
      onProgress?.call(
        'Leyendo página ${page.pageNumber} de ${document.pages.length}',
      );
      var text = await extractPdfPageText(page);
      if (text.trim().length < 100) {
        if (!Platform.isIOS && !Platform.isAndroid) {
          throw const FormatException(
            'El OCR de PDF escaneado requiere iPhone o Android.',
          );
        }
        usedOcr = true;
        onProgress?.call('Reconociendo página ${page.pageNumber}');
        recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
        temporary ??= await (await getTemporaryDirectory()).createTemp(
          'unimet-horario-',
        );
        final scale = math.min(3.0, 3000 / math.max(page.width, page.height));
        final rendered = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
          backgroundColor: 0xFFFFFFFF,
        );
        if (rendered == null) {
          throw const FormatException('No se pudo leer una página del PDF.');
        }
        try {
          final image = await rendered.createImage();
          try {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            if (png == null) {
              throw const FormatException(
                'No se pudo preparar la imagen del horario.',
              );
            }
            final file = File('${temporary.path}/page.png');
            await file.writeAsBytes(png.buffer.asUint8List());
            final result = await recognizer.processImage(
              InputImage.fromFilePath(file.path),
            );
            text = textRows([
              for (final block in result.blocks)
                for (final line in block.lines)
                  for (final element in line.elements)
                    TextPiece(
                      element.text,
                      element.boundingBox.left,
                      line.boundingBox.top,
                      element.boundingBox.right,
                      line.boundingBox.height,
                    ),
            ]);
          } finally {
            image.dispose();
          }
        } finally {
          rendered.dispose();
        }
      }
      pages.add(text);
    }
    return parseScheduleText(
      pages.join('\n'),
      source: name,
      catalog: catalog,
      usedOcr: usedOcr,
    );
  } finally {
    await recognizer?.close();
    await document.dispose();
    if (temporary != null && await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  }
}
