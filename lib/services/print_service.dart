// lib/services/print_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:logger/logger.dart';
import 'package:dc_app/models/ocorrencia.dart';
import 'package:dc_app/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class PrintService {
  static final _logger = Logger();

  /// Carrega uma imagem de uma URL
  static Future<pw.ImageProvider?> _loadImageFromUrl(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        // Para URLs HTTP/HTTPS, baixa a imagem e converte para MemoryImage
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          return pw.MemoryImage(response.bodyBytes);
        }
      } else {
        // Para URLs locais ou caminhos de arquivo
        final file = File(imageUrl);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return pw.MemoryImage(bytes);
        }
      }
    } catch (e) {
      _logger.w('Erro ao carregar imagem: $imageUrl', error: e);
    }
    return null;
  }

  /// Carrega todas as imagens e retorna widgets para o PDF
  static Future<List<pw.Widget>> _loadAllImages(List<String> imageUrls) async {
    final List<pw.Widget> imageWidgets = [];

    for (String imageUrl in imageUrls) {
      try {
        final image = await _loadImageFromUrl(imageUrl);
        if (image != null) {
          imageWidgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Imagem: ${imageUrl.split('/').last}',
                    style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    constraints: const pw.BoxConstraints(maxHeight: 200),
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ),
                ],
              ),
            ),
          );
        } else {
          imageWidgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                'Erro ao carregar: ${imageUrl.split('/').last}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.red),
              ),
            ),
          );
        }
      } catch (e) {
        _logger.e('Erro ao processar imagem: $imageUrl', error: e);
        imageWidgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text(
              'Erro ao processar: ${imageUrl.split('/').last}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.red),
            ),
          ),
        );
      }
    }

    return imageWidgets;
  }

  /// Gera PDF da ocorrência
  static Future<Uint8List> generateOcorrenciaPDF(Ocorrencia ocorrencia, String? nomeUsuario) async {
    try {
      final pdf = pw.Document();

      // Carrega todas as imagens primeiro
      final imageWidgets = await _loadAllImages(ocorrencia.todasAnexoUrls);

      // Formatação de datas
      String formatDate(DateTime? date) {
        if (date == null) return 'Não informado';
        return DateFormat('dd/MM/yyyy HH:mm').format(date);
      }

      // Cabeçalho
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Cabeçalho com logo/título
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'DEFESA CIVIL',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Relatório de Ocorrência',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Informações da ocorrência
                pw.Text(
                  'INFORMAÇÕES DA OCORRÊNCIA',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange,
                  ),
                ),

                pw.SizedBox(height: 10),

                // Tabela de informações
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildTableRow('ID:', ocorrencia.id.toString()),
                    _buildTableRow('Assunto:', ocorrencia.assunto),
                    _buildTableRow('Status:', ocorrencia.status),
                    _buildTableRow('Prioridade:', ocorrencia.prioridadeNome ?? 'Não informado'),
                    _buildTableRow('Tipo:', ocorrencia.tipoOcorrenciaNome ?? 'Não informado'),
                    _buildTableRow('Setor:', ocorrencia.setorNome ?? 'Não informado'),
                    _buildTableRow('Solicitante:', ocorrencia.solicitanteNome ?? 'Não informado'),
                    _buildTableRow('Responsável:', ocorrencia.responsavelNome ?? 'Não informado'),
                    _buildTableRow('Data de Início:', formatDate(ocorrencia.dataInicio)),
                    _buildTableRow('Data de Fim:', formatDate(ocorrencia.dataFim)),
                    _buildTableRow('Última Atualização:', formatDate(ocorrencia.dataUltimaAtualizacao)),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Descrição
                pw.Text(
                  'DESCRIÇÃO',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange,
                  ),
                ),

                pw.SizedBox(height: 10),

                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    ocorrencia.descricao,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),

                pw.SizedBox(height: 20),

                // Anexos (se houver)
                if (ocorrencia.todasAnexoUrls.isNotEmpty) ...[
                  pw.Text(
                    'ANEXOS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange,
                    ),
                  ),

                  pw.SizedBox(height: 10),

                  pw.Text('${ocorrencia.todasAnexoUrls.length} anexo(s) disponível(is)'),

                  pw.SizedBox(height: 10),

                  // Lista de imagens - agora usa os widgets já carregados
                  ...imageWidgets,
                ],

                pw.SizedBox(height: 30),

                // Rodapé
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Relatório gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Usuário: ${nomeUsuario ?? 'Não informado'}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      _logger.e('Erro ao gerar PDF da ocorrência', error: e);
      rethrow;
    }
  }

  /// Constrói uma linha da tabela
  static pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Imprime a ocorrência
  static Future<void> printOcorrencia(Ocorrencia ocorrencia, BuildContext context) async {
    try {
      _logger.i('Iniciando geração de PDF para impressão');

      // Gera o PDF
      final pdfBytes = await generateOcorrenciaPDF(ocorrencia, null);

      _logger.i('PDF gerado com sucesso, abrindo diálogo de impressão');

      // Abre o diálogo de impressão
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Ocorrência_${ocorrencia.id}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );

      _logger.i('Diálogo de impressão aberto com sucesso');
    } catch (e) {
      _logger.e('Erro ao imprimir ocorrência', error: e);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Salva o PDF em arquivo
  static Future<String?> saveOcorrenciaPDF(Ocorrencia ocorrencia) async {
    try {
      _logger.i('Iniciando geração de PDF para salvar');

      // Gera o PDF
      final pdfBytes = await generateOcorrenciaPDF(ocorrencia, null);

      // Define o nome do arquivo
      final fileName = 'Ocorrência_${ocorrencia.id}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

      _logger.i('PDF gerado com sucesso, salvando como: $fileName');

      // Aqui você pode implementar a lógica para salvar o arquivo
      // Por exemplo, usando path_provider para obter o diretório de documentos

      return fileName;
    } catch (e) {
      _logger.e('Erro ao salvar PDF da ocorrência', error: e);
      return null;
    }
  }
}
