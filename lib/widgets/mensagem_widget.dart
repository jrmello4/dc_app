// lib/widgets/mensagem_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dc_app/models/mensagem.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MensagemWidget extends StatelessWidget {
  final Mensagem mensagem;
  final bool isMe;

  const MensagemWidget({
    super.key,
    required this.mensagem,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isMe ? theme.colorScheme.primary.withOpacity(0.9) : theme.colorScheme.surface;
    final textColor = isMe ? Colors.white : theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Card(
                  elevation: 1,
                  color: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                      bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? 'Você' : mensagem.nomeUsuario ?? 'Usuário',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (mensagem.imageUrl != null && mensagem.imageUrl!.isNotEmpty)
                          _buildImageAttachment(context, mensagem.imageUrl!),
                        if (mensagem.texto.isNotEmpty)
                          Text(
                            mensagem.texto,
                            style: TextStyle(color: textColor, fontSize: 15),
                          ),
                        const SizedBox(height: 5),
                        Text(
                          DateFormat('HH:mm').format(mensagem.dataCriacao ?? DateTime.now()),
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageAttachment(BuildContext context, String imageUrl) {
    return GestureDetector(
      onTap: () => _showImageDialog(context, imageUrl),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
            fit: BoxFit.cover,
            height: 150,
            width: double.infinity,
          ),
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}