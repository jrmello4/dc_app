// lib/widgets/map_triangulation_widget.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dc_app/services/setor_location_service.dart';
import 'package:dc_app/models/setor.dart';

class MapTriangulationWidget extends StatefulWidget {
  final List<Setor> setores;
  final List<List<double>>? selectedPolygon;
  final Position? currentPosition;
  final Function(List<List<double>>)? onPolygonUpdated;
  final bool showTriangulation;
  final bool interactive;

  const MapTriangulationWidget({
    Key? key,
    required this.setores,
    this.selectedPolygon,
    this.currentPosition,
    this.onPolygonUpdated,
    this.showTriangulation = true,
    this.interactive = true,
  }) : super(key: key);

  @override
  State<MapTriangulationWidget> createState() => _MapTriangulationWidgetState();
}

class _MapTriangulationWidgetState extends State<MapTriangulationWidget> {
  List<List<double>> _polygonPoints = [];
  bool _isDrawing = false;
  String _selectedMode = 'view'; // 'view', 'draw', 'edit'

  @override
  void initState() {
    super.initState();
    if (widget.selectedPolygon != null) {
      _polygonPoints = List.from(widget.selectedPolygon!);
    }
  }

  @override
  void didUpdateWidget(MapTriangulationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPolygon != null && widget.selectedPolygon != oldWidget.selectedPolygon) {
      _polygonPoints = List.from(widget.selectedPolygon!);
    }
  }

  void _addPoint(Offset offset, Size canvasSize) {
    if (!_isDrawing || _selectedMode != 'draw') return;

    // Converte coordenadas da tela para coordenadas geográficas
    // Esta é uma conversão simplificada - em um app real, você usaria uma biblioteca de mapas
    double lat = _screenToLatitude(offset.dy, canvasSize);
    double lon = _screenToLongitude(offset.dx, canvasSize);

    setState(() {
      _polygonPoints.add([lat, lon]);
    });

    widget.onPolygonUpdated?.call(_polygonPoints);
  }

  void _removeLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
      });
      widget.onPolygonUpdated?.call(_polygonPoints);
    }
  }

  void _clearPolygon() {
    setState(() {
      _polygonPoints.clear();
    });
    widget.onPolygonUpdated?.call(_polygonPoints);
  }

  void _closePolygon() {
    if (_polygonPoints.length >= 3) {
      setState(() {
        _polygonPoints.add(_polygonPoints.first); // Fecha o polígono
      });
      widget.onPolygonUpdated?.call(_polygonPoints);
    }
  }

  double _screenToLatitude(double y, Size canvasSize) {
    // Conversão simplificada - em um app real, você usaria projeção de mapa
    if (widget.currentPosition == null) return 0.0;
    
    double latRange = 0.01; // Aproximadamente 1km
    double normalizedY = y / canvasSize.height;
    return widget.currentPosition!.latitude + (normalizedY - 0.5) * latRange;
  }

  double _screenToLongitude(double x, Size canvasSize) {
    // Conversão simplificada - em um app real, você usaria projeção de mapa
    if (widget.currentPosition == null) return 0.0;
    
    double lonRange = 0.01; // Aproximadamente 1km
    double normalizedX = x / canvasSize.width;
    return widget.currentPosition!.longitude + (normalizedX - 0.5) * lonRange;
  }

  Offset _latLonToScreen(double lat, double lon, Size canvasSize) {
    if (widget.currentPosition == null) return Offset.zero;
    
    double latRange = 0.01;
    double lonRange = 0.01;
    
    double normalizedLat = (lat - widget.currentPosition!.latitude) / latRange + 0.5;
    double normalizedLon = (lon - widget.currentPosition!.longitude) / lonRange + 0.5;
    
    return Offset(
      normalizedLon * canvasSize.width,
      normalizedLat * canvasSize.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Controles
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'view', label: Text('Visualizar')),
                      ButtonSegment(value: 'draw', label: Text('Desenhar')),
                      ButtonSegment(value: 'edit', label: Text('Editar')),
                    ],
                    selected: {_selectedMode},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _selectedMode = selection.first;
                        _isDrawing = _selectedMode == 'draw';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                if (_selectedMode == 'draw') ...[
                  IconButton(
                    onPressed: _removeLastPoint,
                    icon: const Icon(Icons.undo),
                    tooltip: 'Desfazer último ponto',
                  ),
                  IconButton(
                    onPressed: _clearPolygon,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Limpar polígono',
                  ),
                  IconButton(
                    onPressed: _closePolygon,
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar polígono',
                  ),
                ],
              ],
            ),
          ),

          // Mapa simulado
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTapDown: (details) {
                    if (widget.interactive) {
                      _addPoint(details.localPosition, context.size!);
                    }
                  },
                  child: CustomPaint(
                    painter: MapPainter(
                      setores: widget.setores,
                      currentPosition: widget.currentPosition,
                      polygonPoints: _polygonPoints,
                      showTriangulation: widget.showTriangulation,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),

          // Informações do polígono
          if (_polygonPoints.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informações do Polígono:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Pontos: ${_polygonPoints.length}'),
                      ),
                      Expanded(
                        child: Text('Área: ${SetorLocationService.calculatePolygonArea(_polygonPoints).toStringAsFixed(2)} m²'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Perímetro: ${SetorLocationService.calculatePolygonPerimeter(_polygonPoints).toStringAsFixed(2)} m'),
                      ),
                      Expanded(
                        child: Text('Válido: ${SetorLocationService.isValidPolygon(_polygonPoints) ? "Sim" : "Não"}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  final List<Setor> setores;
  final Position? currentPosition;
  final List<List<double>> polygonPoints;
  final bool showTriangulation;

  MapPainter({
    required this.setores,
    this.currentPosition,
    required this.polygonPoints,
    this.showTriangulation = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue.shade100;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Desenha o fundo
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Desenha os setores
    for (int i = 0; i < setores.length; i++) {
      final setor = setores[i];
      if (setor.latitude != null && setor.longitude != null) {
        final center = _latLonToScreen(setor.latitude!, setor.longitude!, size);
        
        // Desenha círculo do setor
        strokePaint.color = Colors.blue.shade400;
        canvas.drawCircle(center, 20, strokePaint);
        
        // Desenha raio do setor se disponível
        if (setor.raio != null) {
          final radius = (setor.raio! / 111320.0) * size.width; // Conversão simplificada
          strokePaint.color = Colors.blue.shade300;
          strokePaint.style = PaintingStyle.stroke;
          canvas.drawCircle(center, radius, strokePaint);
        }
      }
    }

    // Desenha posição atual
    if (currentPosition != null) {
      final center = _latLonToScreen(currentPosition!.latitude, currentPosition!.longitude, size);
      strokePaint.color = Colors.red;
      strokePaint.style = PaintingStyle.fill;
      canvas.drawCircle(center, 8, strokePaint);
    }

    // Desenha polígono selecionado
    if (polygonPoints.isNotEmpty) {
      final path = Path();
      bool isFirst = true;
      
      for (final point in polygonPoints) {
        final screenPoint = _latLonToScreen(point[0], point[1], size);
        if (isFirst) {
          path.moveTo(screenPoint.dx, screenPoint.dy);
          isFirst = false;
        } else {
          path.lineTo(screenPoint.dx, screenPoint.dy);
        }
      }
      
      if (polygonPoints.length > 2) {
        path.close();
      }

      // Preenche o polígono
      paint.color = Colors.green.withOpacity(0.3);
      canvas.drawPath(path, paint);

      // Desenha borda do polígono
      strokePaint.color = Colors.green;
      strokePaint.style = PaintingStyle.stroke;
      canvas.drawPath(path, strokePaint);

      // Desenha pontos do polígono
      for (final point in polygonPoints) {
        final screenPoint = _latLonToScreen(point[0], point[1], size);
        strokePaint.color = Colors.green;
        strokePaint.style = PaintingStyle.fill;
        canvas.drawCircle(screenPoint, 4, strokePaint);
      }
    }

    // Desenha triangulação se habilitada
    if (showTriangulation && polygonPoints.length >= 3) {
      _drawTriangulation(canvas, size);
    }
  }

  void _drawTriangulation(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.orange.withOpacity(0.5);

    // Triangulação simples (não é Delaunay real)
    for (int i = 0; i < polygonPoints.length - 2; i++) {
      for (int j = i + 1; j < polygonPoints.length - 1; j++) {
        for (int k = j + 1; k < polygonPoints.length; k++) {
          final p1 = _latLonToScreen(polygonPoints[i][0], polygonPoints[i][1], size);
          final p2 = _latLonToScreen(polygonPoints[j][0], polygonPoints[j][1], size);
          final p3 = _latLonToScreen(polygonPoints[k][0], polygonPoints[k][1], size);

          canvas.drawLine(p1, p2, paint);
          canvas.drawLine(p2, p3, paint);
          canvas.drawLine(p3, p1, paint);
        }
      }
    }
  }

  Offset _latLonToScreen(double lat, double lon, Size size) {
    if (currentPosition == null) return Offset.zero;
    
    double latRange = 0.01;
    double lonRange = 0.01;
    
    double normalizedLat = (lat - currentPosition!.latitude) / latRange + 0.5;
    double normalizedLon = (lon - currentPosition!.longitude) / lonRange + 0.5;
    
    return Offset(
      normalizedLon * size.width,
      normalizedLat * size.height,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
