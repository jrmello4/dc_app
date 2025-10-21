// lib/screens/ocorrencia_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dc_app/models/ocorrencia.dart';
import 'package:dc_app/screens/ocorrencia_details_screen.dart';
import 'package:dc_app/services/ocorrencia_service.dart';

enum StatusFilter { todas, abertas, encerradas }

class OcorrenciaListScreen extends StatefulWidget {
  const OcorrenciaListScreen({super.key});
  @override
  State<OcorrenciaListScreen> createState() => _OcorrenciaListScreenState();
}

class _OcorrenciaListScreenState extends State<OcorrenciaListScreen> {
  final List<Ocorrencia> _openOcorrencias = [];
  final List<Ocorrencia> _closedOcorrencias = [];
  List<Ocorrencia> _displayedOcorrencias = [];

  final TextEditingController _searchController = TextEditingController();
  StatusFilter _currentFilter = StatusFilter.abertas;
  bool _isSearching = false;
  Timer? _debounce;

  bool _isLoadingOpen = true;
  bool _isLoadingClosed = true;
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
    if (forceRefresh) {
      _errorMessage = null;
    }
    setState(() {
      _isLoadingOpen = true;
      _isLoadingClosed = true;
    });
    // Carrega as listas de ocorrências abertas e encerradas em paralelo.
    await Future.wait([
      _fetchOcorrenciasByStatus('0', forceRefresh: forceRefresh), // '0' para Abertas
      _fetchOcorrenciasByStatus('1', forceRefresh: forceRefresh)  // '1' para Encerradas
    ]);
  }

  Future<void> _fetchOcorrenciasByStatus(String status, {bool forceRefresh = false}) async {
    try {
      final List<Ocorrencia> ocorrencias = await OcorrenciaService.getOcorrenciasByStatus(status);
      if (mounted) {
        ocorrencias.sort((a, b) => (b.dataInicio ?? DateTime(0)).compareTo(a.dataInicio ?? DateTime(0)));
        setState(() {
          if (status == '0') {
            _openOcorrencias..clear()..addAll(ocorrencias);
          } else {
            _closedOcorrencias..clear()..addAll(ocorrencias);
          }
          _applyFiltersAndSearch();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          if (status == '0') _isLoadingOpen = false;
          else _isLoadingClosed = false;
        });
      }
    }
  }

  void _applyFiltersAndSearch() {
    List<Ocorrencia> sourceList;
    switch (_currentFilter) {
      case StatusFilter.abertas:
        sourceList = List.from(_openOcorrencias);
        break;
      case StatusFilter.encerradas:
        sourceList = List.from(_closedOcorrencias);
        break;
      case StatusFilter.todas:
        sourceList = [..._openOcorrencias, ..._closedOcorrencias];
        sourceList.sort((a, b) => (b.dataInicio ?? DateTime(0)).compareTo(a.dataInicio ?? DateTime(0)));
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
    // Se o estado de uma ocorrência mudou na tela de detalhes, recarrega a lista.
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
          : const Text('Minhas Ocorrências'),
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
    final bool isLoading = (_currentFilter == StatusFilter.abertas && _isLoadingOpen) ||
        (_currentFilter == StatusFilter.encerradas && _isLoadingClosed) ||
        (_currentFilter == StatusFilter.todas && (_isLoadingOpen || _isLoadingClosed));

    if (isLoading && _displayedOcorrencias.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _openOcorrencias.isEmpty && _closedOcorrencias.isEmpty) {
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
        subtitle: Text('Atualizado em: $dataFormatada'),
        trailing: Icon(Icons.circle, color: statusColor, size: 12),
        onTap: () => _navigateToDetails(ocorrencia.id),
      ),
    );
  }
}