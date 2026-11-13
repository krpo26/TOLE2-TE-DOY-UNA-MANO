import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'apariencia_config.dart';
import 'services.dart';

/// Logo de la pantalla de inicio (o el ícono por defecto).
class LogoInicio extends StatelessWidget {
  const LogoInicio({super.key});

  @override
  Widget build(BuildContext context) {
    const icono = Icon(Icons.handshake, size: 72, color: Colors.orange);
    return StreamBuilder<Uint8List?>(
      stream: AparienciaService().imagen('logo'),
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) return icono;
        return Image.memory(b,
            height: 110, fit: BoxFit.contain, errorBuilder: (_, __, ___) => icono);
      },
    );
  }
}

/// Imagen de interfaz que se muestra arriba de la pantalla principal.
class BannerInterfaz extends StatelessWidget {
  const BannerInterfaz({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Uint8List?>(
      stream: AparienciaService().imagen('banner'),
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) return const SizedBox.shrink();
        return SizedBox(
          height: 150,
          width: double.infinity,
          child: Image.memory(b,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        );
      },
    );
  }
}

/// Panel del administrador: fuente, logo de inicio e imagen de interfaz.
class AparienciaScreen extends StatefulWidget {
  const AparienciaScreen({super.key});

  @override
  State<AparienciaScreen> createState() => _AparienciaScreenState();
}

class _AparienciaScreenState extends State<AparienciaScreen> {
  final _s = AparienciaService();
  bool _trabajando = false;

  Future<void> _subir(String id, double lado, int calidad) async {
    final msg = ScaffoldMessenger.of(context);
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: lado,
        maxHeight: lado,
        imageQuality: calidad);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.length > kMaxBytesImagen) {
      msg.showSnackBar(const SnackBar(
          content: Text('La imagen pesa más de 600 KB. Elegí una más liviana')));
      return;
    }
    setState(() => _trabajando = true);
    try {
      await _s.guardarImagen(id, bytes);
      msg.showSnackBar(const SnackBar(content: Text('Imagen guardada')));
    } catch (_) {
      msg.showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la imagen')));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Widget _seccion(String titulo, String id, double lado, int calidad) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            StreamBuilder<Uint8List?>(
              stream: _s.imagen(id),
              builder: (context, snap) {
                final b = snap.data;
                return Container(
                  height: 110,
                  width: double.infinity,
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: b == null
                      ? const Text('Sin imagen')
                      : Image.memory(b, fit: BoxFit.contain),
                );
              },
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _trabajando ? null : () => _subir(id, lado, calidad),
                  icon: const Icon(Icons.upload),
                  label: const Text('Cargar'),
                ),
                TextButton.icon(
                  onPressed: _trabajando ? null : () => _s.quitarImagen(id),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Quitar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: StreamBuilder<String>(
                stream: _s.fuente(),
                builder: (context, snap) {
                  final actual = snap.data ?? kFuenteDefecto;
                  return DropdownButtonFormField<String>(
                    value: kFuentes.contains(actual) ? actual : kFuenteDefecto,
                    decoration: const InputDecoration(
                        labelText: 'Fuente de toda la app'),
                    items: [
                      for (final f in kFuentes)
                        DropdownMenuItem(value: f, child: Text(f)),
                    ],
                    onChanged: (v) {
                      if (v != null) _s.guardarFuente(v);
                    },
                  );
                },
              ),
            ),
          ),
          _seccion('Logo de inicio', 'logo', 600, 85),
          _seccion('Imagen de interfaz (banner superior)', 'banner', 1200, 70),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
                'Cada imagen puede pesar hasta 600 KB. Los cambios se ven al instante en todos los dispositivos.'),
          ),
        ],
      ),
    );
  }
}
