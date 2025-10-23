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
import 'package:dc_app/widgets/mini_map_widget.dart';

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
  
  // Variáveis para polígonos desenhados (múltiplos)
  List<List<List<double>>> _drawnPolygons = [];
  List<List<double>> _currentPolygon = [];
  bool _isDraft = false;

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
        
        _logger.i('Localização obtida para centralizar o mapa');
        _showSuccess('Localização obtida para centralizar o mapa');
      } else {
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
      await OcorrenciaService.createOcorrencia(
        assunto: _assuntoController.text,
        descricao: _descricaoController.text,
        prioridadeId: _selectedPrioridadeId,
        setorId: _selectedSetorId,
        tipoOcorrenciaId: _selectedTipoOcorrenciaId,
        imagens: _images,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        poligono: _drawnPolygons.isNotEmpty ? _drawnPolygons.first : null,
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

  void _onPolygonChanged(List<List<double>> polygon) {
    setState(() {
      _currentPolygon = polygon;
    });
  }

  void _addCurrentPolygon() {
    if (_currentPolygon.isNotEmpty) {
      setState(() {
        _drawnPolygons.add(List.from(_currentPolygon));
        _currentPolygon.clear();
        _isDraft = true;
      });
      _showSuccess('Área adicionada! Você pode desenhar mais áreas ou salvar o rascunho.');
    }
  }

  void _removePolygon(int index) {
    setState(() {
      _drawnPolygons.removeAt(index);
      if (_drawnPolygons.isEmpty) {
        _isDraft = false;
      }
    });
  }

  void _saveDraft() async {
    if (_drawnPolygons.isEmpty) {
      _showError('Adicione pelo menos uma área antes de salvar o rascunho.');
      return;
    }

    try {
      // Aqui você pode implementar a lógica para salvar como rascunho
      _showSuccess('Rascunho salvo com ${_drawnPolygons.length} área(s)!');
    } catch (e) {
      _showError('Erro ao salvar rascunho: $e');
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

  // Widget para o mini mapa integrado
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
        
        // Mini mapa
        MiniMapWidget(
          currentPosition: _currentPosition,
          initialPolygon: _currentPolygon.isNotEmpty ? _currentPolygon : null,
          onPolygonChanged: _onPolygonChanged,
          allowDrawing: true,
          height: 300,
        ),
        
        const SizedBox(height: 12),
        
        // Controles do mapa
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _currentPolygon.isNotEmpty ? _addCurrentPolygon : null,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Área'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isDraft ? _saveDraft : null,
              icon: const Icon(Icons.save),
              label: const Text('Salvar Rascunho'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        
        // Lista de áreas desenhadas
        if (_drawnPolygons.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Áreas Desenhadas (${_drawnPolygons.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_drawnPolygons.length, (index) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text('${index + 1}'),
                ),
                title: Text('Área ${index + 1}'),
                subtitle: Text('${_drawnPolygons[index].length} pontos'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removePolygon(index),
                ),
              ),
            );
          }),
        ],
        
        // Status do rascunho
        if (_isDraft) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.edit, color: Colors.orange.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rascunho salvo com ${_drawnPolygons.length} área(s)',
                    style: TextStyle(
                      color: Colors.orange.shade700,
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