// lib/screens/assigned_ocorrencias_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dc_app/models/ocorrencia.dart';
import 'package:dc_app/screens/ocorrencia_details_screen.dart';
import 'package:dc_app/services/ocorrencia_service.dart';

enum StatusFilter { todas, abertas, encerradas }

class AssignedOcorrenciasScreen extends StatefulWidget {
  const AssignedOcorrenciasScreen({super.key});
  @override
  State<AssignedOcorrenciasScreen> createState() => _AssignedOcorrenciasScreenState();
}

class _AssignedOcorrenciasScreenState extends State<AssignedOcorrenciasScreen> {
  List<Ocorrencia> _allOcorrencias = [];
  List<Ocorrencia> _displayedOcorrencias = [];
  final TextEditingController _searchController = TextEditingController();
  StatusFilter _currentFilter = StatusFilter.abertas;
  bool _isSearching = false;
  Timer? _debounce;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeOcorrencias();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initializeOcorrencias({bool forceRefresh = false}) async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final ocorrencias = await OcorrenciaService.getAssignedOcorrencias();
      if (mounted) {
        setState(() {
          _allOcorrencias = ocorrencias;
          _applyFiltersAndSearch();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSearch() {
    List<Ocorrencia> sourceList = List.from(_allOcorrencias);
    switch (_currentFilter) {
      case StatusFilter.abertas:
        sourceList.retainWhere((o) => o.status.toLowerCase() == 'aberta');
        break;
      case StatusFilter.encerradas:
        sourceList.retainWhere((o) => o.status.toLowerCase() == 'encerrada');
        break;
      case StatusFilter.todas:
      // Não faz nada, usa a lista completa
        break;
    }
    String searchTerm = _searchController.text.trim().toLowerCase();
    if (searchTerm.isNotEmpty) {
      sourceList.retainWhere((t) =>
      t.assunto.toLowerCase().contains(searchTerm) || t.id.toString().contains(searchTerm)
      );
    }
    if (mounted) setState(() => _displayedOcorrencias = sourceList);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _applyFiltersAndSearch);
  }

  Future<void> _navigateToDetails(int ocorrenciaId) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => OcorrenciaDetailsScreen(ocorrenciaId: ocorrenciaId)),
    );
    if (result == true) {
      await _initializeOcorrencias(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: () => _initializeOcorrencias(forceRefresh: true),
        child: Column(
          children: [
            _buildFilterChips(context),
            const Divider(height: 1, thickness: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: _isSearching
          ? TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration.collapsed(
          hintText: 'Pesquisar por assunto ou nº...',
          hintStyle: TextStyle(color: Colors.white70),
        ),
        style: const TextStyle(color: Colors.white),
      )
          : const Text('Ocorrências Atribuídas'),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
          onPressed: () => setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) _searchController.clear();
          }),
        ),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      child: Wrap(
        spacing: 10.0,
        children: StatusFilter.values.map((filter) {
          bool isSelected = _currentFilter == filter;
          return FilterChip(
            label: Text(filter.name[0].toUpperCase() + filter.name.substring(1)),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) setState(() {
                _currentFilter = filter;
                _applyFiltersAndSearch();
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('Erro: $_errorMessage')));
    }
    if (_displayedOcorrencias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _searchController.text.isNotEmpty
                ? 'Nenhuma ocorrência encontrada para "${_searchController.text}"'
                : 'Nenhuma ocorrência nesta categoria.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0 + MediaQuery.of(context).padding.bottom),
      itemCount: _displayedOcorrencias.length,
      itemBuilder: (context, index) {
        return _buildOcorrenciaItem(context, _displayedOcorrencias[index]);
      },
    );
  }

  Widget _buildOcorrenciaItem(BuildContext context, Ocorrencia ocorrencia) {
    final isClosed = ocorrencia.status.toLowerCase() == 'encerrada';
    final statusColor = isClosed ? Theme.of(context).colorScheme.error : Colors.green.shade700;
    final dataFormatada = DateFormat('dd/MM/yy HH:mm').format(ocorrencia.dataUltimaAtualizacao ?? ocorrencia.dataInicio ?? DateTime.now());

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        title: Text('#${ocorrencia.id} - ${ocorrencia.assunto}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Solicitante: ${ocorrencia.solicitanteNome ?? "N/A"}\nAtualizado em: $dataFormatada'),
        isThreeLine: true,
        trailing: Icon(Icons.circle, color: statusColor, size: 12),
        onTap: () => _navigateToDetails(ocorrencia.id),
      ),
    );
  }
}