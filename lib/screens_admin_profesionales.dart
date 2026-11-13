import 'package:flutter/material.dart';

import 'models.dart';
import 'services.dart';

/// El admin ve los profesionales registrados y aprueba a los que enviaron su CV.
class AdminProfesionalesScreen extends StatelessWidget {
  const AdminProfesionalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profesionales')),
      body: StreamBuilder<List<Profesional>>(
        stream: ProfesionalesService().todos(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('No se pudo cargar la lista'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(child: Text('Todavía no hay profesionales.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final p = lista[i];
              return Card(
                child: ListTile(
                  title: Text(p.nombre),
                  subtitle: Text('${p.zona} · ${p.anios} años de experiencia'),
                  trailing: Chip(
                    label: Text(p.activo ? 'Aprobado' : 'Pendiente'),
                    backgroundColor:
                        p.activo ? Colors.green.shade100 : Colors.orange.shade100,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ProfesionalDetalleScreen(profesional: p)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ProfesionalDetalleScreen extends StatefulWidget {
  final Profesional profesional;
  const ProfesionalDetalleScreen({super.key, required this.profesional});

  @override
  State<ProfesionalDetalleScreen> createState() =>
      _ProfesionalDetalleScreenState();
}

class _ProfesionalDetalleScreenState extends State<ProfesionalDetalleScreen> {
  final _s = ProfesionalesService();
  Map<String, dynamic>? _cv;
  late bool _activo;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _activo = widget.profesional.activo;
    _cargar();
  }

  Future<void> _cargar() async {
    _cv = await _s.cv(widget.profesional.uid);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cambiar(bool aprobar) async {
    final msg = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      await _s.setActivo(widget.profesional.uid, aprobar);
      setState(() => _activo = aprobar);
    } catch (_) {
      msg.showSnackBar(const SnackBar(content: Text('No se pudo guardar')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _bloque(String titulo, String clave) {
    final t = ((_cv?[clave] as String?) ?? '').trim();
    return Card(
      child: ListTile(
        title: Text(titulo),
        subtitle: Text(t.isEmpty ? 'Sin completar' : t),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profesional;
    return Scaffold(
      appBar: AppBar(title: Text(p.nombre)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: ListTile(
                    title: Text('${p.zona} · ${p.anios} años de experiencia'),
                    subtitle: Text(p.descripcion),
                  ),
                ),
                if (_cv == null)
                  const Card(
                    child: ListTile(
                        title: Text('Todavía no envió su currículum')),
                  )
                else ...[
                  _bloque('Formación y estudios', 'formacion'),
                  _bloque('Experiencia laboral', 'experiencia'),
                  _bloque('Certificaciones y matrículas', 'certificaciones'),
                  _bloque('Referencias', 'referencias'),
                ],
                const SizedBox(height: 12),
                if (_activo)
                  OutlinedButton(
                    onPressed: _guardando ? null : () => _cambiar(false),
                    child: const Text('Quitar aprobación'),
                  )
                else
                  FilledButton(
                    onPressed: (_guardando || _cv == null)
                        ? null
                        : () => _cambiar(true),
                    child: const Text('Aprobar y agendar'),
                  ),
              ],
            ),
    );
  }
}
