// lib/screens/create_ocorrencia_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dc_app/services/ocorrencia_service.dart';
import 'package:dc_app/services/location_service.dart';
import 'package:dc_app/screens/map_drawing_screen.dart';
import 'package:dc_app/services/location_state_service.dart';
import 'package:dc_app/services/auth_service.dart'; // Importar AuthService
import 'package:provider/provider.dart'; // Importar Provider
import 'package:logger/logger.dart';

class CreateOcorrenciaScreen extends StatefulWidget {
  const CreateOcorrenciaScreen({super.key});

  @override
  _CreateOcorrenciaScreenState createState() => _CreateOcorrenciaScreenState();
}

class _CreateOcorrenciaScreenState extends State<CreateOcorrenciaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _logger = Logger();

  // Controladores
  final _assuntoController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _locationController = TextEditingController();

  // Seletores
  String? _selectedPrioridade;
  String? _selectedTipo;
  String? _selectedSetor;
  List<File> _anexos = [];

  // Estado de UI
  bool _isSaving = false;
  Future<OcorrenciaCreationData>? _creationDataFuture;

  @override
  void initState() {
    super.initState();
    _logger.i('Iniciando CreateOcorrenciaScreen');
    // Limpa estado de localização anterior ao iniciar a tela
    Provider.of<LocationStateService>(context, listen: false)
        .clearLocationState();
    _loadDropdownData();
  }

  @override
  void dispose() {
    _assuntoController.dispose();
    _descricaoController.dispose();
    _locationController.dispose();
    // Limpa estado de localização ao sair da tela
    Provider.of<LocationStateService>(context, listen: false)
        .clearLocationState();
    _logger.i('Disposing CreateOcorrenciaScreen');
    super.dispose();
  }

  void _loadDropdownData() {
    _logger.i('Tentando carregar dados do dropdown...');

    // Obter o AuthService do Provider
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    final userId = authService.userId;

    // Verificar se o usuário está autenticado
    if (token == null || userId == null) {
      _logger.w('Usuário não autenticado. Não é possível carregar dados.');
      // Define o futuro como um erro para o FutureBuilder tratar
      setState(() {
        _creationDataFuture = Future.error(
          OcorrenciaException('Sua sessão expirou. Faça login novamente.'),
        );
      });
      _showErrorAndRedirectToLogin('Sua sessão expirou. Faça login novamente.');
      return;
    }

    // Passa o token e userId para o serviço
    setState(() {
      _creationDataFuture = OcorrenciaService.getCreationData(token, userId);
    });

    _creationDataFuture!.then((data) {
      _logger.i('Dados do dropdown carregados com sucesso.');
    }).catchError((error) {
      _logger.e('Erro ao carregar dados do dropdown', error: error);
      // O FutureBuilder tratará a exibição do erro
    });
  }

  Future<void> _getCurrentLocation() async {
    _logger.i('Tentando obter localização atual...');
    final locationState = Provider.of<LocationStateService>(context, listen: false);
    
    locationState.setGettingLocation(true);

    try {
      // Solicita permissão de localização
      bool hasPermission = await LocationService.requestLocationPermission();
      if (!hasPermission) {
        _showError('Permissão de localização negada. Não foi possível obter a localização atual.');
        return;
      }

      _logger.i('Obtendo localização atual...');
      
      // Obtém a localização atual
      final locationData = await LocationService.getCurrentLocationOnly();
      
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
        
        // Salva no LocationStateService
        locationState.setCurrentPosition(position);
        
        _logger.i('Localização obtida: ${position.latitude}, ${position.longitude}');
        _showSuccess('Localização obtida com sucesso');
      } else {
        _showError('Não foi possível obter a localização atual.');
        _logger.w('locationData é null');
      }
    } catch (e) {
      _logger.e('Erro ao obter localização', error: e);
      _showError('Erro ao obter localização: ${e.toString()}');
    } finally {
      locationState.setGettingLocation(false);
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Lê o estado de localização do serviço
      final locationState =
      Provider.of<LocationStateService>(context, listen: false);

      // Lê o estado de autenticação do serviço
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;
      final userId = authService.userId;

      // Validação de autenticação
      if (token == null || userId == null) {
        _showErrorAndRedirectToLogin('Sessão expirada. Faça login novamente.');
        return;
      }

      // Validação de localização
      if (locationState.currentPosition == null &&
          !locationState.hasDrawnArea) {
        _showError(
            'Por favor, forneça sua localização atual ou desenhe uma área no mapa.');
        return;
      }

      setState(() => _isSaving = true);
      _logger.i('Iniciando submissão do formulário...');

      try {
        await OcorrenciaService.createOcorrencia(
          token, // Passa o token
          userId, // Passa o userId
          assunto: _assuntoController.text,
          prioridade: _selectedPrioridade!,
          tipo: _selectedTipo!,
          setor: _selectedSetor!,
          descricao: _descricaoController.text,
          latitude: locationState.currentPosition?.latitude,
          longitude: locationState.currentPosition?.longitude,
          poligono:
          locationState.hasDrawnArea ? locationState.drawnPolygon : null,
        );

        // Simulação de upload de anexos (se houver)
        // Em um app real, você pegaria o ID da ocorrência criada e faria o upload
        if (_anexos.isNotEmpty) {
          _logger.i('Iniciando upload de ${_anexos.length} anexos...');
          // Supondo que a API de criação retorne o ID, ou que você tenha outro método
          // Aqui estamos apenas simulando
          // int ocorrenciaId = ...; // ID retornado pela API
          // for (var file in _anexos) {
          //   await OcorrenciaService.uploadFile(token, ocorrenciaId: ocorrenciaId, file: file);
          // }
          await Future.delayed(const Duration(seconds: 1)); // Simulação
        }

        _logger.i('Ocorrência registrada com sucesso.');
        _showSuccess('Ocorrência registrada com sucesso!');
        if (mounted) Navigator.of(context).pop(true);
      } on OcorrenciaException catch (e) {
        _logger.e('Falha ao registrar ocorrência (OcorrenciaException)',
            error: e);
        _showError('Erro ao registrar: ${e.message}');
      } catch (e) {
        _logger.e('Falha ao registrar ocorrência (Erro desconhecido)', error: e);
        _showError('Ocorreu um erro inesperado: $e');
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    } else {
      _logger.w('Formulário inválido. Verifique os campos.');
      _showError('Por favor, preencha todos os campos obrigatórios.');
    }
  }

  Future<void> _openMapDrawing() async {
    _logger.i('Abrindo tela de desenho de mapa...');

    // Apenas navega. O MapDrawingScreen irá atualizar o LocationStateService.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MapDrawingScreen(),
      ),
    );

    // O Consumer<LocationStateService> no build()
    // irá reconstruir o _buildLocationField automaticamente
    // quando o serviço for atualizado pelo MapDrawingScreen.
    _logger.i('Retornou da tela de desenho.');
  }


  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _anexos.add(File(pickedFile.path));
      });
      _logger.i('Imagem selecionada: ${pickedFile.path}');
    } else {
      _logger.i('Seleção de imagem cancelada.');
    }
  }

  // --- Funções de UI ---

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _showErrorAndRedirectToLogin(String message) {
    if (mounted) {
      _showError(message);
      // Redireciona para o login após mostrar a mensagem
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Ocorrência'),
        backgroundColor: theme.primaryColor,
      ),
      body: FutureBuilder<OcorrenciaCreationData>(
        future: _creationDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            _logger.i('FutureBuilder: Carregando dados...');
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            _logger.e('FutureBuilder: Erro ao carregar', error: snapshot.error);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Erro ao carregar dados: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loadDropdownData,
                      child: const Text('Tentar Novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            _logger.w('FutureBuilder: Sem dados (snapshot.hasData é falso)');
            return const Center(child: Text('Nenhum dado encontrado.'));
          }

          _logger.i('FutureBuilder: Dados carregados, construindo formulário.');
          final creationData = snapshot.data!;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionTitle('Informações Básicas', theme),
                  _buildTextFormField(_assuntoController, 'Assunto'),
                  _buildDropdown(
                    'Prioridade',
                    _selectedPrioridade,
                    creationData.prioridades,
                        (value) => setState(() => _selectedPrioridade = value),
                  ),
                  _buildDropdown(
                    'Tipo de Ocorrência',
                    _selectedTipo,
                    creationData.tipos,
                        (value) => setState(() => _selectedTipo = value),
                  ),
                  _buildDropdown(
                    'Setor Responsável',
                    _selectedSetor,
                    creationData.setores,
                        (value) => setState(() => _selectedSetor = value),
                  ),
                  _buildTextFormField(_descricaoController, 'Descrição',
                      maxLines: 5),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Localização', theme),

                  // O Consumer garante que este widget seja reconstruído
                  // sempre que o LocationStateService notificar mudanças.
                  Consumer<LocationStateService>(
                    builder: (context, locationState, child) {
                      _logger.i('Consumer<LocationStateService> reconstruído.');
                      return _buildLocationField(
                        isGettingLocation: locationState.isGettingLocation,
                        hasDrawnArea: locationState.hasDrawnArea,
                        currentPosition: locationState.currentPosition,
                        drawnPolygon: locationState.drawnPolygon ?? [],
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Anexos (Opcional)', theme),
                  _buildAttachmentField(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Widgets de Construção ---

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style:
        theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor),
      ),
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        maxLines: maxLines,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Por favor, preencha o campo $label.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown(String label, String? selectedValue,
      List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Por favor, selecione um(a) $label.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildLocationField({
    required bool isGettingLocation,
    required bool hasDrawnArea,
    required Position? currentPosition,
    required List<List<double>> drawnPolygon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.grey[50],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isGettingLocation ? null : _getCurrentLocation,
                  icon: isGettingLocation
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.my_location),
                  label: Text(isGettingLocation ? 'Obtendo...' : 'Minha Localização'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
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
                  label: Text(hasDrawnArea ? 'Editar Área' : 'Desenhar Área'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    hasDrawnArea ? Colors.green : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          // Status da localização capturada
          if (currentPosition != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Localização capturada: ${currentPosition.latitude.toStringAsFixed(6)}, ${currentPosition.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Status da área desenhada
          if (hasDrawnArea) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Área desenhada com ${drawnPolygon.length} pontos',
                    style: const TextStyle(color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentField() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.attach_file),
          label: const Text('Adicionar Anexo'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _anexos.map((file) {
            return Chip(
              label: Text(
                file.path.split('/').last,
                overflow: TextOverflow.ellipsis,
              ),
              avatar: const Icon(Icons.image, size: 18),
              onDeleted: () {
                setState(() {
                  _anexos.remove(file);
                });
                _logger.i('Anexo removido: ${file.path}');
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _submitForm,
      icon: _isSaving
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Colors.white,
        ),
      )
          : const Icon(Icons.send),
      label: Text(_isSaving ? 'Enviando...' : 'Registrar Ocorrência'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}