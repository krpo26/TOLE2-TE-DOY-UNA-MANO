import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'services.dart';

Future<void> _abrir(BuildContext context, Uri uri) async {
  final msg = ScaffoldMessenger.of(context);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('no abrió');
  } catch (_) {
    msg.showSnackBar(const SnackBar(content: Text('No se pudo abrir')));
  }
}

Uri _whatsapp(String tel) {
  var d = soloDigitos(tel);
  if (d.startsWith('0')) d = d.substring(1);
  final n = d.startsWith('54') ? d : '549$d';
  return Uri.parse('https://wa.me/$n');
}

class ContactoCard extends StatelessWidget {
  final String titulo;
  final String nombre;
  final String telefono;
  const ContactoCard({
    super.key,
    required this.titulo,
    required this.nombre,
    required this.telefono,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        title: Text('$titulo: $nombre'),
        subtitle: Text(telefono),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Llamar',
              icon: const Icon(Icons.call),
              onPressed: () =>
                  _abrir(context, Uri(scheme: 'tel', path: telefono)),
            ),
            IconButton(
              tooltip: 'WhatsApp',
              icon: const Icon(Icons.chat),
              onPressed: () => _abrir(context, _whatsapp(telefono)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contacto del profesional elegido (solo existe si el presupuesto fue aceptado).
class ContactoProfesional extends StatelessWidget {
  final String presupuestoId;
  final String nombre;
  const ContactoProfesional(
      {super.key, required this.presupuestoId, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: PedidosService().telefonoProfesional(presupuestoId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        final tel = snap.data;
        if (tel == null || tel.isEmpty) {
          return const Card(
            child: ListTile(title: Text('Contacto no disponible')),
          );
        }
        return ContactoCard(
            titulo: 'Contactá a tu profesional', nombre: nombre, telefono: tel);
      },
    );
  }
}

/// Trabajos asignados al profesional.
class MisTrabajosScreen extends StatelessWidget {
  const MisTrabajosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<SesionService>().user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis trabajos')),
      body: StreamBuilder<List<Pedido>>(
        stream: PedidosService().trabajosDe(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('No se pudieron cargar los trabajos'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(
                child: Text('Todavía no te eligieron para ningún trabajo.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final p = lista[i];
              return Card(
                child: ListTile(
                  title: Text(p.oficioNombre),
                  subtitle: Text(
                      '${p.clienteNombre} · ${p.zona}\n${pesos(p.montoAcordado ?? 0)}'),
                  isThreeLine: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TrabajoProfesionalScreen(pedido: p)),
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

class TrabajoProfesionalScreen extends StatelessWidget {
  final Pedido pedido;
  const TrabajoProfesionalScreen({super.key, required this.pedido});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajo asignado')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              title: Text(pedido.oficioNombre),
              subtitle: Text(
                  '${pedido.descripcion}\n${pedido.zona}\nAcordado: ${pesos(pedido.montoAcordado ?? 0)}'),
              isThreeLine: true,
            ),
          ),
          FutureBuilder<String?>(
            future: PedidosService().telefonoCliente(pedido.id),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              final tel = snap.data;
              if (tel == null || tel.isEmpty) {
                return const Card(
                  child: ListTile(title: Text('Contacto no disponible')),
                );
              }
              return ContactoCard(
                  titulo: 'Cliente',
                  nombre: pedido.clienteNombre,
                  telefono: tel);
            },
          ),
        ],
      ),
    );
  }
}
