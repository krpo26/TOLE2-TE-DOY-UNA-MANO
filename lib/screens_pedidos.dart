import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'screens_contacto.dart';
import 'services.dart';

String _etiquetaEstado(String e) =>
    e == 'abierto' ? 'Abierto' : (e == 'asignado' ? 'Asignado' : 'Cerrado');

class _CabeceraPedido extends StatelessWidget {
  final Pedido p;
  const _CabeceraPedido(this.p);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(p.oficioNombre),
        subtitle: Text('${p.descripcion}\n${p.zona}'),
        isThreeLine: true,
        trailing: Chip(label: Text(_etiquetaEstado(p.estado))),
      ),
    );
  }
}

/// El cliente describe el trabajo que necesita.
class NuevoPedidoScreen extends StatefulWidget {
  final Oficio? oficioInicial;
  const NuevoPedidoScreen({super.key, this.oficioInicial});

  @override
  State<NuevoPedidoScreen> createState() => _NuevoPedidoScreenState();
}

class _NuevoPedidoScreenState extends State<NuevoPedidoScreen> {
  final _desc = TextEditingController();
  final _zona = TextEditingController();
  final _tel = TextEditingController();
  List<Oficio> _lista = [];
  String? _oficioId;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _oficioId = widget.oficioInicial?.id;
  }

  Future<void> _enviar() async {
    final sesion = context.read<SesionService>();
    final msg = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final oficio = _lista.where((o) => o.id == _oficioId).firstOrNull;
    if (oficio == null ||
        _desc.text.trim().isEmpty ||
        _zona.text.trim().isEmpty ||
        soloDigitos(_tel.text).length < 8) {
      msg.showSnackBar(const SnackBar(
          content: Text('Elegí el oficio y completá descripción, zona y teléfono')));
      return;
    }
    setState(() => _enviando = true);
    try {
      await PedidosService().crear(
        clienteId: sesion.user!.uid,
        clienteNombre: sesion.perfil?.nombre ?? '',
        oficio: oficio,
        descripcion: _desc.text,
        zona: _zona.text,
        telefono: _tel.text,
      );
      msg.showSnackBar(const SnackBar(
          content: Text('Pedido enviado. Los profesionales ya pueden presupuestar')));
      nav.pop();
    } catch (_) {
      msg.showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el pedido')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedir presupuesto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<List<Oficio>>(
            stream: OficiosService().todos(),
            builder: (context, snap) {
              _lista = (snap.data ?? []).where((o) => o.activo).toList();
              final valor =
                  _lista.any((o) => o.id == _oficioId) ? _oficioId : null;
              return DropdownButtonFormField<String>(
                value: valor,
                decoration: const InputDecoration(labelText: 'Qué necesitás'),
                items: [
                  for (final o in _lista)
                    DropdownMenuItem(value: o.id, child: Text(o.nombre)),
                ],
                onChanged: (v) => setState(() => _oficioId = v),
              );
            },
          ),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Describí el trabajo a realizar'),
          ),
          TextField(
            controller: _zona,
            decoration:
                const InputDecoration(labelText: 'Dónde (barrio o ciudad)'),
          ),
          TextField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Tu teléfono (con código de área, sin 0 ni 15)',
              helperText: 'Solo lo ve el profesional que elijas',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            child: const Text('Enviar pedido'),
          ),
        ],
      ),
    );
  }
}

/// Lista de pedidos del usuario.
class MisPedidosScreen extends StatelessWidget {
  const MisPedidosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<SesionService>().user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pedidos')),
      body: StreamBuilder<List<Pedido>>(
        stream: PedidosService().misPedidos(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('No se pudieron cargar los pedidos'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(child: Text('Todavía no hiciste pedidos.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final p = lista[i];
              return Card(
                child: ListTile(
                  title: Text(p.oficioNombre),
                  subtitle: Text(p.descripcion,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Chip(label: Text(_etiquetaEstado(p.estado))),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PedidoClienteScreen(pedidoId: p.id)),
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

/// El cliente ve los presupuestos recibidos y elige uno.
class PedidoClienteScreen extends StatelessWidget {
  final String pedidoId;
  const PedidoClienteScreen({super.key, required this.pedidoId});

  Future<void> _elegir(BuildContext context, Pedido p, Presupuesto pr) async {
    final msg = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elegir profesional'),
        content: Text(
            '¿Aceptás el presupuesto de ${pr.profesionalNombre} por ${pesos(pr.monto)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aceptar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PedidosService().aceptar(p, pr);
    } catch (_) {
      msg.showSnackBar(
          const SnackBar(content: Text('No se pudo aceptar el presupuesto')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicio = PedidosService();
    final uid = context.read<SesionService>().user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi pedido')),
      body: StreamBuilder<Pedido>(
        stream: servicio.pedido(pedidoId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _CabeceraPedido(p),
              const SizedBox(height: 12),
              Text('Presupuestos recibidos',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              StreamBuilder<List<Presupuesto>>(
                stream: servicio.presupuestosDe(p.id, uid),
                builder: (context, s2) {
                  if (!s2.hasData) return const LinearProgressIndicator();
                  final lista = s2.data!;
                  if (lista.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'Todavía no recibiste presupuestos. Te van a llegar acá.'),
                    );
                  }
                  final aceptado =
                      lista.where((x) => x.estado == 'aceptado').firstOrNull;
                  return Column(
                    children: [
                      if (aceptado != null)
                        ContactoProfesional(
                          presupuestoId: aceptado.id,
                          nombre: aceptado.profesionalNombre,
                        ),
                      for (final pr in lista)
                        Card(
                          child: ListTile(
                            title: Text(
                                '${pr.profesionalNombre} · ${pesos(pr.monto)}'),
                            subtitle: Text(
                                '${pr.anios} años de experiencia\n${pr.mensaje}'),
                            isThreeLine: true,
                            trailing: pr.estado == 'aceptado'
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : (p.abierto
                                    ? FilledButton(
                                        onPressed: () => _elegir(context, p, pr),
                                        child: const Text('Elegir'),
                                      )
                                    : null),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// El profesional ve los pedidos abiertos de sus oficios.
class PedidosDisponiblesScreen extends StatelessWidget {
  const PedidosDisponiblesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<SesionService>().user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos disponibles')),
      body: FutureBuilder<Profesional?>(
        future: ProfesionalesService().miPerfil(uid),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final pro = snap.data;
          if (pro == null) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'Primero completá tu perfil profesional (ícono de perfil arriba) para ver pedidos.'),
            ));
          }
          return StreamBuilder<List<Pedido>>(
            stream: PedidosService().disponibles(pro.oficioIds),
            builder: (context, s2) {
              if (s2.hasError) {
                return const Center(child: Text('No se pudieron cargar los pedidos'));
              }
              if (!s2.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final lista = s2.data!;
              if (lista.isEmpty) {
                return const Center(
                    child: Text('No hay pedidos abiertos para tus oficios.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: lista.length,
                itemBuilder: (context, i) {
                  final p = lista[i];
                  return Card(
                    child: ListTile(
                      title: Text(p.oficioNombre),
                      subtitle: Text('${p.descripcion}\n${p.zona}',
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      isThreeLine: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                PedidoProfesionalScreen(pedido: p, pro: pro)),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// El profesional envía (o corrige) su presupuesto.
class PedidoProfesionalScreen extends StatefulWidget {
  final Pedido pedido;
  final Profesional pro;
  const PedidoProfesionalScreen(
      {super.key, required this.pedido, required this.pro});

  @override
  State<PedidoProfesionalScreen> createState() =>
      _PedidoProfesionalScreenState();
}

class _PedidoProfesionalScreenState extends State<PedidoProfesionalScreen> {
  final _monto = TextEditingController();
  final _mensaje = TextEditingController();
  Presupuesto? _actual;
  String _telefono = '';
  bool _cargando = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final p = await PedidosService()
        .miPresupuesto(widget.pedido.id, widget.pro.uid);
    _telefono = await ProfesionalesService().miTelefono(widget.pro.uid);
    if (p != null) {
      _actual = p;
      _monto.text = p.monto.toString();
      _mensaje.text = p.mensaje;
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _enviar() async {
    final msg = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (soloDigitos(_telefono).length < 8) {
      msg.showSnackBar(const SnackBar(
          content: Text('Cargá tu teléfono en tu perfil para poder presupuestar')));
      return;
    }
    final monto = int.tryParse(_monto.text.replaceAll('.', '').trim());
    if (monto == null || monto <= 0) {
      msg.showSnackBar(
          const SnackBar(content: Text('Ingresá un monto válido en pesos')));
      return;
    }
    setState(() => _enviando = true);
    try {
      await PedidosService().enviarPresupuesto(
        pedido: widget.pedido,
        profesionalId: widget.pro.uid,
        profesionalNombre: widget.pro.nombre,
        anios: widget.pro.anios,
        monto: monto,
        mensaje: _mensaje.text,
        telefono: _telefono,
      );
      msg.showSnackBar(const SnackBar(content: Text('Presupuesto enviado')));
      nav.pop();
    } catch (_) {
      msg.showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el presupuesto')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloqueado = _actual?.estado == 'aceptado';
    return Scaffold(
      appBar: AppBar(title: const Text('Presupuestar')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _CabeceraPedido(widget.pedido),
                const SizedBox(height: 12),
                if (bloqueado)
                  const Text('Tu presupuesto fue aceptado.')
                else ...[
                  TextField(
                    controller: _monto,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Tu precio por el trabajo (en pesos)'),
                  ),
                  TextField(
                    controller: _mensaje,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Mensaje para el cliente (opcional)'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _enviando ? null : _enviar,
                    child: Text(_actual == null
                        ? 'Enviar presupuesto'
                        : 'Actualizar presupuesto'),
                  ),
                ],
              ],
            ),
    );
  }
}
