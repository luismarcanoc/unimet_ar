import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _blue = Color(0xFF1769E8);
const _navy = Color(0xFF081B49);
const _muted = Color(0xFF607195);
const _background = Color(0xFFF3F7FF);
const _savedPointsKey = 'saved_interest_points_v1';
const _selectedPointKey = 'selected_interest_point_v1';
const _onboardingKey = 'onboarding_seen_v1';
const _duplicateRadiusMeters = 2.0;
const _arrivalRadiusMeters = 2.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = [];
  }
  runApp(UnimetArApp(cameras: cameras));
}

class UnimetArApp extends StatelessWidget {
  const UnimetArApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNIMET AR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _blue),
        scaffoldBackgroundColor: _background,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(cameras: cameras),
    );
  }
}

class InterestPoint {
  const InterestPoint({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory InterestPoint.fromJson(Map<String, dynamic> json) {
    return InterestPoint(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  List<InterestPoint> _points = [];
  String? _selectedPointId;
  bool _loading = true;
  bool _working = false;

  InterestPoint? get _selectedPoint {
    for (final point in _points) {
      if (point.id == _selectedPointId) return point;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOnboardingIfNeeded();
    });
  }

  Future<void> _loadSavedState() async {
    final rawPoints =
        await _preferences.getStringList(_savedPointsKey) ?? <String>[];
    final selectedPointId = await _preferences.getString(_selectedPointKey);
    final points = <InterestPoint>[];
    for (final rawPoint in rawPoints) {
      try {
        points.add(
          InterestPoint.fromJson(
            jsonDecode(rawPoint) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Ignore malformed local records instead of blocking the app.
      }
    }
    if (!mounted) return;
    setState(() {
      _points = points;
      _selectedPointId = points.any((point) => point.id == selectedPointId)
          ? selectedPointId
          : null;
      _loading = false;
    });
  }

  Future<void> _showOnboardingIfNeeded() async {
    final alreadySeen = await _preferences.getBool(_onboardingKey) ?? false;
    if (!alreadySeen && mounted) await _showOnboarding();
  }

  Future<void> _showOnboarding() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.explore_rounded, color: _blue, size: 42),
        title: const Text(
          'Prueba tu primera guía',
          textAlign: TextAlign.center,
          style: TextStyle(color: _navy, fontWeight: FontWeight.w900),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingStep(
              number: '1',
              text:
                  'Crea tu primer punto de interés en cualquier lugar de tu alrededor. Puedes probar la app con un solo punto.',
            ),
            SizedBox(height: 18),
            OnboardingStep(
              number: '2',
              text:
                  'Aléjate lo suficiente del punto, selecciónalo como destino y abre la guía para que la flecha te lleve de vuelta.',
            ),
            SizedBox(height: 16),
            Text(
              'Activa la ubicación precisa y evita estar junto a objetos metálicos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13, height: 1.35),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    await _preferences.setBool(_onboardingKey, true);
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return false;
      await _showLocationProblem(
        title: 'Activa la ubicación',
        message:
            'El teléfono necesita la ubicación encendida para marcar y seguir puntos.',
        actionLabel: 'Abrir ajustes',
        onAction: Geolocator.openLocationSettings,
      );
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      await _showLocationProblem(
        title: 'Permiso bloqueado',
        message:
            'Permite la ubicación precisa para UNIMET AR desde los ajustes del teléfono.',
        actionLabel: 'Abrir ajustes',
        onAction: Geolocator.openAppSettings,
      );
      return false;
    }
    if (permission == LocationPermission.denied) {
      _showMessage('No se concedió el permiso de ubicación.');
      return false;
    }
    return true;
  }

  Future<void> _showLocationProblem({
    required String title,
    required String message,
    required String actionLabel,
    required Future<bool> Function() onAction,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(onAction());
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<String?> _askPointName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo punto de interés'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Nombre del punto',
            hintText: 'Ej. Puerta de la sala',
            prefixIcon: Icon(Icons.place_outlined),
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) Navigator.of(dialogContext).pop(trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) Navigator.of(dialogContext).pop(trimmed);
            },
            child: const Text('Marcar aquí'),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
  }

  Future<void> _markPoint() async {
    final name = await _askPointName();
    if (name == null || !mounted) return;
    if (_points
        .any((point) => point.name.toLowerCase() == name.toLowerCase())) {
      _showMessage('Ya existe un punto con ese nombre.');
      return;
    }
    if (!await _ensureLocationPermission() || !mounted) return;
    setState(() => _working = true);
    try {
      final position = await _currentHighAccuracyPosition();
      InterestPoint? duplicate;
      double? duplicateDistance;
      for (final point in _points) {
        final distance = coordinateDistanceMeters(
          position.latitude,
          position.longitude,
          point.latitude,
          point.longitude,
        );
        if (distance <= _duplicateRadiusMeters) {
          duplicate = point;
          duplicateDistance = distance;
          break;
        }
      }
      if (duplicate != null) {
        _showMessage(
          'Ya existe “${duplicate.name}” a ${duplicateDistance!.toStringAsFixed(1)} m.',
        );
        return;
      }
      final point = InterestPoint(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        createdAt: DateTime.now(),
      );
      setState(() {
        _points = [..._points, point];
        _selectedPointId = point.id;
      });
      await _savePoints();
      final warning = position.accuracy > 10
          ? ' Precisión baja (${position.accuracy.toStringAsFixed(0)} m); intenta de nuevo cerca de una ventana.'
          : '';
      _showMessage('Punto guardado y seleccionado.$warning');
    } on TimeoutException {
      _showMessage(
          'La ubicación tardó demasiado. Inténtalo cerca de una ventana.');
    } catch (_) {
      _showMessage(
          'No se pudo obtener una ubicación precisa. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<Position> _currentHighAccuracyPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 25),
      ),
    );
  }

  Future<void> _savePoints() async {
    await _preferences.setStringList(
      _savedPointsKey,
      _points.map((point) => jsonEncode(point.toJson())).toList(),
    );
    if (_selectedPointId == null) {
      await _preferences.remove(_selectedPointKey);
    } else {
      await _preferences.setString(_selectedPointKey, _selectedPointId!);
    }
  }

  Future<void> _selectPoint(InterestPoint point) async {
    setState(() => _selectedPointId = point.id);
    await _preferences.setString(_selectedPointKey, point.id);
  }

  Future<void> _deletePoint(InterestPoint point) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Borrar punto'),
            content: Text('¿Quieres borrar “${point.name}”?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Borrar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() {
      _points = _points.where((item) => item.id != point.id).toList();
      if (_selectedPointId == point.id) _selectedPointId = null;
    });
    await _savePoints();
  }

  Future<void> _openGuide() async {
    final destination = _selectedPoint;
    if (destination == null) {
      _showMessage('Selecciona un punto de destino.');
      return;
    }
    if (!await _ensureLocationPermission() || !mounted) return;
    setState(() => _working = true);
    try {
      final position = await _currentHighAccuracyPosition();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArGuideScreen(
            cameras: widget.cameras,
            initialPosition: position,
            destination: destination,
          ),
        ),
      );
    } on TimeoutException {
      _showMessage('La ubicación tardó demasiado. Inténtalo de nuevo.');
    } catch (_) {
      _showMessage('No fue posible iniciar el seguimiento.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openArKitTrial() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ArKitQrTestScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: HomeHeader(onHelp: _showOnboarding),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    sliver: SliverToBoxAdapter(
                      child: MarkPointPanel(busy: _working, onMark: _markPoint),
                    ),
                  ),
                  if (Platform.isIOS)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      sliver: SliverToBoxAdapter(
                        child: ArKitTrialPanel(onOpen: _openArKitTrial),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Puntos guardados',
                              style: TextStyle(
                                color: _navy,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            '${_points.length}',
                            style: const TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_points.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(child: EmptyPointsState()),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.separated(
                        itemCount: _points.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final point = _points[index];
                          return PointTile(
                            point: point,
                            selected: point.id == _selectedPointId,
                            onSelect: () => _selectPoint(point),
                            onDelete: () => _deletePoint(point),
                          );
                        },
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _selectedPoint == null || _working ? null : _openGuide,
          icon: _working
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.view_in_ar_rounded),
          label: Text(
            _selectedPoint == null
                ? 'Selecciona un destino'
                : 'Guiarme a ${_selectedPoint!.name}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class OnboardingStep extends StatelessWidget {
  const OnboardingStep({
    super.key,
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _navy, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.onHelp});

  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UNIMET AR',
                style: TextStyle(
                  color: _navy,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Marca un lugar y deja que el teléfono te guíe de vuelta.',
                style: TextStyle(color: _muted, fontSize: 15, height: 1.35),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Cómo usar la app',
          onPressed: onHelp,
          icon: const Icon(Icons.help_outline_rounded),
        ),
      ],
    );
  }
}

class MarkPointPanel extends StatelessWidget {
  const MarkPointPanel({
    super.key,
    required this.busy,
    required this.onMark,
  });

  final bool busy;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.09),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_location_alt_rounded, color: _blue),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marca tu ubicación actual',
                  style: TextStyle(color: _navy, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 3),
                Text(
                  'Se guardará como un destino.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: 'Marcar punto',
            onPressed: busy ? null : onMark,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class ArKitTrialPanel extends StatelessWidget {
  const ArKitTrialPanel({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF163875),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child:
                      Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Probar QR + ARKit',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ancla flechas 3D a un marcador físico.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyPointsState extends StatelessWidget {
  const EmptyPointsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC9DCFA)),
      ),
      child: const Column(
        children: [
          Icon(Icons.pin_drop_outlined, color: _blue, size: 42),
          SizedBox(height: 10),
          Text(
            'Todavía no hay puntos',
            style: TextStyle(color: _navy, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 5),
          Text(
            'Usa el botón + para guardar el primero.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }
}

class PointTile extends StatelessWidget {
  const PointTile({
    super.key,
    required this.point,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  final InterestPoint point;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE7F0FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? _blue : const Color(0xFFDCE5F3),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? _blue : _muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Precisión al marcar: ±${point.accuracy.toStringAsFixed(0)} m',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Borrar ${point.name}',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArKitQrTestScreen extends StatefulWidget {
  const ArKitQrTestScreen({super.key});

  @override
  State<ArKitQrTestScreen> createState() => _ArKitQrTestScreenState();
}

class _ArKitQrTestScreenState extends State<ArKitQrTestScreen> {
  MethodChannel? _channel;
  bool _markerDetected = false;
  bool _hasError = false;
  String _status = 'Iniciando ARKit...';
  String _trackingState = 'Preparando seguimiento';

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('unimet_ar/arkit_view_$viewId');
    channel.setMethodCallHandler(_handleNativeEvent);
    setState(() {
      _channel = channel;
      _status = 'Busca el marcador CASA-QR-001';
    });
  }

  Future<void> _handleNativeEvent(MethodCall call) async {
    if (!mounted) return;
    final arguments = Map<String, dynamic>.from(
      (call.arguments as Map?) ?? const <String, dynamic>{},
    );
    switch (call.method) {
      case 'arReady':
        setState(() {
          _hasError = false;
          _status = 'Busca el marcador CASA-QR-001';
        });
      case 'markerDetected':
        setState(() {
          _markerDetected = true;
          _hasError = false;
          _status = 'Marcador detectado. Sigue las flechas.';
        });
      case 'trackingState':
        final state = arguments['state'] as String? ?? 'limitado';
        setState(() => _trackingState = _trackingMessage(state));
      case 'error':
        setState(() {
          _hasError = true;
          _status =
              arguments['message'] as String? ?? 'ARKit no está disponible.';
        });
    }
  }

  String _trackingMessage(String state) {
    return switch (state) {
      'normal' => 'Seguimiento estable',
      'inicializando' => 'Inicializando el entorno',
      'movimiento_excesivo' => 'Mueve el iPhone más lentamente',
      'pocos_detalles' => 'Apunta hacia una zona con más detalles',
      'relocalizando' => 'Recuperando la ubicación',
      'no_disponible' => 'Seguimiento no disponible',
      _ => 'Seguimiento limitado',
    };
  }

  Future<void> _resetSession() async {
    setState(() {
      _markerDetected = false;
      _hasError = false;
      _status = 'Reiniciando ARKit...';
    });
    await _channel?.invokeMethod<void>('reset');
  }

  Future<void> _showInstructions() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Preparar el marcador'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Imprime CASA-QR-001 exactamente a 20 x 20 cm.'),
            SizedBox(height: 10),
            Text(
                '2. Pégalo plano y vertical, con su centro a 1,50 m del piso.'),
            SizedBox(height: 10),
            Text('3. Apunta la cámara al QR desde 1 o 2 metros.'),
            SizedBox(height: 10),
            Text(
                '4. Cuando aparezcan las flechas, camina hacia la derecha del QR.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _ArKitPlatformViewConnector(
              onCreated: _onPlatformViewCreated,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  _ArKitTopBar(
                    onBack: () => Navigator.of(context).pop(),
                    onHelp: _showInstructions,
                    onReset: _resetSession,
                  ),
                  const Spacer(),
                  if (!_markerDetected && !_hasError) const _QrScanReticle(),
                  const Spacer(),
                  _ArKitStatusPanel(
                    status: _status,
                    trackingState: _trackingState,
                    markerDetected: _markerDetected,
                    hasError: _hasError,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArKitPlatformViewConnector extends StatelessWidget {
  const _ArKitPlatformViewConnector({required this.onCreated});

  final PlatformViewCreatedCallback onCreated;

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: 'unimet_ar/arkit_view',
      layoutDirection: TextDirection.ltr,
      creationParams: const <String, dynamic>{
        'markerId': 'CASA-QR-001',
        'physicalWidth': 0.20,
        'markerCenterHeight': 1.50,
        'routeLength': 3.0,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: onCreated,
    );
  }
}

class _ArKitTopBar extends StatelessWidget {
  const _ArKitTopBar({
    required this.onBack,
    required this.onHelp,
    required this.onReset,
  });

  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xDD101419),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prueba QR + ARKit',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Marcador de 20 cm · ruta de 3 m',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Instrucciones',
            onPressed: onHelp,
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Reiniciar ARKit',
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _QrScanReticle extends StatelessWidget {
  const _QrScanReticle();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 230,
      child: CustomPaint(painter: _QrReticlePainter()),
    );
  }
}

class _QrReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const length = 44.0;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final corners = <Path>[
      Path()
        ..moveTo(0, length)
        ..lineTo(0, 0)
        ..lineTo(length, 0),
      Path()
        ..moveTo(size.width - length, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, length),
      Path()
        ..moveTo(size.width, size.height - length)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width - length, size.height),
      Path()
        ..moveTo(length, size.height)
        ..lineTo(0, size.height)
        ..lineTo(0, size.height - length),
    ];
    for (final corner in corners) {
      canvas.drawPath(corner, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArKitStatusPanel extends StatelessWidget {
  const _ArKitStatusPanel({
    required this.status,
    required this.trackingState,
    required this.markerDetected,
    required this.hasError,
  });

  final String status;
  final String trackingState;
  final bool markerDetected;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final color = hasError
        ? const Color(0xFFFFB4A9)
        : markerDetected
            ? const Color(0xFF82E6AC)
            : const Color(0xFF8DC1FF);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE6101419),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasError
                ? Icons.error_outline_rounded
                : markerDetected
                    ? Icons.check_circle_outline_rounded
                    : Icons.qr_code_scanner_rounded,
            color: color,
            size: 34,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trackingState,
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ArGuideScreen extends StatefulWidget {
  const ArGuideScreen({
    super.key,
    required this.cameras,
    required this.initialPosition,
    required this.destination,
  });

  final List<CameraDescription> cameras;
  final Position initialPosition;
  final InterestPoint destination;

  @override
  State<ArGuideScreen> createState() => _ArGuideScreenState();
}

class _ArGuideScreenState extends State<ArGuideScreen> {
  CameraController? _cameraController;
  Future<void>? _cameraReady;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  late Position _currentPosition;
  double? _headingDegrees;
  String? _sensorProblem;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
    _initializeCamera();
    _startLiveTracking();
  }

  void _initializeCamera() {
    if (widget.cameras.isEmpty) return;
    final backCameras = widget.cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    final camera =
        backCameras.isNotEmpty ? backCameras.first : widget.cameras.first;
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _cameraReady = _cameraController!.initialize();
  }

  void _startLiveTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        if (mounted) setState(() => _currentPosition = position);
      },
      onError: (_) {
        if (mounted) {
          setState(
              () => _sensorProblem = 'No se pudo actualizar la ubicación.');
        }
      },
    );

    final compassEvents = FlutterCompass.events;
    if (compassEvents == null) {
      _sensorProblem = 'Este dispositivo no ofrece datos de brújula.';
      return;
    }
    _compassSubscription = compassEvents.listen(
      (event) {
        final newHeading = event.heading;
        if (newHeading == null || !mounted) return;
        setState(() {
          if (_headingDegrees == null) {
            _headingDegrees = normalizeDegrees(newHeading);
          } else {
            final delta = shortestSignedAngle(newHeading - _headingDegrees!);
            _headingDegrees = normalizeDegrees(_headingDegrees! + delta * 0.22);
          }
          _sensorProblem = null;
        });
      },
      onError: (_) {
        if (mounted) {
          setState(() => _sensorProblem = 'No se pudo leer la brújula.');
        }
      },
    );
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    unawaited(_compassSubscription?.cancel());
    unawaited(_cameraController?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distance = coordinateDistanceMeters(
      _currentPosition.latitude,
      _currentPosition.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );
    final targetBearing = coordinateBearingDegrees(
      _currentPosition.latitude,
      _currentPosition.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );
    final relativeBearing = _headingDegrees == null
        ? 0.0
        : normalizeDegrees(targetBearing - _headingDegrees!);
    final arrived = distance <= _arrivalRadiusMeters;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraBackdrop(
            controller: _cameraController,
            cameraReady: _cameraReady,
          ),
          Container(color: Colors.black.withValues(alpha: 0.08)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  TopGuideBar(
                    destination: widget.destination,
                    distance: distance,
                  ),
                  const Spacer(),
                  if (_headingDegrees == null)
                    const SensorLoadingState()
                  else if (arrived)
                    const ArrivalMarker()
                  else
                    PerspectiveNavigationArrow(
                      relativeBearing: relativeBearing,
                    ),
                  const Spacer(),
                  NavigationPanel(
                    distance: distance,
                    relativeBearing: relativeBearing,
                    headingDegrees: _headingDegrees,
                    targetBearing: targetBearing,
                    horizontalAccuracy: _currentPosition.accuracy,
                    sensorProblem: _sensorProblem,
                    arrived: arrived,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CameraBackdrop extends StatelessWidget {
  const CameraBackdrop({
    super.key,
    required this.controller,
    required this.cameraReady,
  });

  final CameraController? controller;
  final Future<void>? cameraReady;

  @override
  Widget build(BuildContext context) {
    if (controller == null || cameraReady == null) {
      return const CameraFallback();
    }
    return FutureBuilder<void>(
      future: cameraReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CameraFallback(message: 'Inicializando cámara...');
        }
        if (snapshot.hasError || !controller!.value.isInitialized) {
          return const CameraFallback();
        }
        return CameraPreview(controller!);
      },
    );
  }
}

class CameraFallback extends StatelessWidget {
  const CameraFallback({
    super.key,
    this.message = 'Cámara no disponible en este dispositivo',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF071022),
      child: Center(
        child: Text(message, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}

class TopGuideBar extends StatelessWidget {
  const TopGuideBar({
    super.key,
    required this.destination,
    required this.distance,
  });

  final InterestPoint destination;
  final double distance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xDD101419),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  destination.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                Text(
                  '${formatDistance(distance)} al destino',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SensorLoadingState extends StatelessWidget {
  const SensorLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xCC101419),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Calibrando brújula...',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class PerspectiveNavigationArrow extends StatelessWidget {
  const PerspectiveNavigationArrow({
    super.key,
    required this.relativeBearing,
  });

  final double relativeBearing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: instructionFor(relativeBearing),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0018)
          ..rotateX(0.88),
        child: Transform.rotate(
          angle: relativeBearing * math.pi / 180,
          child: const CustomPaint(
            size: Size(230, 250),
            painter: NavigationArrowPainter(),
          ),
        ),
      ),
    );
  }
}

class NavigationArrowPainter extends CustomPainter {
  const NavigationArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.79),
        width: size.width * 0.78,
        height: 34,
      ),
      shadowPaint,
    );
    for (var index = 2; index >= 0; index--) {
      final scale = 0.72 + index * 0.12;
      final tipY = 18.0 + index * 61;
      final face = _chevronPath(size.width / 2, tipY, scale);
      final extrusion = face.shift(Offset(0, 10 + index * 1.5));
      canvas.drawPath(
        extrusion,
        Paint()
          ..color = const Color(0xFF073F9E)
          ..style = PaintingStyle.fill,
      );
      final facePaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF83BCFF), Color(0xFF0865DC)],
        ).createShader(face.getBounds())
        ..style = PaintingStyle.fill;
      canvas.drawPath(face, facePaint);
      canvas.drawPath(
        face,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }
  }

  Path _chevronPath(double centerX, double tipY, double scale) {
    final halfWidth = 80 * scale;
    final depth = 61 * scale;
    final thickness = 23 * scale;
    return Path()
      ..moveTo(centerX, tipY)
      ..lineTo(centerX + halfWidth, tipY + depth)
      ..lineTo(centerX + halfWidth - thickness, tipY + depth + thickness)
      ..lineTo(centerX, tipY + thickness * 1.35)
      ..lineTo(centerX - halfWidth + thickness, tipY + depth + thickness)
      ..lineTo(centerX - halfWidth, tipY + depth)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ArrivalMarker extends StatelessWidget {
  const ArrivalMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: const [
          BoxShadow(
              color: Colors.black38, blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: const Icon(Icons.flag_rounded, color: Colors.white, size: 72),
    );
  }
}

class NavigationPanel extends StatelessWidget {
  const NavigationPanel({
    super.key,
    required this.distance,
    required this.relativeBearing,
    required this.headingDegrees,
    required this.targetBearing,
    required this.horizontalAccuracy,
    required this.sensorProblem,
    required this.arrived,
  });

  final double distance;
  final double relativeBearing;
  final double? headingDegrees;
  final double targetBearing;
  final double horizontalAccuracy;
  final String? sensorProblem;
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    final instruction = headingDegrees == null
        ? 'Esperando orientación'
        : arrived
            ? 'Llegaste al punto'
            : instructionFor(relativeBearing);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE6101419),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Transform.rotate(
                  angle: (headingDegrees ?? 0) * -math.pi / 180,
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Color(0xFF65A8FF),
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDistance(distance),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      instruction,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF173557),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'AUTO',
                  style: TextStyle(
                    color: Color(0xFF8DC1FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  headingDegrees == null
                      ? 'Brújula: esperando datos'
                      : 'Brújula: ${headingDegrees!.toStringAsFixed(0)}°  ·  Destino: ${targetBearing.toStringAsFixed(0)}°',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
              Text(
                'GPS ±${horizontalAccuracy.toStringAsFixed(0)} m',
                style: TextStyle(
                  color: horizontalAccuracy <= 10
                      ? const Color(0xFF8BE3B1)
                      : const Color(0xFFFFC66E),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (sensorProblem != null) ...[
            const SizedBox(height: 9),
            Text(
              sensorProblem!,
              style: const TextStyle(color: Color(0xFFFFC66E), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

double coordinateDistanceMeters(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  const earthRadiusMeters = 6371000.0;
  final latitudeDelta = (latitudeB - latitudeA) * math.pi / 180;
  final longitudeDelta = (longitudeB - longitudeA) * math.pi / 180;
  final latitudeARadians = latitudeA * math.pi / 180;
  final latitudeBRadians = latitudeB * math.pi / 180;
  final haversine = math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(latitudeARadians) *
          math.cos(latitudeBRadians) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return earthRadiusMeters *
      2 *
      math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
}

double coordinateBearingDegrees(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  final startLatitude = latitudeA * math.pi / 180;
  final endLatitude = latitudeB * math.pi / 180;
  final longitudeDelta = (longitudeB - longitudeA) * math.pi / 180;
  final y = math.sin(longitudeDelta) * math.cos(endLatitude);
  final x = math.cos(startLatitude) * math.sin(endLatitude) -
      math.sin(startLatitude) *
          math.cos(endLatitude) *
          math.cos(longitudeDelta);
  return normalizeDegrees(math.atan2(y, x) * 180 / math.pi);
}

double normalizeDegrees(double degrees) {
  final normalized = degrees % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

double shortestSignedAngle(double degrees) {
  return (degrees + 540) % 360 - 180;
}

String instructionFor(double relativeBearing) {
  final signed = shortestSignedAngle(relativeBearing);
  final absolute = signed.abs();
  if (absolute <= 12) return 'Sigue derecho';
  if (absolute <= 50) {
    return signed > 0 ? 'Ve hacia la derecha' : 'Ve hacia la izquierda';
  }
  if (absolute <= 125) {
    return signed > 0 ? 'Gira a la derecha' : 'Gira a la izquierda';
  }
  return 'Date la vuelta';
}

String formatDistance(double meters) {
  if (meters < 10) return '${meters.toStringAsFixed(1)} m';
  if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
