import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'screens_pedidos.dart';
import 'services.dart';

/// Pantalla donde el profesional completa su perfil y elige sus oficios.
class PerfilProfesionalScreen extends StatefulWidget {
  const PerfilProfesionalScreen({super.key});

  @override
  State<PerfilProfesionalScreen> createState() =>
      _PerfilProfesionalScreenState();
}

class _PerfilProfesionalScreenState extends State<PerfilProfesionalScreen> {
  final _servicio = ProfesionalesService();
  final _zona = TextEditingController();
  final _desc = TextEditingController();
  final _anios = TextEditingController();
  final _formacion = TextEditingController();
  final _experiencia = TextEditingController();
  final _certificaciones = TextEditingController();
  final _referencias = TextEditingController();
  final Set<String> _oficios = {};
  bool? _aprobado;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = context.read<SesionService>().user!.uid;
    final p = await _servicio.miPerfil(uid);
    final cv = await _servicio.cv(uid);
    if (cv != null) {
      _formacion.text = (cv['formacion'] as String?) ?? '';
      _experiencia.text = (cv['experiencia'] as String?) ?? '';
      _certificaciones.text = (cv['certificaciones'] as String?) ?? '';
      _referencias.text = (cv['referencias'] as String?) ?? '';
    }
    _aprobado = p?.activo;
    if (p != null) {
      _zona.text = p.zona;
      _desc.text = p.descripcion;
      _anios.text = p.anios.toString();
      _oficios.addAll(p.oficioIds);
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    final sesion = context.read<SesionService>();
    final msg = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (_zona.text.trim().isEmpty ||
        _oficios.isEmpty ||
        _experiencia.text.trim().isEmpty) {
      msg.showSnackBar(const SnackBar(
          content: Text(
              'Completá tu zona, tu experiencia laboral y elegí al menos un oficio')));
      return;
    }
    setState(() => _guardando = true);
    try {
      await _servicio.guardar(
        sesion.user!.uid,
        nombre: sesion.perfil?.nombre ?? '',
        zona: _zona.text,
        descripcion: _desc.text,
        anios: int.tryParse(_anios.text.trim()) ?? 0,
        oficioIds: _oficios.toList(),
      );
      await _servicio.guardarCv(sesion.user!.uid, {
        'formacion': _formacion.text.trim(),
        'experiencia': _experiencia.text.trim(),
        'certificaciones': _certificaciones.text.trim(),
        'referencias': _referencias.text.trim(),
      });
      msg.showSnackBar(const SnackBar(content: Text('Perfil guardado')));
      nav.pop();
    } catch (_) {
      msg.showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el perfil')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil profesional')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: _aprobado == true
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  child: ListTile(
                    leading: Icon(
                        _aprobado == true ? Icons.verified : Icons.hourglass_top),
                    title: Text(_aprobado == true
                        ? 'Perfil aprobado'
                        : (_aprobado == null
                            ? 'Completá tu perfil y tu currículum'
                            : 'Tu currículum está en revisión')),
                    subtitle: Text(_aprobado == true
                        ? 'Ya aparecés en las listas y podés presupuestar.'
                        : 'Cuando el administrador lo apruebe vas a aparecer en las listas y a poder presupuestar.'),
                  ),
                ),
                TextField(
                  controller: _zona,
                  decoration: const InputDecoration(
                      labelText: 'Zona donde trabajás (barrio o ciudad)'),
                ),
                TextField(
                  controller: _anios,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Años de experiencia'),
                ),
                TextField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Contá qué trabajos hacés'),
                ),
                const SizedBox(height: 20),
                Text('Mis oficios',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                StreamBuilder<List<Oficio>>(
                  stream: OficiosService().todos(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final lista = snap.data!.where((o) => o.activo).toList();
                    return Wrap(
                      spacing: 8,
                      children: [
                        for (final o in lista)
                          FilterChip(
                            label: Text(o.nombre),
                            selected: _oficios.contains(o.id),
                            onSelected: (v) => setState(() =>
                                v ? _oficios.add(o.id) : _oficios.remove(o.id)),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('Currículum vitae',
                    style: Theme.of(context).textTheme.titleMedium),
                TextField(
                  controller: _experiencia,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Experiencia laboral (obligatorio)',
                      helperText: 'Dónde trabajaste, qué hiciste y por cuánto tiempo'),
                ),
                TextField(
                  controller: _formacion,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Formación y estudios'),
                ),
                TextField(
                  controller: _certificaciones,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Certificaciones y matrículas'),
                ),
                TextField(
                  controller: _referencias,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Referencias (nombre y contacto)',
                      helperText: 'Solo lo ve el administrador'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: const Text('Guardar perfil'),
                ),
              ],
            ),
    );
  }
}

/// Lista de profesionales de un oficio, ordenados por experiencia.
class ProfesionalesScreen extends StatelessWidget {
  final Oficio oficio;
  const ProfesionalesScreen({super.key, required this.oficio});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(oficio.nombre)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => NuevoPedidoScreen(oficioInicial: oficio)),
        ),
        icon: const Icon(Icons.request_quote),
        label: Text('Pedir presupuesto de ${oficio.nombre}'),
      ),
      body: StreamBuilder<List<Profesional>>(
        stream: ProfesionalesService().porOficio(oficio.id),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('No se pudo cargar la lista'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(
                child: Text('Todavía no hay profesionales en este oficio.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final p = lista[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(p.nombre.isEmpty
                        ? '?'
                        : p.nombre[0].toUpperCase()),
                  ),
                  title: Text(p.nombre),
                  subtitle: Text(
                      '${p.anios} años de experiencia · ${p.zona}\n${p.descripcion}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
