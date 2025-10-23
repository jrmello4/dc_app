// lib/screens/ocorrencia_details_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:dc_app/models/avaliacao.dart';
import 'package:dc_app/models/mensagem.dart';
import 'package:dc_app/models/ocorrencia.dart';
import 'package:dc_app/services/auth_service.dart';
import 'package:dc_app/services/status_ocorrencia_service.dart';
import 'package:dc_app/services/ocorrencia_service.dart';
import 'package:dc_app/services/print_service.dart';
import 'package:dc_app/widgets/mensagem_widget.dart';
import 'package:dc_app/widgets/ocorrencia_map_widget.dart';

class OcorrenciaDetailsScreen extends StatefulWidget {
  final int ocorrenciaId;
  const OcorrenciaDetailsScreen({super.key, required this.ocorrenciaId});

  @override
  State<OcorrenciaDetailsScreen> createState() => _OcorrenciaDetailsScreenState();
}

class _OcorrenciaDetailsScreenState extends State<OcorrenciaDetailsScreen> {
  final _logger = Logger();
  late Future<Ocorrencia> _detailsFuture;

  final _mensagemController = TextEditingController();
  final _comentarioController = TextEditingController();

  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  int _userRating = 0;
  bool _isSendingMessage = false;
  bool _isUploadingImage = false;
  bool _isSubmittingRating = false;
  bool _isUpdatingStatus = false;
  bool _didStateChange = false;

  final StatusOcorrenciaService _statusOcorrenciaService = StatusOcorrenciaService();

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    _mensagemController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _detailsFuture = OcorrenciaService.getOcorrenciaDetails(widget.ocorrenciaId);
    });
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
    }
  }

  Future<void> _submitMessage() async {
    if (_mensagemController.text.trim().isEmpty && _pickedImage == null) return;

    setState(() => _isSendingMessage = true);

    final textToSend = _mensagemController.text.trim();
    final imageToSend = _pickedImage;

    _mensagemController.clear();
    setState(() => _pickedImage = null);

    try {
      await OcorrenciaService.addMessage(widget.ocorrenciaId, textToSend, image: imageToSend);
      _didStateChange = true;
      _showSuccess("Mensagem enviada com sucesso."); // Removido (simulação)
      _loadDetails(); // Recarrega para obter a nova mensagem (Comentário ajustado)
    } catch (e) {
      _showError('Erro ao enviar mensagem: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  Future<void> _handleUpdateStatus(String acao) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final message = await _statusOcorrenciaService.atualizarStatusOcorrencia(widget.ocorrenciaId, acao);
      _showSuccess(message);
      _didStateChange = true;
      _loadDetails();
    } catch (e) {
      _showError('Erro: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  // Método para imprimir a ocorrência
  void _printOcorrencia(Ocorrencia ocorrencia) async {
    try {
      _logger.i('Iniciando impressão da ocorrência ${ocorrencia.id}');
      await PrintService.printOcorrencia(ocorrencia, context);
    } catch (e) {
      _logger.e('Erro ao imprimir ocorrência', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao imprimir: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitRating() async {
    if (_userRating == 0) {
      _showError('Por favor, selecione uma nota.');
      return;
    }
    setState(() => _isSubmittingRating = true);
    try {
      await OcorrenciaService.addRating(
        ocorrenciaId: widget.ocorrenciaId,
        nota: _userRating,
        comentario: _comentarioController.text.trim(),
      );
      _showSuccess('Avaliação enviada com sucesso!');
      _comentarioController.clear();
      if (mounted) setState(() => _userRating = 0);
      _didStateChange = true;
      _loadDetails();
    } catch (e) {
      _showError('Erro ao enviar avaliação: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmittingRating = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;
    setState(() => _isUploadingImage = true);
    try {
      await OcorrenciaService.addImage(widget.ocorrenciaId, File(pickedFile.path));
      _showSuccess('Imagem enviada com sucesso!');
      _didStateChange = true;
      _loadDetails();
    } catch (e) {
      _showError('Erro ao enviar imagem: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.of(context).pop(_didStateChange);
      },
      child: Scaffold(
        body: FutureBuilder<Ocorrencia>(
          future: _detailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Scaffold(
                  appBar: AppBar(title: const Text('Detalhes da Ocorrência')),
                  body: _buildErrorView(snapshot.error, Theme.of(context)));
            }

            final Ocorrencia ocorrencia = snapshot.data!;
            final List<Mensagem> messages = ocorrencia.mensagens;
            final bool isClosed = ocorrencia.status.toLowerCase() == 'encerrada';
            final bool isOwner = (AuthService.userId == ocorrencia.solicitanteId);
            final bool canManage = AuthService.isTecnico || isOwner;

            return Scaffold(
              appBar: _buildAppBar(context, ocorrencia, isClosed, canManage),
              body: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadDetails,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                        children: [
                          _buildOcorrenciaInfoCard(ocorrencia, isClosed, Theme.of(context)),
                          _buildAnexoSection(ocorrencia, Theme.of(context)),
                          if (!isClosed) _buildImageUploadSection(),
                          _buildMensagensSection(messages, Theme.of(context)),
                          if (isClosed && isOwner) _buildAvaliacaoWrapper(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (!isClosed) _buildMessageInputField(Theme.of(context)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, Ocorrencia ocorrencia, bool isClosed, bool canManage) {
    return AppBar(
      title: Text('Ocorrência #${ocorrencia.id}'),
      actions: [
        // Botão de impressão
        IconButton(
          icon: const Icon(Icons.print),
          onPressed: () => _printOcorrencia(ocorrencia),
          tooltip: 'Imprimir Ocorrência',
        ),
        if (_isUpdatingStatus)
          const Padding(padding: EdgeInsets.only(right: 16.0), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.0))))
        else if (canManage)
          PopupMenuButton<String>(
            onSelected: _handleUpdateStatus,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              if (isClosed) const PopupMenuItem<String>(value: 'abrir', child: ListTile(leading: Icon(Icons.lock_open_rounded), title: Text('Reabrir Ocorrência')))
              else const PopupMenuItem<String>(value: 'fechar', child: ListTile(leading: Icon(Icons.lock_outline_rounded), title: Text('Encerrar Ocorrência'))),
            ],
          ),
      ],
    );
  }

  Widget _buildOcorrenciaInfoCard(Ocorrencia ocorrencia, bool isClosed, ThemeData theme) {
    final statusColor = isClosed ? theme.colorScheme.error : Colors.green.shade700;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ocorrencia.assunto, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            _buildDetailRow('Status', ocorrencia.status, theme, valueColor: statusColor, valueFontWeight: FontWeight.bold),
            _buildDetailRow('Solicitante', ocorrencia.solicitanteNome ?? 'N/A', theme),
            _buildDetailRow('Setor', ocorrencia.setorNome ?? 'N/A', theme),
            _buildDetailRow('Prioridade', ocorrencia.prioridadeNome ?? 'N/A', theme),
            _buildDetailRow('Aberta em', _formatDateTime(ocorrencia.dataInicio), theme),
            if (isClosed) _buildDetailRow('Encerrada em', _formatDateTime(ocorrencia.dataFim), theme),
            const Divider(height: 24, thickness: 1),
            Text(ocorrencia.descricao, style: theme.textTheme.bodyMedium),
            
            // Mapa com área desenhada (se houver dados geográficos)
            if (ocorrencia.poligonos != null && ocorrencia.poligonos!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 24, thickness: 1),
              Text('Área da Ocorrência', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              OcorrenciaMapWidget(ocorrencia: ocorrencia, height: 250),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnexoSection(Ocorrencia ocorrencia, ThemeData theme) {
    if (ocorrencia.todasAnexoUrls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Anexos', theme),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: ocorrencia.todasAnexoUrls.length,
          itemBuilder: (context, index) {
            final fullUrl = ocorrencia.todasAnexoUrls[index];
            return GestureDetector(
              onTap: () => _showImageDialog(context, fullUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  fullUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (context, error, stack) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildImageUploadSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: _isUploadingImage
          ? const Center(child: CircularProgressIndicator())
          : OutlinedButton.icon(
        icon: const Icon(Icons.attach_file),
        label: const Text('Adicionar Novo Anexo'),
        onPressed: _pickAndUploadImage,
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
      ),
    );
  }

  Widget _buildMensagensSection(List<Mensagem> messages, ThemeData theme) {
    final currentUserId = AuthService.userId;
    messages.sort((a, b) => (a.dataCriacao ?? DateTime(0)).compareTo(b.dataCriacao ?? DateTime(0)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Mensagens', theme),
        if (messages.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Nenhuma mensagem nesta ocorrência.'))),
        ...messages.map((msg) {
          final isMe = msg.usuarioId == currentUserId;
          return MensagemWidget(mensagem: msg, isMe: isMe);
        }),
      ],
    );
  }

  Widget _buildAvaliacaoWrapper() {
    return FutureBuilder<List<Avaliacao>>(
      future: OcorrenciaService.getRatings(widget.ocorrenciaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
        }
        final ratings = snapshot.data ?? [];
        return _buildAvaliacaoSection(ratings, Theme.of(context));
      },
    );
  }

  Widget _buildAvaliacaoSection(List<Avaliacao> ratings, ThemeData theme) {
    final bool hasUserRated = ratings.any((r) => r.usuarioId == AuthService.userId);

    if (hasUserRated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Sua Avaliação', theme),
          ...ratings.where((r) => r.usuarioId == AuthService.userId).map((r) => _buildAvaliacaoCard(r, theme)),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Avalie o Atendimento', theme),
          _buildRatingInputCard(theme)
        ],
      );
    }
  }

  Widget _buildAvaliacaoCard(Avaliacao avaliacao, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(avaliacao.nomeUsuario, style: theme.textTheme.titleMedium),
                Row(children: List.generate(5, (i) => Icon(i < avaliacao.nota ? Icons.star : Icons.star_border, color: Colors.amber, size: 18))),
              ],
            ),
            if (avaliacao.comentario.isNotEmpty) ...[
              const Divider(height: 20),
              Text('"${avaliacao.comentario}"', style: const TextStyle(fontStyle: FontStyle.italic)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildRatingInputCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Sua opinião é importante! Por favor, deixe sua nota.'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) => IconButton(
                onPressed: () => setState(() => _userRating = index + 1),
                icon: Icon(index < _userRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 36),
              )),
            ),
            TextField(controller: _comentarioController, decoration: const InputDecoration(labelText: 'Comentário (opcional)'), maxLines: 2),
            const SizedBox(height: 16),
            _isSubmittingRating
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded),
              label: const Text('Enviar Avaliação'),
              onPressed: _submitRating,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputField(ThemeData theme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black12, offset: Offset(0, -2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pickedImage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.file(_pickedImage!, height: 100, width: 100, fit: BoxFit.cover),
                    ),
                    Material(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() => _pickedImage = null),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: theme.colorScheme.secondary),
                  onPressed: _pickImageFromGallery,
                ),
                Expanded(
                  child: TextField(
                    controller: _mensagemController,
                    decoration: const InputDecoration.collapsed(hintText: 'Digite sua mensagem...'),
                    onSubmitted: (_) => _submitMessage(),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                _isSendingMessage
                    ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()))
                    : IconButton(icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary), onPressed: _submitMessage),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(Object? error, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 60),
            const SizedBox(height: 20),
            Text('Erro ao Carregar Detalhes', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error)),
            Text(error.toString(), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            ElevatedButton.icon(icon: const Icon(Icons.refresh_rounded), label: const Text('Tentar Novamente'), onPressed: _loadDetails),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
    child: Text(title, style: theme.textTheme.titleLarge),
  );

  Widget _buildDetailRow(String label, String value, ThemeData theme, {Color? valueColor, FontWeight? valueFontWeight}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: Text(value.isEmpty ? 'N/A' : value, style: theme.textTheme.bodyMedium?.copyWith(color: valueColor, fontWeight: valueFontWeight))),
      ],
    ),
  );

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Não informada';
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: Theme.of(context).colorScheme.error,
    ));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: Colors.green.shade700,
    ));
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: InteractiveViewer(child: Center(child: Image.network(imageUrl))),
      ),
    );
  }
}