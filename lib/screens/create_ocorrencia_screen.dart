// lib/screens/create_ocorrencia_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dc_app/services/auth_service.dart';
import 'package:dc_app/services/ocorrencia_service.dart';
import 'package:dc_app/services/location_service.dart';
import 'package:dc_app/widgets/autocomplete_field.dart';
import 'package:dc_app/models/setor.dart';
import 'package:dc_app/screens/map_drawing_screen.dart';

class CreateOcorrenciaScreen extends StatefulWidget {
  const CreateOcorrenciaScreen({super.key});

  @override
  State<CreateOcorrenciaScreen> createState() => _CreateOcorrenciaScreenState();
}

class _CreateOcorrenciaScreenState extends State<CreateOcorrenciaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assuntoController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _logger = Logger();

  int? _selectedPrioridadeId;
  int? _selectedSetorId;
  int? _selectedTipoOcorrenciaId;
  final List<File> _images = [];
  bool _isSaving = false;
  
  // Variáveis para localização
  String? _currentLocation;
  bool _isGettingLocation = false;
  final _areaController = TextEditingController();
  final _locationController = TextEditingController();
  Position? _currentPosition;
  
  // Variáveis para polígono desenhado
  List<List<double>> _drawnPolygon = [];
  bool _hasDrawnArea = false;

  late Future<OcorrenciaCreationData> _creationDataFuture;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  void _loadDropdownData() {
    _creationDataFuture = OcorrenciaService.getCreationData();
    _creationDataFuture.then((data) {
      if (mounted && data.setorUsuarioId != null) {
        // Pré-seleciona o setor do usuário, se disponível
        setState(() {
          _selectedSetorId = data.setorUsuarioId;
        });
      }
    }).catchError((error) {
      _showError(error is AuthException ? error.message : 'Falha ao carregar dados para criação.');
    });
  }

  // Método para capturar localização atual
  Future<void> _getCurrentLocation() async {
    print('🔍 Debug - Iniciando _getCurrentLocation');
    setState(() => _isGettingLocation = true);
    
    try {
      _logger.i('Solicitando permissão de localização...');
      
      // Solicita permissão de localização
      bool hasPermission = await LocationService.requestLocationPermission();
      if (!hasPermission) {
        _showError('Permissão de localização negada. Não foi possível obter a localização atual.');
        return;
      }

      _logger.i('Obtendo localização atual...');
      
      // Obtém a localização atual (método otimizado)
      final locationData = await LocationService.getCurrentLocationOnly();
      
      if (locationData != null) {
        print('🔍 Debug - Localização obtida: ${locationData['latitude']}, ${locationData['longitude']}');
        setState(() {
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
        });
        
        print('🔍 Debug - _currentPosition definido: $_currentPosition');
        _logger.i('Localização obtida para centralizar o mapa');
        _showSuccess('Localização obtida para centralizar o mapa');
      } else {
        print('🔍 Debug - locationData é null');
        _showError('Não foi possível obter a localização atual.');
      }
    } catch (e) {
      _logger.e('Erro ao obter localização', error: e);
      _showError('Erro ao obter localização: ${e.toString()}');
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage(imageQuality: 70);

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _images.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showError('Por favor, corrija os erros no formulário.');
      return;
    }
    setState(() => _isSaving = true);

    try {
      // Debug: verificar se a localização foi capturada
      print('🔍 Debug - _currentPosition: $_currentPosition');
      print('🔍 Debug - _hasDrawnArea: $_hasDrawnArea');
      print('🔍 Debug - _drawnPolygon: ${_drawnPolygon.length} pontos');
      
      await OcorrenciaService.createOcorrencia(
        assunto: _assuntoController.text,
        descricao: _descricaoController.text,
        prioridadeId: _selectedPrioridadeId,
        setorId: _selectedSetorId,
        tipoOcorrenciaId: _selectedTipoOcorrenciaId,
        imagens: _images,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        poligono: _hasDrawnArea ? _drawnPolygon : null,
      );
      _showSuccess('Ocorrência registrada com sucesso!');
      if (mounted) Navigator.of(context).pop(true); // Retorna true para a tela anterior saber que algo foi criado
    } on OcorrenciaException catch (e) {
      _showError(e.message);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _logger.e('Erro inesperado ao criar ocorrência', error: e);
      _showError('Ocorreu um erro desconhecido. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
    ));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _openMapDrawing() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MapDrawingScreen(),
      ),
    );
    
    if (result == true && mounted) {
      // O usuário desenhou uma área no mapa
      setState(() {
        _hasDrawnArea = true;
      });
      _showSuccess('Área desenhada com sucesso!');
    }
  }

  @override
  void dispose() {
    _assuntoController.dispose();
    _descricaoController.dispose();
    _areaController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Nova Ocorrência')),
      body: FutureBuilder<OcorrenciaCreationData>(
        future: _creationDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Nenhum dado encontrado para criar a ocorrência.'));
          }

          final data = snapshot.data!;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              children: [
                _buildHeader(theme),
                _buildTextField(
                  controller: _assuntoController,
                  labelText: 'Assunto da Ocorrência',
                  prefixIcon: Icons.subject_rounded,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe o assunto.' : null,
                ),
                _buildDropdown(
                  label: 'Tipo de Ocorrência',
                  items: data.tiposOcorrencia,
                  selectedValue: _selectedTipoOcorrenciaId,
                  onChanged: (value) => setState(() => _selectedTipoOcorrenciaId = value),
                  prefixIcon: Icons.category_outlined,
                  validator: (v) => v == null ? 'Selecione o tipo.' : null,
                ),
                _buildDropdown(
                  label: 'Prioridade',
                  items: data.prioridades,
                  selectedValue: _selectedPrioridadeId,
                  onChanged: (value) => setState(() => _selectedPrioridadeId = value),
                  prefixIcon: Icons.notification_important_outlined,
                  validator: (v) => v == null ? 'Selecione a prioridade.' : null,
                ),
                _buildSetorDropdown(
                  label: 'Setor de Destino',
                  setores: data.setores,
                  selectedValue: _selectedSetorId,
                  onChanged: (value) => setState(() => _selectedSetorId = value),
                  prefixIcon: Icons.group_work_outlined,
                  validator: (v) => v == null ? 'Selecione o setor.' : null,
                ),
                // Campo de localização
                _buildLocationField(),
                _buildTextField(
                  controller: _descricaoController,
                  labelText: 'Descreva o problema ou solicitação...',
                  prefixIcon: Icons.description_outlined,
                  maxLines: 6,
                  minLines: 4,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe a descrição.' : null,
                ),
                const SizedBox(height: 16),
                _buildImagePicker(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
                const SizedBox(height: 44),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, top: 12.0),
      child: Column(
        children: [
          Icon(Icons.add_alert_outlined, size: 48, color: Colors.grey.shade700),
          const SizedBox(height: 10),
          Text('Informe os Detalhes da Ocorrência', style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _buildTextField({ required TextEditingController controller, required String labelText, required IconData prefixIcon, required FormFieldValidator<String> validator, int? maxLines = 1, int? minLines = 1, }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: labelText, prefixIcon: Icon(prefixIcon)),
        maxLines: maxLines,
        minLines: minLines,
        validator: validator,
      ),
    );
  }

  Widget _buildDropdown({ required String label, required List<DropdownItem> items, required int? selectedValue, required ValueChanged<int?> onChanged, required IconData prefixIcon, required FormFieldValidator<int> validator, }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<int>(
        value: selectedValue,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(prefixIcon)),
        items: items.map((item) => DropdownMenuItem<int>(value: item.id, child: Text(item.nome, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
        validator: validator,
        isExpanded: true,
      ),
    );
  }

  Widget _buildSetorDropdown({ required String label, required List<Setor> setores, required int? selectedValue, required ValueChanged<int?> onChanged, required IconData prefixIcon, required FormFieldValidator<int> validator, }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<int>(
        value: selectedValue,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(prefixIcon)),
        items: setores.map((setor) => DropdownMenuItem<int>(
          value: setor.id, 
          child: Text(setor.nome, overflow: TextOverflow.ellipsis)
        )).toList(),
        onChanged: onChanged,
        validator: validator,
        isExpanded: true,
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('Anexos:', style: Theme.of(context).textTheme.titleSmall),
          ),
        if (_images.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.file(_images[index], height: 120, width: 120, fit: BoxFit.cover),
                  ),
                  Material(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _removeImage(index),
                      child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.close, color: Colors.white, size: 18)),
                    ),
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.attach_file),
          label: Text(_images.isEmpty ? 'Anexar Fotos' : 'Adicionar mais fotos'),
          onPressed: _pickImages,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            foregroundColor: Theme.of(context).colorScheme.primary,
            side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return _isSaving
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton.icon(
      icon: const Icon(Icons.send_rounded),
      label: const Text('REGISTRAR OCORRÊNCIA'),
      onPressed: _submitForm,
    );
  }

  // Widget para o campo de localização
  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        
        // Título da seção
        Row(
          children: [
            Icon(Icons.map, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Localização e Área',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Botões de localização
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isGettingLocation ? null : _getCurrentLocation,
                icon: _isGettingLocation 
                  ? const SizedBox(
                      width: 16, 
                      height: 16, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    )
                  : const Icon(Icons.my_location),
                label: Text(_isGettingLocation ? 'Obtendo...' : 'Minha Localização'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openMapDrawing,
                icon: const Icon(Icons.map),
                label: Text(_hasDrawnArea ? 'Editar Área' : 'Desenhar Área'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasDrawnArea ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        
        // Status da localização capturada
        if (_currentPosition != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.blue.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Localização capturada: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Status da área desenhada
        if (_hasDrawnArea) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Área desenhada com ${_drawnPolygon.length} pontos',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}