// lib/widgets/autocomplete_field.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:dc_app/services/location_data_service.dart';

class AutocompleteField extends StatefulWidget {
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final String? Function(String?)? validator;
  final TextEditingController controller;
  final bool isArea; // true para área, false para local
  final Function(String)? onChanged;

  const AutocompleteField({
    super.key,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    required this.controller,
    required this.isArea,
    this.validator,
    this.onChanged,
  });

  @override
  State<AutocompleteField> createState() => _AutocompleteFieldState();
}

class _AutocompleteFieldState extends State<AutocompleteField> {
  final _logger = Logger();
  List<String> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialSuggestions();
  }

  void _loadInitialSuggestions() {
    setState(() {
      _isLoading = true;
    });

    // Carrega sugestões iniciais
    if (widget.isArea) {
      _suggestions = LocationDataService.getCommonAreas();
    } else {
      _suggestions = LocationDataService.getCommonLocais();
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) {
      _loadInitialSuggestions();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Busca sugestões baseadas no texto
    List<String> results;
    if (widget.isArea) {
      results = LocationDataService.getAreaSuggestions(text);
    } else {
      results = LocationDataService.getLocalSuggestions(text);
    }

    setState(() {
      _suggestions = results;
      _isLoading = false;
    });

    // Chama callback se fornecido
    if (widget.onChanged != null) {
      widget.onChanged!(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return _suggestions;
            }
            return _suggestions.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            widget.controller.text = selection;
            _logger.i('${widget.isArea ? 'Área' : 'Local'} selecionado: $selection');
          },
          fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                prefixIcon: Icon(widget.prefixIcon),
                border: const OutlineInputBorder(),
                suffixIcon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _onTextChanged,
              validator: widget.validator,
            );
          },
          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () {
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        
        // Indicador de validação
        if (widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildValidationIndicator(),
        ],
      ],
    );
  }

  Widget _buildValidationIndicator() {
    final text = widget.controller.text;
    bool isValid;
    
    if (widget.isArea) {
      isValid = LocationDataService.isValidArea(text);
    } else {
      isValid = LocationDataService.isValidLocal(text);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isValid ? Colors.green.shade50 : Colors.orange.shade50,
        border: Border.all(
          color: isValid ? Colors.green.shade200 : Colors.orange.shade200,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.warning,
            color: isValid ? Colors.green.shade600 : Colors.orange.shade600,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isValid 
                  ? '${widget.isArea ? 'Área' : 'Local'} válido'
                  : '${widget.isArea ? 'Área' : 'Local'} não encontrado - verifique a digitação',
              style: TextStyle(
                color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
