// lib/widgets/area_selection_widget.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dc_app/services/setor_location_service.dart';
import 'package:dc_app/services/location_service.dart';
import 'package:dc_app/models/setor.dart';

class AreaSelectionWidget extends StatefulWidget {
  final List<Setor> setores;
  final Function(List<List<double>>)? onAreaSelected;
  final Function(Setor?)? onSetorSelected;
  final bool showTriangulation;
  final bool showAreaCalculation;

  const AreaSelectionWidget({
    Key? key,
    required this.setores,
    this.onAreaSelected,
    this.onSetorSelected,
    this.showTriangulation = true,
    this.showAreaCalculation = true,
  }) : super(key: key);

  @override
  State<AreaSelectionWidget> createState() => _AreaSelectionWidgetState();
}

class _AreaSelectionWidgetState extends State<AreaSelectionWidget> {
  Position? _currentPosition;
  Setor? _selectedSetor;
  List<List<double>> _selectedPolygon = [];
  double _areaRadius = 100.0; // metros
  double _areaWidth = 200.0; // metros
  double _areaHeight = 200.0; // metros
  String _areaShape = 'circular'; // 'circular' ou 'rectangular'
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final locationData = await LocationService.getCurrentLocationWithAddress();
      if (locationData != null) {
        final position = Position(
          latitude: locationData['latitude'],
          longitude: locationData['longitude'],
          timestamp: DateTime.now(),
          accuracy: locationData['accuracy'] ?? 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        setState(() {
          _currentPosition = position;
        });

        // Encontra setores que contêm a localização atual
        final containingSetores = SetorLocationService.findSetoresContainingPoint(
          position.latitude,
          position.longitude,
          widget.setores,
        );

        if (containingSetores.isNotEmpty) {
          setState(() {
            _selectedSetor = containingSetores.first;
          });
          widget.onSetorSelected?.call(_selectedSetor);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao obter localização: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateArea() {
    if (_currentPosition == null) return;

    List<List<double>> newPolygon;

    if (_areaShape == 'circular') {
      newPolygon = SetorLocationService.createCircularPolygon(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _areaRadius,
      );
    } else {
      newPolygon = SetorLocationService.createRectangularPolygon(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _areaWidth,
        _areaHeight,
      );
    }

    setState(() {
      _selectedPolygon = newPolygon;
    });

    widget.onAreaSelected?.call(_selectedPolygon);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleção de Área',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // Status da localização
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    TextButton(
                      onPressed: _getCurrentLocation,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              )
            else if (_currentPosition != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Localização atual:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Seleção de setor
            if (_currentPosition != null) ...[
              Text(
                'Setor Atual:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_selectedSetor != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_city, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedSetor!.nome,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            if (_selectedSetor!.raio != null)
                              Text(
                                'Raio: ${_selectedSetor!.raio!.toStringAsFixed(0)}m',
                                style: TextStyle(color: Colors.blue.shade600),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Localização não está dentro de nenhum setor',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // Configuração da área
            if (_currentPosition != null) ...[
              Text(
                'Configuração da Área:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              // Forma da área
              Row(
                children: [
                  const Text('Forma: '),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _areaShape,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _areaShape = newValue;
                        });
                        _updateArea();
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 'circular', child: Text('Circular')),
                      DropdownMenuItem(value: 'rectangular', child: Text('Retangular')),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Parâmetros da área
              if (_areaShape == 'circular') ...[
                Text('Raio: ${_areaRadius.toStringAsFixed(0)} metros'),
                Slider(
                  value: _areaRadius,
                  min: 10.0,
                  max: 1000.0,
                  divisions: 99,
                  label: '${_areaRadius.toStringAsFixed(0)}m',
                  onChanged: (double value) {
                    setState(() {
                      _areaRadius = value;
                    });
                    _updateArea();
                  },
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Largura: ${_areaWidth.toStringAsFixed(0)} metros'),
                          Slider(
                            value: _areaWidth,
                            min: 10.0,
                            max: 1000.0,
                            divisions: 99,
                            onChanged: (double value) {
                              setState(() {
                                _areaWidth = value;
                              });
                              _updateArea();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Altura: ${_areaHeight.toStringAsFixed(0)} metros'),
                          Slider(
                            value: _areaHeight,
                            min: 10.0,
                            max: 1000.0,
                            divisions: 99,
                            onChanged: (double value) {
                              setState(() {
                                _areaHeight = value;
                              });
                              _updateArea();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Informações da área calculada
              if (widget.showAreaCalculation && _selectedPolygon.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informações da Área:',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Área: ${SetorLocationService.calculatePolygonArea(_selectedPolygon).toStringAsFixed(2)} m²'),
                      Text('Perímetro: ${SetorLocationService.calculatePolygonPerimeter(_selectedPolygon).toStringAsFixed(2)} m'),
                      Text('Centro: ${SetorLocationService.calculatePolygonCenter(_selectedPolygon)['latitude']!.toStringAsFixed(6)}, ${SetorLocationService.calculatePolygonCenter(_selectedPolygon)['longitude']!.toStringAsFixed(6)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Botões de ação
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _updateArea,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar Área'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectedPolygon.isNotEmpty
                          ? () {
                              widget.onAreaSelected?.call(_selectedPolygon);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Área selecionada com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
