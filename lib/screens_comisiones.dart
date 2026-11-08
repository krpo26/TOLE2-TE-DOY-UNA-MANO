import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'services.dart';

class _Resumen extends StatelessWidget {
  final List<Comision> lista;
  const _Resumen(this.lista);

  @override
  Widget build(BuildContext context) {
    final pendiente = lista
        .where((c) => !c.cobrada)
        .fold<int>(0, (a, c) => a + c.montoComision);
    final cobrado = lista
        .where((c) => c.cobrada)
        .fold<int>(0, (a, c) => a + c.montoComision);
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                const Text('Pendiente'),
                Text(pesos(pendiente),
                    style: Theme.of(context).textTheme.titleLarge),
              ]),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                const Text('Cobrado'),
                Text(pesos(cobrado),
                    style: Theme.of(context).textTheme.titleLarge),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Panel del admin: porcentaje y comisiones de todos los trabajos.
class AdminComisionesScreen extends StatelessWidget {
  const AdminComisionesScreen({super.key});

  Future<void> _cambiarPorcentaje(BuildContext context, double actual) {
    final c = TextEditingController(text: fmtPct(actual));
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Porcentaje de comisión'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Porcentaje (0 a 100)',
            helperText: 'Se aplica a los trabajos que se acepten desde ahora',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(c.text.replaceAll(',', '.').trim());
              if (v == null || v < 0 || v > 100) return;
              await ConfigService().guardarPorcentaje(v);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicio = ComisionesService();
    return Scaffold(
      appBar: AppBar(title: const Text('Comisiones')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          StreamBuilder<double>(
            stream: ConfigService().porcentaje(),
            builder: (context, snap) {
              final pct = snap.data ?? 10.0;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.percent),
                  title: Text('Comisión actual: ${fmtPct(pct)}%'),
                  trailing: TextButton(
                    onPressed: () => _cambiarPorcentaje(context, pct),
                    child: const Text('Cambiar'),
                  ),
                ),
              );
            },
          ),
          StreamBuilder<List<Comision>>(
            stream: servicio.todas(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('No se pudieron cargar las comisiones');
              }
              if (!snap.hasData) return const LinearProgressIndicator();
              final lista = snap.data!;
              return Column(
                children: [
                  _Resumen(lista),
                  if (lista.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Todavía no hay trabajos asignados.'),
                    ),
                  for (final c in lista)
                    Card(
                      child: ListTile(
                        title: Text(
                            '${c.profesionalNombre} · ${c.oficioNombre}'),
                        subtitle: Text(
                            'Trabajo ${pesos(c.montoAcordado)} · ${fmtPct(c.porcentaje)}% = ${pesos(c.montoComision)}'),
                        trailing: c.cobrada
                            ? IconButton(
                                tooltip: 'Marcar como pendiente',
                                icon: const Icon(Icons.check_circle,
                                    color: Colors.green),
                                onPressed: () =>
                                    servicio.marcarCobrada(c.id, false),
                              )
                            : TextButton(
                                onPressed: () =>
                                    servicio.marcarCobrada(c.id, true),
                                child: const Text('Cobrada'),
                              ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// El profesional ve cuánto le corresponde pagar de comisión.
class MisComisionesScreen extends StatelessWidget {
  const MisComisionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<SesionService>().user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis comisiones')),
      body: StreamBuilder<List<Comision>>(
        stream: ComisionesService().deProfesional(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
                child: Text('No se pudieron cargar las comisiones'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _Resumen(lista),
              if (lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Todavía no tenés trabajos asignados.'),
                ),
              for (final c in lista)
                Card(
                  child: ListTile(
                    title: Text(c.oficioNombre),
                    subtitle: Text(
                        'Trabajo ${pesos(c.montoAcordado)} · comisión ${fmtPct(c.porcentaje)}% = ${pesos(c.montoComision)}'),
                    trailing: Chip(
                        label: Text(c.cobrada ? 'Pagada' : 'A pagar')),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
