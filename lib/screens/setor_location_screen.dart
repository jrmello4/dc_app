// lib/screens/setor_location_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:dc_app/services/ocorrencia_service.dart';
import 'package:dc_app/services/location_service.dart';
import 'package:dc_app/services/setor_location_service.dart';
import 'package:dc_app/services/auth_service.dart';
import 'package:dc_app/widgets/area_selection_widget.dart';
import 'package:dc_app/widgets/map_triangulation_widget.dart';
import 'package:dc_app/models/setor.dart';

class SetorLocationScreen extends StatefulWidget {
  const SetorLocationScreen({Key? key}) : super(key: key);

  @override
  State<SetorLocationScreen> createState() => _SetorLocationScreenState();
}

class _SetorLocationScreenState extends State<SetorLocationScreen> {
  List<Setor> _setores = [];
  Position? _currentPosition;
  List<List<double>> _selectedPolygon = [];
  Setor? _selectedSetor;
  bool _isLoading = true;
  String? _errorMessage;

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
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;
      final userId = authService.userId;
      
      if (token == null || userId == null) {
        throw Exception('Usuário não autenticado');
      }
      
      final creationData = await OcorrenciaService.getCreationData(token, userId);
      
      // Obtém localização atual
      final locationData = await LocationService.getCurrentLocationWithAddress();
      
      setState(() {
        // Converte List<String> para List<Setor>
        _setores = creationData.setores.map((nome) => Setor(
          id: creationData.setores.indexOf(nome) + 1,
          nome: nome,
          latitude: 0.0,
          longitude: 0.0,
          raio: 0.0,
        )).toList();
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
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
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

  void _onAreaSelected(List<List<double>> polygon) {
    setState(() {
      _selectedPolygon = polygon;
    });
  }

  void _onSetorSelected(Setor? setor) {
    setState(() {
      _selectedSetor = setor;
    });
  }

  void _onPolygonUpdated(List<List<double>> polygon) {
    setState(() {
      _selectedPolygon = polygon;
    });
  }

  void _saveOcorrencia() async {
    if (_selectedPolygon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma área primeiro'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;
      final userId = authService.userId;
      
      if (token == null || userId == null) {
        throw Exception('Usuário não autenticado');
      }
      
      await OcorrenciaService.createOcorrencia(
        token,
        userId,
        assunto: 'Ocorrência com área selecionada',
        prioridade: 'Média', // Valor padrão
        tipo: 'Geral', // Valor padrão
        setor: _selectedSetor?.nome ?? 'Não especificado',
        descricao: 'Ocorrência criada com polígono personalizado',
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
        title: const Text('Localização e Triangulação'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar dados',
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
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Widget de seleção de área
                      AreaSelectionWidget(
                        setores: _setores,
                        onAreaSelected: _onAreaSelected,
                        onSetorSelected: _onSetorSelected,
                        showTriangulation: true,
                        showAreaCalculation: true,
                      ),

                      // Widget de mapa e triangulação
                      if (_currentPosition != null)
                        MapTriangulationWidget(
                          setores: _setores,
                          selectedPolygon: _selectedPolygon,
                          currentPosition: _currentPosition,
                          onPolygonUpdated: _onPolygonUpdated,
                          showTriangulation: true,
                          interactive: true,
                        ),

                      // Informações do setor atual
                      if (_selectedSetor != null)
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Setor Atual',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                ListTile(
                                  leading: Icon(
                                    Icons.location_city,
                                    color: Colors.blue.shade700,
                                  ),
                                  title: Text(
                                    _selectedSetor!.nome,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (_selectedSetor!.raio != null)
                                        Text('Raio: ${_selectedSetor!.raio!.toStringAsFixed(0)} metros'),
                                      if (_selectedSetor!.latitude != null && _selectedSetor!.longitude != null)
                                        Text(
                                          'Centro: ${_selectedSetor!.latitude!.toStringAsFixed(6)}, ${_selectedSetor!.longitude!.toStringAsFixed(6)}',
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Informações da área selecionada
                      if (_selectedPolygon.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Área Selecionada',
                                  style: Theme.of(context).textTheme.titleLarge,
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
                        ),

                      // Botão para salvar ocorrência
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _selectedPolygon.isNotEmpty ? _saveOcorrencia : null,
                            icon: const Icon(Icons.save),
                            label: const Text('Criar Ocorrência com Área'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
