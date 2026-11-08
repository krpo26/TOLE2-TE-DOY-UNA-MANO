import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'legal_config.dart';
import 'services.dart';

Future<void> abrirUrl(BuildContext context, String url) async {
  final msg = ScaffoldMessenger.of(context);
  try {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('no abrió');
  } catch (_) {
    msg.showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace')));
  }
}

class LinksLegales extends StatelessWidget {
  const LinksLegales({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => abrirUrl(context, kUrlTerminos),
          child: const Text('Términos y Condiciones'),
        ),
        TextButton(
          onPressed: () => abrirUrl(context, kUrlPrivacidad),
          child: const Text('Política de Privacidad'),
        ),
      ],
    );
  }
}

/// Pantalla que ven los usuarios que todavía no aceptaron la versión vigente.
class TerminosGate extends StatefulWidget {
  const TerminosGate({super.key});

  @override
  State<TerminosGate> createState() => _TerminosGateState();
}

class _TerminosGateState extends State<TerminosGate> {
  bool _acepto = false;
  bool _guardando = false;

  Future<void> _aceptar() async {
    final sesion = context.read<SesionService>();
    final msg = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      await sesion.aceptarTerminos();
    } catch (_) {
      msg.showSnackBar(
          const SnackBar(content: Text('No se pudo guardar. Probá de nuevo')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gavel, size: 56, color: Colors.orange),
              const SizedBox(height: 16),
              Text('Antes de seguir',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const Text(
                'Para usar TE DOY UNA MANO! tenés que leer y aceptar los '
                'Términos y Condiciones y la Política de Privacidad.',
                textAlign: TextAlign.center,
              ),
              const LinksLegales(),
              CheckboxListTile(
                value: _acepto,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Leí y acepto ambos documentos'),
                onChanged: (v) => setState(() => _acepto = v ?? false),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: (_acepto && !_guardando) ? _aceptar : null,
                child: const Text('Aceptar y continuar'),
              ),
              TextButton(
                onPressed: context.read<SesionService>().salir,
                child: const Text('Salir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Datos de la cuenta, textos legales y eliminación de la cuenta.
class CuentaScreen extends StatelessWidget {
  const CuentaScreen({super.key});

  Future<void> _eliminar(BuildContext context) async {
    final nav = Navigator.of(context);
    final msg = ScaffoldMessenger.of(context);
    final sesion = context.read<SesionService>();
    final pass = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar mi cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Se borran tu perfil, tus pedidos y tus presupuestos. '
                'Esta acción no se puede deshacer. Se conserva solo el '
                'registro de comisiones, que la ley contable exige guardar.'),
            TextField(
              controller: pass,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Tu contraseña para confirmar'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || pass.text.isEmpty) return;
    try {
      await sesion.eliminarCuenta(pass.text);
      nav.popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      final clave = e.code == 'wrong-password' || e.code == 'invalid-credential';
      msg.showSnackBar(SnackBar(
          content: Text(clave
              ? 'Contraseña incorrecta'
              : 'No se pudo eliminar la cuenta. Probá de nuevo')));
    } catch (_) {
      msg.showSnackBar(const SnackBar(
          content: Text('No se pudo eliminar la cuenta. Probá de nuevo')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = context.watch<SesionService>().perfil;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(perfil?.nombre ?? ''),
            subtitle: Text(perfil?.email ?? ''),
          ),
          const LinksLegales(),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contacto'),
            subtitle: const Text(kEmailContacto),
          ),
          const Divider(height: 32),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => _eliminar(context),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Eliminar mi cuenta'),
          ),
        ],
      ),
    );
  }
}
