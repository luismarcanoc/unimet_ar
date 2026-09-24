import 'dart:convert';
import 'package:csv/csv.dart';

const scheduleDays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
  'Evento Virtual',
];

String searchKey(String value) {
  var result = value.toUpperCase();
  const accents = {
    'Á': 'A',
    'É': 'E',
    'Í': 'I',
    'Ó': 'O',
    'Ú': 'U',
    'Ü': 'U',
    'Ñ': 'N',
  };
  accents.forEach((from, to) => result = result.replaceAll(from, to));
  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String roomKey(String name) {
  final clean = searchKey(name).replaceAll(RegExp(r'[‐‑–—]'), '-');
  final code = RegExp(r'^(A\d+|SL)\s*-?\s*([0-9O]{3})$').firstMatch(clean);
  return code == null ? clean : '${code[1]}-${code[2]!.replaceAll('O', '0')}';
}

class ScheduleClass {
  const ScheduleClass({
    required this.days,
    required this.time,
    required this.room,
    required this.subject,
    required this.section,
    required this.professor,
    this.code = '',
    this.period = '',
  });
  final List<String> days;
  final String time, room, subject, section, professor, code, period;
  bool get isVirtual =>
      searchKey(room) == 'VIRTUAL' || days.contains('Evento Virtual');
  Map<String, dynamic> toJson() => {
    'days': days,
    'time': time,
    'room': room,
    'subject': subject,
    'section': section,
    'professor': professor,
    'code': code,
    'period': period,
  };
  factory ScheduleClass.fromJson(Map<String, dynamic> value) => ScheduleClass(
    days: List<String>.from(value['days'] as List),
    time: value['time'] as String,
    room: value['room'] as String,
    subject: value['subject'] as String,
    section: value['section'] as String,
    professor: value['professor'] as String,
    code: value['code'] as String? ?? '',
    period: value['period'] as String? ?? '',
  );
}

class ScheduleData {
  const ScheduleData({
    required this.classes,
    required this.source,
    this.usedOcr = false,
  });
  final List<ScheduleClass> classes;
  final String source;
  final bool usedOcr;
  String get period => classes
      .map((c) => c.period)
      .where((p) => p.isNotEmpty)
      .toSet()
      .join(', ');
  String encode() => jsonEncode({
    'source': source,
    'usedOcr': usedOcr,
    'classes': classes.map((c) => c.toJson()).toList(),
  });
  factory ScheduleData.decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ScheduleData(
      source: json['source'] as String,
      usedOcr: json['usedOcr'] as bool? ?? false,
      classes: (json['classes'] as List)
          .map(
            (e) => ScheduleClass.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
  String toCsv() => const ListToCsvConverter().convert([
    [
      'DIAS',
      'HORA',
      'AULA',
      'MATERIA(ASIGNATURA)',
      'SECCION',
      'PROFESOR',
      'CODIGO',
      'PERIODO',
    ],
    ...classes.map(
      (c) => [
        c.days.join(' / '),
        c.time,
        c.room,
        c.subject,
        c.section,
        c.professor,
        c.code,
        c.period,
      ],
    ),
  ]);
}

bool isUnimetSchedule(String text) {
  final key = searchKey(text);
  return [
    'PLAN HORARIO',
    'PERIODO',
    'ASIGNATURA',
    'PROFESOR',
  ].every(key.contains);
}

String _time(String raw) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*-\s*(\d{1,2}):(\d{2})(?::\d{2})?$',
  ).firstMatch(raw.trim());
  if (match == null) {
    throw const FormatException('Hora no reconocida en el horario.');
  }
  final a = int.parse(match[1]!) * 60 + int.parse(match[2]!);
  final b = int.parse(match[3]!) * 60 + int.parse(match[4]!);
  if (int.parse(match[1]!) > 23 ||
      int.parse(match[3]!) > 23 ||
      int.parse(match[2]!) > 59 ||
      int.parse(match[4]!) > 59 ||
      a >= b) {
    throw const FormatException('El horario contiene una hora inválida.');
  }
  return '${match[1]!.padLeft(2, '0')}:${match[2]}-${match[3]!.padLeft(2, '0')}:${match[4]}';
}

List<String> _days(String value) {
  final values = value.split(RegExp(r'\s*[/,]\s*|\s+y\s+'));
  return values
      .map(
        (v) => scheduleDays.firstWhere(
          (d) => searchKey(d) == searchKey(v),
          orElse: () =>
              throw const FormatException('Día no reconocido en el horario.'),
        ),
      )
      .toList();
}

List<ScheduleClass> consolidateClasses(List<ScheduleClass> classes) {
  final result = <String, ScheduleClass>{};
  for (final c in classes) {
    final key = jsonEncode([
      c.time,
      roomKey(c.room),
      c.code,
      c.subject,
      c.section,
      c.professor,
      c.period,
    ]);
    final days = {...?result[key]?.days, ...c.days}.toList()
      ..sort(
        (a, b) => scheduleDays.indexOf(a).compareTo(scheduleDays.indexOf(b)),
      );
    result[key] = ScheduleClass(
      days: days,
      time: c.time,
      room: c.room,
      subject: c.subject,
      section: c.section,
      professor: c.professor,
      code: c.code,
      period: c.period,
    );
  }
  return result.values.toList()..sort((a, b) {
    final day = scheduleDays
        .indexOf(a.days.first)
        .compareTo(scheduleDays.indexOf(b.days.first));
    return day == 0 ? a.time.compareTo(b.time) : day;
  });
}

ScheduleData parseScheduleText(
  String text, {
  required String source,
  required Map<String, String> catalog,
  bool usedOcr = false,
}) {
  if (!isUnimetSchedule(text)) {
    throw const FormatException('Este archivo no es un Plan Horario UNIMET.');
  }
  final periods = RegExp(
    r'PER[IÍ]ODO\s*:\s*(\d{4})\s*-\s*(\d{3})',
    caseSensitive: false,
  ).allMatches(text).map((m) => '${m[1]}-${m[2]}').toSet();
  if (periods.length > 1) {
    throw const FormatException(
      'El PDF mezcla varios períodos. Selecciona un horario individual.',
    );
  }
  final period = periods.isEmpty ? '' : periods.single;
  final row = RegExp(
    r'^(Lunes|Martes|Mi[eé]rcoles|Jueves|Viernes|S[aá]bado|Domingo)\s+(\d{1,2}:\d{2}(?::\d{2})?\s*-\s*\d{1,2}:\d{2}(?::\d{2})?)\s+(.+)$',
    caseSensitive: false,
  );
  final classes = <ScheduleClass>[];
  for (final raw in text.split('\n')) {
    final line = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = row.firstMatch(line);
    final virtual = RegExp(
      r'^Evento\s+Virtual\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null && virtual == null) {
      if (RegExp(
        r'^(Lunes|Martes|Mi[eé]rcoles|Jueves|Viernes|S[aá]bado|Domingo)\b',
        caseSensitive: false,
      ).hasMatch(line)) {
        throw const FormatException(
          'No se pudo leer una fila completa. Usa el PDF original o el CSV del OCR.',
        );
      }
      continue;
    }
    final body = match?[3] ?? virtual![1]!;
    final sections = RegExp(
      r'\b([A-Z]{3,}\d{2})\s*-\s*(\d+)\b',
      caseSensitive: false,
    ).allMatches(body).toList();
    if (sections.isEmpty) {
      throw const FormatException(
        'No se pudo leer el código y la sección de una clase.',
      );
    }
    final section = sections.last;
    final code = section[1]!.toUpperCase();
    final prefix = body.substring(0, section.start);
    final codes = RegExp(
      '\\b$code\\b',
      caseSensitive: false,
    ).allMatches(prefix).toList();
    if (codes.isEmpty) {
      throw const FormatException(
        'Los códigos de materia y sección no coinciden.',
      );
    }
    final printed = prefix.substring(codes.last.end).trim();
    final location = prefix.substring(0, codes.last.start).trim();
    final roomMatch = RegExp(
      r'^(?:A\d+|SL)\s*-\s*[A-Z0-9]{3}\b',
      caseSensitive: false,
    ).firstMatch(location);
    var professor = body.substring(section.end).trim();
    if (professor.contains(',')) {
      final comma = professor.indexOf(',');
      professor =
          '${professor.substring(comma + 1).trim()} ${professor.substring(0, comma).trim()}'
              .trim();
    }
    final name = catalog[code] ?? printed;
    if (name.isEmpty || professor.isEmpty) {
      throw const FormatException(
        'Una clase tiene campos incompletos. Revisa el PDF.',
      );
    }
    classes.add(
      ScheduleClass(
        days: match == null ? ['Evento Virtual'] : _days(match[1]!),
        time: match == null ? '' : _time(match[2]!),
        room: match == null
            ? 'Virtual'
            : roomMatch == null
            ? ''
            : roomKey(roomMatch[0]!),
        subject: name,
        section: section[2]!,
        professor: professor,
        code: code,
        period: period,
      ),
    );
  }
  if (classes.isEmpty) {
    throw const FormatException(
      'No se encontraron clases legibles en el horario.',
    );
  }
  final expectedRows = RegExp(
    r'\b[A-Z]{3,}\d{2}\s*-\s*\d+\b',
    caseSensitive: false,
  ).allMatches(text).length;
  if (expectedRows != classes.length) {
    throw const FormatException(
      'Hay filas que no se pudieron leer completas. Usa el PDF original o el CSV individual del OCR.',
    );
  }
  return ScheduleData(
    classes: consolidateClasses(classes),
    source: source,
    usedOcr: usedOcr,
  );
}

ScheduleData parseScheduleCsv(String text, {required String source}) {
  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
      .convert(
        text
            .replaceAll('\uFEFF', '')
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n'),
      )
      .where((r) => r.any((v) => v.toString().trim().isNotEmpty))
      .toList();
  if (rows.length < 2) {
    throw const FormatException('El CSV de horario está vacío.');
  }
  final headers = rows.first.map((v) => searchKey(v.toString())).toList();
  const required = [
    'DIAS',
    'HORA',
    'AULA',
    'MATERIA(ASIGNATURA)',
    'SECCION',
    'PROFESOR',
  ];
  if (!required.every(headers.contains)) {
    throw const FormatException(
      'Selecciona el CSV de horario, no el CSV de coordenadas.',
    );
  }
  String cell(List<dynamic> row, String name) {
    final index = headers.indexOf(name);
    return index < 0 || index >= row.length ? '' : row[index].toString().trim();
  }

  final periods = <String>{};
  final files = <String>{};
  final classes = <ScheduleClass>[];
  for (final row in rows.skip(1)) {
    final days = _days(cell(row, 'DIAS'));
    final subject = cell(row, 'MATERIA(ASIGNATURA)');
    final section = cell(row, 'SECCION');
    if (subject.isEmpty || !RegExp(r'^\d+$').hasMatch(section)) {
      throw const FormatException('Materia o sección inválida.');
    }
    final period = cell(row, 'PERIODO');
    final file = cell(row, 'ARCHIVO');
    if (period.isNotEmpty) periods.add(period);
    if (file.isNotEmpty) files.add(file);
    classes.add(
      ScheduleClass(
        days: days,
        time: days.contains('Evento Virtual') ? '' : _time(cell(row, 'HORA')),
        room: roomKey(cell(row, 'AULA')),
        subject: subject,
        section: section,
        professor: cell(row, 'PROFESOR'),
        code: cell(row, 'CODIGO'),
        period: period,
      ),
    );
  }
  if (periods.length > 1 || files.length > 1) {
    throw const FormatException(
      'Este CSV mezcla varios horarios. Selecciona un archivo individual.',
    );
  }
  return ScheduleData(classes: consolidateClasses(classes), source: source);
}
