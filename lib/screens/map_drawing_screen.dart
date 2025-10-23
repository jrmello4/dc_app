// lib/screens/map_drawing_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dc_app/services/ocorrencia_service.dart';
import 'package:dc_app/services/location_service.dart';
import 'package:dc_app/services/setor_location_service.dart';
import 'package:dc_app/widgets/leaflet_map_widget.dart';
import 'package:dc_app/models/setor.dart';

class MapDrawingScreen extends StatefulWidget {
  const MapDrawingScreen({Key? key}) : super(key: key);

  @override
  State<MapDrawingScreen> createState() => _MapDrawingScreenState();
}

class _MapDrawingScreenState extends State<MapDrawingScreen> {
  List<Setor> _setores = [];
  Position? _currentPosition;
  List<List<double>> _selectedPolygon = [];
  Setor? _selectedSetor;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showSetores = true;
  bool _allowDrawing = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Carrega dados de criação (setores)
      final creationData = await OcorrenciaService.getCreationData();
      
      // Obtém localização atual
      final locationData = await LocationService.getCurrentLocationWithAddress();
      
      setState(() {
        _setores = creationData.setores;
        if (locationData != null) {
          _currentPosition = Position(
            latitude: locationData['latitude'],
            longitude: locationData['longitude'],
            timestamp: DateTime.now(),
            accuracy: locationData['accuracy'] ?? 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );
        }
      });

      // Encontra setor atual
      if (_currentPosition != null) {
        final containingSetores = SetorLocationService.findSetoresContainingPoint(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          _setores,
        );
        
        if (containingSetores.isNotEmpty) {
          setState(() {
            _selectedSetor = containingSetores.first;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar dados: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onPolygonChanged(List<List<double>> polygon) {
    setState(() {
      _selectedPolygon = polygon;
    });
  }

  void _onSetorSelected(Setor? setor) {
    setState(() {
      _selectedSetor = setor;
    });
  }

  void _saveOcorrencia() async {
    if (_selectedPolygon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desenhe uma área no mapa primeiro'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await OcorrenciaService.createOcorrencia(
        assunto: 'Ocorrência com área desenhada',
        descricao: 'Ocorrência criada com polígono desenhado no mapa',
        setorId: _selectedSetor?.id,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        poligono: _selectedPolygon,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocorrência criada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Volta para a tela anterior
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar ocorrência: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desenhar Área no Mapa'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar dados',
          ),
          IconButton(
            onPressed: _showSetores ? () => setState(() => _showSetores = false) : () => setState(() => _showSetores = true),
            icon: Icon(_showSetores ? Icons.visibility_off : Icons.visibility),
            tooltip: _showSetores ? 'Ocultar setores' : 'Mostrar setores',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Informações do setor atual
                    if (_selectedSetor != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Colors.blue.shade50,
                        child: Row(
                          children: [
                            Icon(Icons.location_city, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Setor Atual: ${_selectedSetor!.nome}',
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
                      ),

                    // Mapa interativo
                    Expanded(
                      child: LeafletMapWidget(
                        setores: _setores,
                        currentPosition: _currentPosition,
                        initialPolygon: _selectedPolygon,
                        onPolygonChanged: _onPolygonChanged,
                        onSetorSelected: _onSetorSelected,
                        showSetores: _showSetores,
                        allowDrawing: _allowDrawing,
                        showControls: true,
                      ),
                    ),

                    // Painel de informações
                    if (_selectedPolygon.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Área Selecionada:',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoCard(
                                    icon: Icons.straighten,
                                    title: 'Área',
                                    value: '${SetorLocationService.calculatePolygonArea(_selectedPolygon).toStringAsFixed(2)} m²',
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _InfoCard(
                                    icon: Icons.timeline,
                                    title: 'Perímetro',
                                    value: '${SetorLocationService.calculatePolygonPerimeter(_selectedPolygon).toStringAsFixed(2)} m',
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoCard(
                                    icon: Icons.location_on,
                                    title: 'Pontos',
                                    value: '${_selectedPolygon.length}',
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _InfoCard(
                                    icon: Icons.check_circle,
                                    title: 'Válido',
                                    value: SetorLocationService.isValidPolygon(_selectedPolygon) ? 'Sim' : 'Não',
                                    color: SetorLocationService.isValidPolygon(_selectedPolygon) ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Botões de ação
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _selectedPolygon.isNotEmpty ? _saveOcorrencia : null,
                              icon: const Icon(Icons.save),
                              label: const Text('Salvar Ocorrência'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
