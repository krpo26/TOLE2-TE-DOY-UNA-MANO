import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'screens_comisiones.dart';
import 'screens_cuenta.dart';
import 'screens_contacto.dart';
import 'screens_pedidos.dart';
import 'screens_profesional.dart';
import 'services.dart';

class Puerta extends StatelessWidget {
  const Puerta({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SesionService>();
    if (s.cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (s.user == null) return const LoginScreen();
    if (s.perfil != null && !s.perfil!.aceptoTerminos) {
      return const TerminosGate();
    }
    return const HomeScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _registro = false;
  bool _acepto = false;
  bool _trabajando = false;
  String _rol = 'cliente';

  Future<void> _enviar() async {
    final sesion = context.read<SesionService>();
    final msg = ScaffoldMessenger.of(context);
    if (_registro && !_acepto) {
      msg.showSnackBar(const SnackBar(
          content: Text('Tenés que aceptar los Términos y la Política de Privacidad')));
      return;
    }
    setState(() => _trabajando = true);
    try {
      if (_registro) {
        await sesion.registrar(_nombre.text, _email.text, _pass.text, _rol);
      } else {
        await sesion.ingresar(_email.text, _pass.text);
      }
    } on FirebaseAuthException catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e.message ?? 'Error de acceso')));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.handshake, size: 72, color: Colors.orange),
                const SizedBox(height: 8),
                Text('TE DOY UNA MANO!',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                if (_registro) ...[
                  TextField(
                    controller: _nombre,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  DropdownButtonFormField<String>(
                    value: _rol,
                    decoration: const InputDecoration(labelText: 'Soy'),
                    items: const [
                      DropdownMenuItem(
                          value: 'cliente', child: Text('Cliente')),
                      DropdownMenuItem(
                          value: 'profesional',
                          child: Text('Profesional / trabajador')),
                    ],
                    onChanged: (v) => setState(() => _rol = v ?? 'cliente'),
                  ),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
                if (_registro) ...[
                  CheckboxListTile(
                    value: _acepto,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                        'Leí y acepto los Términos y Condiciones y la Política de Privacidad'),
                    onChanged: (v) => setState(() => _acepto = v ?? false),
                  ),
                  const LinksLegales(),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _trabajando ? null : _enviar,
                  child: Text(_registro ? 'Crear cuenta' : 'Ingresar'),
                ),
                TextButton(
                  onPressed: () => setState(() => _registro = !_registro),
                  child: Text(_registro
                      ? 'Ya tengo cuenta'
                      : 'No tengo cuenta, registrarme'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionService>();
    final perfil = sesion.perfil;
    final admin = perfil?.esAdmin ?? false;
    final servicio = OficiosService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TE DOY UNA MANO!'),
        actions: [
          if (admin)
            IconButton(
              tooltip: 'Cargar oficios básicos',
              icon: const Icon(Icons.playlist_add),
              onPressed: servicio.cargarBasicos,
            ),
          if (admin)
            IconButton(
              tooltip: 'Comisiones',
              icon: const Icon(Icons.paid),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminComisionesScreen()),
              ),
            ),
          if (!admin)
            IconButton(
              tooltip: 'Mis pedidos',
              icon: const Icon(Icons.receipt_long),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MisPedidosScreen()),
              ),
            ),
          if (perfil?.rol == 'profesional')
            IconButton(
              tooltip: 'Pedidos disponibles',
              icon: const Icon(Icons.work),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PedidosDisponiblesScreen()),
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.account_circle),
            onSelected: (v) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => v == 'perfil'
                    ? const PerfilProfesionalScreen()
                    : v == 'trabajos'
                        ? const MisTrabajosScreen()
                        : v == 'comisiones'
                            ? const MisComisionesScreen()
                            : const CuentaScreen(),
              ),
            ),
            itemBuilder: (_) => [
              if (perfil?.rol == 'profesional') ...const [
                PopupMenuItem(value: 'trabajos', child: Text('Mis trabajos')),
                PopupMenuItem(value: 'perfil', child: Text('Mi perfil')),
                PopupMenuItem(
                    value: 'comisiones', child: Text('Mis comisiones')),
              ],
              const PopupMenuItem(value: 'cuenta', child: Text('Mi cuenta')),
            ],
          ),
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: sesion.salir,
          ),
        ],
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => _dialogoAgregar(context, servicio),
              icon: const Icon(Icons.add),
              label: const Text('Agregar oficio'),
            )
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NuevoPedidoScreen()),
              ),
              icon: const Icon(Icons.request_quote),
              label: const Text('Pedir presupuesto'),
            ),
      body: StreamBuilder<List<Oficio>>(
        stream: servicio.todos(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('No se pudieron cargar los oficios'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista =
              snap.data!.where((o) => admin || o.activo).toList();
          if (lista.isEmpty) {
            return Center(
              child: Text(admin
                  ? 'Todavía no hay oficios. Tocá el botón de arriba para cargar los básicos.'
                  : 'Todavía no hay oficios disponibles.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final o = lista[i];
              return ListTile(
                leading: const Icon(Icons.handyman),
                title: Text(o.nombre),
                subtitle: Text(o.descripcion),
                trailing: admin
                    ? Switch(
                        value: o.activo,
                        onChanged: (v) => servicio.activar(o.id, v),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: admin
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ProfesionalesScreen(oficio: o)),
                        ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _dialogoAgregar(BuildContext context, OficiosService s) {
    final nombre = TextEditingController();
    final desc = TextEditingController();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo oficio o servicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (nombre.text.trim().isEmpty) return;
              await s.agregar(nombre.text, desc.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
