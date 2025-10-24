// lib/screens/map_drawing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dc_app/services/location_service.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart'; // 1. Importar Provider
import 'package:dc_app/services/location_state_service.dart'; // 2. Importar LocationStateService

class MapDrawingScreen extends StatefulWidget {
  const MapDrawingScreen({super.key});

  @override
  _MapDrawingScreenState createState() => _MapDrawingScreenState();
}

class _MapDrawingScreenState extends State<MapDrawingScreen> {
  List<LatLng> _polygonPoints = [];
  List<LatLng> _currentPolygon = [];
  LatLng _initialCameraPosition =
  const LatLng(-15.7942, -47.8825); // Posição inicial (Brasília)
  bool _isLoading = true;
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _logger.i('Iniciando MapDrawingScreen');
    _centerMapOnUserLocation();
  }

  Future<void> _centerMapOnUserLocation() async {
    _logger.i('Tentando centralizar mapa na localização do usuário...');
    try {
      final locationData = await LocationService.getCurrentLocationOnly();
      if (locationData != null && mounted) {
        setState(() {
          _initialCameraPosition =
              LatLng(locationData['latitude'], locationData['longitude']);
          _isLoading = false;
        });
        // O flutter_map não precisa de animateCamera
        _logger.i('Mapa centralizado em: $_initialCameraPosition');
      } else {
        _logger.w('Não foi possível obter localização. Usando posição padrão.');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      _logger.e('Erro ao obter localização para centralizar mapa', error: e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // flutter_map não precisa de onMapCreated

  void _onTap(LatLng point) {
    setState(() {
      _polygonPoints.add(point);
      _updatePolygons();
    });
    _logger.d('Ponto adicionado: $point');
  }

  void _updatePolygons() {
    setState(() {
      _currentPolygon = List.from(_polygonPoints);
    });
  }

  void _clearPolygon() {
    setState(() {
      _polygonPoints = [];
      _currentPolygon = [];
    });
    _logger.i('Polígono limpo.');
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
        _currentPolygon = List.from(_polygonPoints);
      });
      _logger.i('Último ponto removido.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desenhar Área da Ocorrência'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undoLastPoint,
            tooltip: 'Desfazer último ponto',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearPolygon,
            tooltip: 'Limpar desenho',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
        options: MapOptions(
          initialCenter: _initialCameraPosition,
          initialZoom: 14.0,
          onTap: (tapPosition, point) => _onTap(point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.dc_app',
          ),
          if (_currentPolygon.isNotEmpty)
            PolygonLayer(
              polygons: [
                Polygon(
                  points: _currentPolygon,
                  color: Colors.red.withOpacity(0.3),
                  borderColor: Colors.red,
                  borderStrokeWidth: 2.0,
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: _polygonPoints.length < 3
          ? null
          : FloatingActionButton.extended(
        icon: const Icon(Icons.check),
        label: const Text('Usar Esta Área'),
        onPressed: () {
          // *** INÍCIO DA CORREÇÃO ***

          // 1. Converte List<LatLng> para List<List<double>>
          final List<List<double>> polygonResult = _polygonPoints
              .map((latLng) => [latLng.latitude, latLng.longitude])
              .toList();

          _logger.i('Salvando polígono com ${polygonResult.length} pontos.');

          // 2. Obtém o serviço
          final locationState =
          Provider.of<LocationStateService>(context, listen: false);

          // 3. Salva o polígono no serviço
          locationState.setDrawnPolygon(polygonResult);

          // 4. Apenas fecha a tela (sem retornar valor)
          Navigator.of(context).pop();

          // *** FIM DA CORREÇÃO ***
        },
      ),
    );
  }
}