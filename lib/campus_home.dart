import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart' show InterestPoint, ArGuideScreen;
import 'salon_csv.dart';
import 'schedule.dart';
import 'schedule_import.dart';
import 'floor_markers.dart';
import 'floor_scanner.dart';

List<InterestPoint> matchingRooms(String name, List<InterestPoint> rooms) =>
    rooms
        .where((r) => roomKey(r.name) == roomKey(name) && r.isImported)
        .toList();

class CampusHome extends StatefulWidget {
  const CampusHome({super.key, required this.cameras});
  final List<CameraDescription> cameras;
  @override
  State<CampusHome> createState() => _CampusHomeState();
}

class _CampusHomeState extends State<CampusHome> {
  final _preferences = SharedPreferencesAsync();
  final _search = TextEditingController();
  List<InterestPoint> _rooms = [];
  ScheduleData? _schedule;
  int _tab = 0;
  bool _loading = true, _busy = false;
  String _query = '', _progress = '';
  String? _day;
  FloorMarker? _floor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _preferences.getString('campus_schedule_v1');
      if (raw != null) _schedule = ScheduleData.decode(raw);
    } catch (_) {
      _message(
        'No se pudo recuperar el horario guardado. Vuelve a importarlo.',
      );
    }
    try {
      final rooms =
          await _preferences.getStringList('imported_salons_v1') ?? [];
      _rooms = rooms
          .map(
            (r) =>
                InterestPoint.fromJson(jsonDecode(r) as Map<String, dynamic>),
          )
          .where(
            (r) =>
                r.isImported &&
                r.latitude.isFinite &&
                r.longitude.isFinite &&
                r.latitude.abs() <= 90 &&
                r.longitude.abs() <= 180,
          )
          .toList();
    } catch (_) {
      _message(
        'No se pudieron recuperar todos los datos guardados. Vuelve a importar el archivo.',
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _importSchedule() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = 'Seleccionando horario';
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'csv'],
        withData: true,
        allowMultiple: false,
      );
      if (picked == null || !mounted) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException(
          'No se pudo abrir el archivo. Descárgalo en Archivos e intenta de nuevo.',
        );
      }
      final result = await importSchedule(
        bytes,
        file.name,
        onProgress: (text) {
          if (mounted) setState(() => _progress = text);
        },
      );
      if (!mounted) return;
      final accepted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ScheduleReview(data: result, rooms: _rooms),
        ),
      );
      if (accepted != true) return;
      await _preferences.setString('campus_schedule_v1', result.encode());
      if (mounted) {
        setState(() {
          _schedule = result;
          _day = null;
        });
      }
      _message('Horario guardado.');
    } on FormatException catch (e) {
      _message(e.message);
    } catch (_) {
      _message(
        'No se pudo procesar el horario. Prueba el PDF original o el CSV individual del OCR.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importRooms() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = 'Cargando coordenadas';
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (picked == null || !mounted) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null || bytes.length > 5 * 1024 * 1024) {
        throw const FormatException('No se puede abrir el CSV o supera 5 MB.');
      }
      final result = parseSalonCsv(utf8.decode(bytes).replaceAll('\uFEFF', ''));
      final unique = <String, InterestPoint>{};
      for (final r in result.records) {
        if (unique.containsKey(r.id)) {
          throw const FormatException(
            'El CSV tiene identificadores duplicados. Revisa el registro.',
          );
        }
        unique[r.id] = InterestPoint(
          id: 'csv:${r.id}',
          name: r.name,
          latitude: r.latitude,
          longitude: r.longitude,
          accuracy: r.accuracy,
          createdAt: DateTime.now(),
          floor: r.floor,
          reference: r.reference,
          altitude: r.altitude,
          altitudeAccuracy: r.altitudeAccuracy,
          isImported: true,
        );
      }
      final rooms = unique.values.toList()
        ..sort((a, b) => roomKey(a.name).compareTo(roomKey(b.name)));
      if (!mounted ||
          !await _confirm(
            'Actualizar salones',
            '${rooms.length} registros del archivo seleccionado. ${result.skippedRows} filas omitidas. Sustituirá el catálogo del teléfono.',
          )) {
        return;
      }
      await _preferences.setStringList(
        'imported_salons_v1',
        rooms.map((r) => jsonEncode(r.toJson())).toList(),
      );
      if (mounted) setState(() => _rooms = rooms);
      _message('Coordenadas actualizadas.');
    } on SalonCsvFormatException catch (e) {
      _message(e.message);
    } on FormatException catch (e) {
      _message(e.message);
    } catch (_) {
      _message('No se pudo importar el registro de salones.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _navigate(InterestPoint room) async {
    if (_busy || !room.isImported) return;
    setState(() {
      _busy = true;
      _progress = 'Obteniendo ubicación';
    });
    try {
      if (_floor != null && !_floor!.matchesRoom(room.name, room.floor)) {
        if (!await _confirm(
          'Destino en otro piso o edificio',
          'Piso identificado: ${_floor!.label}. Destino: ${room.name}, piso ${room.floor}. La guía GPS no identifica escaleras ni cambios de piso.',
        )) {
          return;
        }
      }
      if (!mounted) return;
      if (!await Geolocator.isLocationServiceEnabled()) {
        _message('Activa la ubicación del teléfono.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted &&
            await _confirm(
              'Permiso de ubicación bloqueado',
              'Abre los ajustes para permitir ubicación precisa.',
            )) {
          await Geolocator.openAppSettings();
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        _message('Se necesita permiso de ubicación.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArGuideScreen(
            cameras: widget.cameras,
            initialPosition: position,
            destination: room,
          ),
        ),
      );
    } catch (_) {
      _message(
        'No se pudo iniciar la guía. Revisa la ubicación y vuelve a intentar.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _classDestination(ScheduleClass c) async {
    final matches = matchingRooms(c.room, _rooms);
    if (matches.length == 1) {
      await _navigate(matches.single);
      return;
    }
    if (matches.isEmpty) {
      _message('No hay coordenadas registradas para ${c.room}.');
      return;
    }
    final room = await showModalBottomSheet<InterestPoint>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Selecciona el registro correcto')),
            ...matches.map(
              (r) => ListTile(
                title: Text(r.name),
                subtitle: Text('Piso ${r.floor} · ${r.reference}'),
                onTap: () => Navigator.pop(context, r),
              ),
            ),
          ],
        ),
      ),
    );
    if (room != null && mounted) await _navigate(room);
  }

  Future<void> _scanFloor() async {
    final marker = await Navigator.of(context).push<FloorMarker>(
      MaterialPageRoute(builder: (_) => const FloorScannerScreen()),
    );
    if (marker != null && mounted) {
      setState(() {
        _floor = marker;
        _tab = 1;
        _query = '';
        _search.clear();
      });
    }
  }

  Future<void> _export() async {
    final data = _schedule;
    if (data == null) return;
    try {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar horario',
        fileName: 'horario_unimet.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: utf8.encode('\uFEFF${data.toCsv()}'),
      );
    } catch (_) {
      _message('No se pudo exportar el horario.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_tab == 0 ? 'Mi horario' : 'Salones UNIMET'),
      actions: [
        IconButton(
          tooltip: 'Identificar piso con QR',
          onPressed: _busy ? null : _scanFloor,
          icon: const Icon(Icons.qr_code_scanner),
        ),
        if (_tab == 0 && _schedule != null)
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (value) async {
              if (value == 'export') {
                await _export();
                return;
              }
              if (await _confirm(
                'Quitar horario',
                'Se quitará el horario guardado; los salones se conservan.',
              )) {
                await _preferences.remove('campus_schedule_v1');
                if (mounted) setState(() => _schedule = null);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Exportar CSV')),
              PopupMenuItem(value: 'delete', child: Text('Quitar horario')),
            ],
          ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_progress),
                ),
              if (_floor != null)
                Material(
                  color: const Color(0xFFE1F2E9),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.layers_outlined),
                    title: Text('Piso identificado: ${_floor!.label}'),
                    trailing: IconButton(
                      tooltip: 'Quitar piso identificado',
                      onPressed: () => setState(() => _floor = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              Expanded(child: _tab == 0 ? _scheduleView() : _roomView()),
            ],
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (index) => setState(() => _tab = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          label: 'Horario',
        ),
        NavigationDestination(
          icon: Icon(Icons.school_outlined),
          label: 'Salones',
        ),
      ],
    ),
  );

  Widget _scheduleView() {
    if (_schedule == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Image.asset(
            'OCR_horario/assets/welcome-illustration.png',
            height: 180,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'Horario de clases',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _importSchedule,
            icon: const Icon(Icons.upload_file),
            label: const Text('Cargar horario'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _tab = 1),
            icon: const Icon(Icons.search),
            label: const Text('Buscar salón'),
          ),
        ],
      );
    }
    final data = _schedule!;
    final classes = data.classes
        .where((c) => _day == null || c.days.contains(_day))
        .toList();
    if (_day != null) {
      classes.sort((a, b) => a.time.compareTo(b.time));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data.period.isEmpty ? data.source : 'Trimestre ${data.period}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Reemplazar horario',
              onPressed: _busy ? null : _importSchedule,
              icon: const Icon(Icons.upload_file),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('${data.source}:${_day ?? 'Todos'}'),
          initialValue: _day ?? 'Todos',
          decoration: const InputDecoration(labelText: 'Día'),
          items: [
            'Todos',
            ...scheduleDays,
          ].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (d) => setState(() => _day = d == 'Todos' ? null : d),
        ),
        const SizedBox(height: 16),
        if (_rooms.isEmpty)
          ListTile(
            leading: const Icon(Icons.location_off_outlined),
            title: const Text('Sin coordenadas de salones'),
            trailing: IconButton(
              tooltip: 'Cargar coordenadas',
              onPressed: _busy ? null : _importRooms,
              icon: const Icon(Icons.file_upload_outlined),
            ),
          ),
        if (classes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No hay clases este día.'),
          ),
        ...classes.map(
          (c) => ScheduleClassTile(
            item: c,
            matches: matchingRooms(c.room, _rooms).length,
            onNavigate: _busy ? null : () => _classDestination(c),
          ),
        ),
      ],
    );
  }

  Widget _roomView() {
    final filtered = _rooms
        .where(
          (r) =>
              (_floor == null || _floor!.matchesRoom(r.name, r.floor)) &&
              searchKey(
                '${r.name} ${r.floor} ${r.reference}',
              ).contains(searchKey(_query)),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_rooms.length} salones registrados',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Importar coordenadas CSV',
              onPressed: _busy ? null : _importRooms,
              icon: const Icon(Icons.upload_file),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (text) => setState(() => _query = text),
          decoration: const InputDecoration(
            labelText: 'Buscar salón',
            hintText: 'A1-202',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        if (_rooms.isEmpty)
          FilledButton.icon(
            onPressed: _busy ? null : _importRooms,
            icon: const Icon(Icons.upload_file),
            label: const Text('Cargar coordenadas reales'),
          ),
        if (_rooms.isNotEmpty && filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No hay salones con esos filtros.'),
          ),
        ...filtered.map(
          (room) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Piso ${room.floor}${room.reference.isEmpty ? '' : ' · ${room.reference}'}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    room.accuracy > 0
                        ? 'Precisión registrada: ±${room.accuracy.toStringAsFixed(0)} m'
                        : 'Precisión registrada desconocida',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _navigate(room),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Ir al salón'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ScheduleClassTile extends StatelessWidget {
  const ScheduleClassTile({
    super.key,
    required this.item,
    required this.matches,
    this.onNavigate,
  });
  final ScheduleClass item;
  final int matches;
  final VoidCallback? onNavigate;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: Color(0xFFDEE5ED)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.subject,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _field(
                Icons.calendar_today_outlined,
                'Días',
                item.days.join(' / '),
              ),
              _field(
                Icons.schedule,
                'Hora',
                item.time.isEmpty ? 'Sin hora fija' : item.time,
              ),
              _field(
                Icons.meeting_room_outlined,
                'Aula',
                item.room.isEmpty ? 'Por confirmar' : item.room,
              ),
              _field(Icons.groups_outlined, 'Sección', item.section),
            ],
          ),
          const SizedBox(height: 12),
          Text('Profesor: ${item.professor}'),
          if (item.code.isNotEmpty)
            Text(item.code, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          if (item.isVirtual)
            const Text(
              'Clase virtual',
              style: TextStyle(color: Color(0xFF287354)),
            )
          else if (matches == 0)
            const Text(
              'Sin coordenadas registradas',
              style: TextStyle(color: Color(0xFF975815)),
            )
          else
            FilledButton.tonalIcon(
              onPressed: onNavigate,
              icon: const Icon(Icons.navigation_outlined),
              label: Text(
                matches == 1
                    ? 'Ir a ${item.room}'
                    : 'Elegir registro de ${item.room}',
              ),
            ),
        ],
      ),
    ),
  );
  Widget _field(IconData icon, String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF1769E8)),
      const SizedBox(width: 7),
      Flexible(child: Text('$label: $value')),
    ],
  );
}

class ScheduleReview extends StatelessWidget {
  const ScheduleReview({super.key, required this.data, required this.rooms});
  final ScheduleData data;
  final List<InterestPoint> rooms;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Revisar horario')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${data.classes.length} clases · ${data.source}'),
        if (data.usedOcr)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Reconocido desde una imagen. Confirma las aulas y horas con el documento original.',
            ),
          ),
        const SizedBox(height: 12),
        ...data.classes.map(
          (c) => ScheduleClassTile(
            item: c,
            matches: matchingRooms(c.room, rooms).length,
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check),
          label: const Text('Confirmar horario'),
        ),
      ),
    ),
  );
}
