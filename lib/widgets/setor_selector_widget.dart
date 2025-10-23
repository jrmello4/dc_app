// lib/widgets/setor_selector_widget.dart

import 'package:flutter/material.dart';
import 'package:dc_app/models/setor.dart';

class SetorSelectorWidget extends StatefulWidget {
  final List<Setor> setores;
  final Setor? selectedSetor;
  final Function(Setor?)? onSetorChanged;
  final bool showSetores;

  const SetorSelectorWidget({
    Key? key,
    required this.setores,
    this.selectedSetor,
    this.onSetorChanged,
    this.showSetores = true,
  }) : super(key: key);

  @override
  State<SetorSelectorWidget> createState() => _SetorSelectorWidgetState();
}

class _SetorSelectorWidgetState extends State<SetorSelectorWidget> {
  Setor? _selectedSetor;

  @override
  void initState() {
    super.initState();
    _selectedSetor = widget.selectedSetor;
  }

  @override
  void didUpdateWidget(SetorSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSetor != _selectedSetor) {
      setState(() {
        _selectedSetor = widget.selectedSetor;
      });
    }
  }

  void _onSetorChanged(Setor? setor) {
    setState(() {
      _selectedSetor = setor;
    });
    widget.onSetorChanged?.call(setor);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showSetores || widget.setores.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_city, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Selecionar Setor',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Lista de setores
            ...widget.setores.map((setor) {
              final isSelected = _selectedSetor?.id == setor.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _onSetorChanged(isSelected ? null : setor),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                setor.nome,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.blue.shade700 : Colors.grey.shade800,
                                ),
                              ),
                              if (setor.raio != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Raio: ${setor.raio!.toStringAsFixed(0)}m',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                              if (setor.latitude != null && setor.longitude != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Centro: ${setor.latitude!.toStringAsFixed(6)}, ${setor.longitude!.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected ? Colors.blue.shade500 : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            
            if (_selectedSetor != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Setor selecionado: ${_selectedSetor!.nome}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
