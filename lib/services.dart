import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'legal_config.dart';
import 'models.dart';

final _db = FirebaseFirestore.instance;

class SesionService extends ChangeNotifier {
  User? user;
  Usuario? perfil;
  bool cargando = true;

  void escuchar() {
    FirebaseAuth.instance.authStateChanges().listen((u) async {
      user = u;
      perfil = u == null ? null : await _cargarPerfil(u);
      cargando = false;
      notifyListeners();
    });
  }

  Future<Usuario> _cargarPerfil(User u) async {
    final doc = await _db.collection('usuarios').doc(u.uid).get();
    return Usuario.desdeDoc(u.uid, doc.data());
  }

  Future<void> ingresar(String email, String pass) async {
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email.trim(), password: pass);
  }

  Future<void> registrar(
      String nombre, String email, String pass, String rol) async {
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email.trim(), password: pass);
    await _db.collection('usuarios').doc(cred.user!.uid).set({
      'nombre': nombre.trim(),
      'email': email.trim(),
      'rol': rol, // solo cliente o profesional; admin se asigna a mano
      'aceptoTerminos': true,
      'versionTerminos': kVersionTerminos,
      'aceptoEn': FieldValue.serverTimestamp(),
      'creado': FieldValue.serverTimestamp(),
    });
    perfil = await _cargarPerfil(cred.user!);
    notifyListeners();
  }

  Future<void> aceptarTerminos() async {
    final u = user!;
    await _db.collection('usuarios').doc(u.uid).set({
      'aceptoTerminos': true,
      'versionTerminos': kVersionTerminos,
      'aceptoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    perfil = await _cargarPerfil(u);
    notifyListeners();
  }

  /// Borra los datos personales del usuario y después su cuenta.
  /// Las comisiones se conservan por obligación contable.
  Future<void> eliminarCuenta(String password) async {
    final u = FirebaseAuth.instance.currentUser!;
    await u.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: u.email!, password: password));
    final uid = u.uid;
    final hijos = <DocumentReference>[
      _db.collection('profesionales').doc(uid).collection('privado').doc('contacto'),
    ];
    final padres = <DocumentReference>[
      _db.collection('profesionales').doc(uid),
    ];
    final pedidos =
        await _db.collection('pedidos').where('clienteId', isEqualTo: uid).get();
    for (final d in pedidos.docs) {
      hijos.add(d.reference.collection('privado').doc('contacto'));
      padres.add(d.reference);
    }
    for (final campo in ['profesionalId', 'clienteId']) {
      final ps = await _db
          .collection('presupuestos')
          .where(campo, isEqualTo: uid)
          .get();
      for (final d in ps.docs) {
        hijos.add(d.reference.collection('privado').doc('contacto'));
        padres.add(d.reference);
      }
    }
    padres.add(_db.collection('usuarios').doc(uid));
    // Primero los datos privados y después los documentos principales.
    final refs = [...hijos, ...padres];
    for (var i = 0; i < refs.length; i += 400) {
      final fin = i + 400 > refs.length ? refs.length : i + 400;
      final batch = _db.batch();
      for (final r in refs.sublist(i, fin)) {
        batch.delete(r);
      }
      await batch.commit();
    }
    await u.delete();
  }

  Future<void> salir() => FirebaseAuth.instance.signOut();
}

class OficiosService {
  final _col = _db.collection('oficios');

  Stream<List<Oficio>> todos() => _col
      .orderBy('nombre')
      .snapshots()
      .map((s) => s.docs.map(Oficio.desdeDoc).toList());

  Future<void> agregar(String nombre, String descripcion) => _col.add({
        'nombre': nombre.trim(),
        'descripcion': descripcion.trim(),
        'activo': true,
        'creado': FieldValue.serverTimestamp(),
      });

  Future<void> activar(String id, bool activo) =>
      _col.doc(id).update({'activo': activo});

  Future<void> cargarBasicos() async {
    const basicos = {
      'Plomero': 'Instalaciones y arreglos de agua, cañerías y sanitarios.',
      'Electricista': 'Instalaciones eléctricas, tableros y reparaciones.',
      'Gasista': 'Instalación y revisión de gas.',
      'Albañil': 'Construcción, refacciones y revoques.',
      'Pintor': 'Pintura de interiores y exteriores.',
      'Carpintero': 'Muebles, puertas y trabajos en madera.',
      'Hacer filas':
          'Hago la fila por vos en lugares con demora: bancos, trámites, '
              'oficinas y más.',
    };
    final batch = _db.batch();
    basicos.forEach((nombre, desc) {
      batch.set(_col.doc(), {
        'nombre': nombre,
        'descripcion': desc,
        'activo': true,
        'creado': FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
  }
}

class ProfesionalesService {
  final _col = _db.collection('profesionales');

  Future<Profesional?> miPerfil(String uid) async {
    final doc = await _col.doc(uid).get();
    return doc.exists ? Profesional.desdeDoc(doc) : null;
  }

  Future<String> miTelefono(String uid) async {
    try {
      final d = await _col.doc(uid).collection('privado').doc('contacto').get();
      return (d.data()?['telefono'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> guardar(
    String uid, {
    required String nombre,
    required String zona,
    required String descripcion,
    required int anios,
    required List<String> oficioIds,
    required String telefono,
  }) async {
    final existe = (await _col.doc(uid).get()).exists;
    await _col.doc(uid).set({
      'nombre': nombre.trim(),
      'zona': zona.trim(),
      'descripcion': descripcion.trim(),
      'anios': anios,
      'oficioIds': oficioIds,
      if (!existe) 'activo': true,
      'actualizado': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _col
        .doc(uid)
        .collection('privado')
        .doc('contacto')
        .set({'telefono': soloDigitos(telefono)});
  }

  Stream<List<Profesional>> porOficio(String oficioId) => _col
      .where('oficioIds', arrayContains: oficioId)
      .snapshots()
      .map((s) {
        final lista =
            s.docs.map(Profesional.desdeDoc).where((p) => p.activo).toList();
        lista.sort((a, b) => b.anios.compareTo(a.anios));
        return lista;
      });
}

class PedidosService {
  final _pedidos = _db.collection('pedidos');
  final _presu = _db.collection('presupuestos');

  List<Pedido> _ordenar(Iterable<Pedido> l) {
    final lista = l.toList();
    lista.sort((a, b) => (b.creado ?? DateTime.now())
        .compareTo(a.creado ?? DateTime.now()));
    return lista;
  }

  Future<void> crear({
    required String clienteId,
    required String clienteNombre,
    required Oficio oficio,
    required String descripcion,
    required String zona,
    required String telefono,
  }) {
    final ref = _pedidos.doc();
    final batch = _db.batch();
    batch.set(ref, {
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'oficioId': oficio.id,
      'oficioNombre': oficio.nombre,
      'descripcion': descripcion.trim(),
      'zona': zona.trim(),
      'estado': 'abierto',
      'creado': FieldValue.serverTimestamp(),
    });
    // El teléfono va aparte: solo lo ve el profesional elegido.
    batch.set(ref.collection('privado').doc('contacto'),
        {'telefono': soloDigitos(telefono)});
    return batch.commit();
  }

  Stream<Pedido> pedido(String id) =>
      _pedidos.doc(id).snapshots().map(Pedido.desdeDoc);

  Stream<List<Pedido>> misPedidos(String uid) => _pedidos
      .where('clienteId', isEqualTo: uid)
      .snapshots()
      .map((s) => _ordenar(s.docs.map(Pedido.desdeDoc)));

  Stream<List<Pedido>> disponibles(List<String> oficioIds) {
    if (oficioIds.isEmpty) return Stream.value(<Pedido>[]);
    return _pedidos
        .where('oficioId', whereIn: oficioIds.take(30).toList())
        .snapshots()
        .map((s) =>
            _ordenar(s.docs.map(Pedido.desdeDoc).where((p) => p.abierto)));
  }

  Stream<List<Presupuesto>> presupuestosDe(String pedidoId, String clienteId) =>
      _presu
          .where('pedidoId', isEqualTo: pedidoId)
          .where('clienteId', isEqualTo: clienteId)
          .snapshots()
          .map((s) {
        final l = s.docs.map(Presupuesto.desdeDoc).toList();
        l.sort((a, b) => a.monto.compareTo(b.monto));
        return l;
      });

  Future<Presupuesto?> miPresupuesto(String pedidoId, String uid) async {
    final doc = await _presu.doc('${pedidoId}_$uid').get();
    return doc.exists ? Presupuesto.desdeDoc(doc) : null;
  }

  Future<String?> telefonoCliente(String pedidoId) async {
    try {
      final d = await _pedidos
          .doc(pedidoId)
          .collection('privado')
          .doc('contacto')
          .get();
      return d.data()?['telefono'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> telefonoProfesional(String presupuestoId) async {
    try {
      final d = await _presu
          .doc(presupuestoId)
          .collection('privado')
          .doc('contacto')
          .get();
      return d.data()?['telefono'] as String?;
    } catch (_) {
      return null;
    }
  }

  Stream<List<Pedido>> trabajosDe(String uid) => _pedidos
      .where('profesionalElegidoId', isEqualTo: uid)
      .snapshots()
      .map((s) => _ordenar(s.docs.map(Pedido.desdeDoc)));

  Future<void> enviarPresupuesto({
    required Pedido pedido,
    required String profesionalId,
    required String profesionalNombre,
    required int anios,
    required int monto,
    required String mensaje,
    required String telefono,
  }) async {
    final ref = _presu.doc('${pedido.id}_$profesionalId');
    final existe = (await ref.get()).exists;
    final batch = _db.batch();
    batch.set(ref, {
      'pedidoId': pedido.id,
      'clienteId': pedido.clienteId,
      'profesionalId': profesionalId,
      'profesionalNombre': profesionalNombre,
      'anios': anios,
      'monto': monto,
      'mensaje': mensaje.trim(),
      'estado': 'pendiente',
      if (!existe) 'creado': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // El teléfono va aparte: el cliente solo lo ve si acepta este presupuesto.
    batch.set(ref.collection('privado').doc('contacto'),
        {'telefono': soloDigitos(telefono)});
    await batch.commit();
  }

  Future<void> aceptar(Pedido pedido, Presupuesto p) async {
    final pct = await ConfigService().porcentajeActual();
    final comision = (p.monto * pct / 100).floor();
    final batch = _db.batch();
    batch.update(_pedidos.doc(pedido.id), {
      'estado': 'asignado',
      'presupuestoElegidoId': p.id,
      'profesionalElegidoId': p.profesionalId,
      'montoAcordado': p.monto,
    });
    batch.update(_presu.doc(p.id), {'estado': 'aceptado'});
    batch.set(_db.collection('comisiones').doc(pedido.id), {
      'pedidoId': pedido.id,
      'clienteId': pedido.clienteId,
      'profesionalId': p.profesionalId,
      'profesionalNombre': p.profesionalNombre,
      'oficioNombre': pedido.oficioNombre,
      'montoAcordado': p.monto,
      'porcentaje': pct,
      'montoComision': comision,
      'estado': 'pendiente',
      'creado': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}

class ConfigService {
  final _doc = _db.collection('config').doc('comisiones');

  /// Porcentaje de comisión; 10 si el admin todavía no lo cambió.
  Stream<double> porcentaje() => _doc
      .snapshots()
      .map((d) => (d.data()?['porcentaje'] as num?)?.toDouble() ?? 10.0);

  Future<double> porcentajeActual() async {
    final d = await _doc.get();
    return (d.data()?['porcentaje'] as num?)?.toDouble() ?? 10.0;
  }

  Future<void> guardarPorcentaje(double pct) =>
      _doc.set({'porcentaje': pct}, SetOptions(merge: true));
}

class ComisionesService {
  final _col = _db.collection('comisiones');

  List<Comision> _ordenar(Iterable<Comision> l) {
    final lista = l.toList();
    lista.sort((a, b) {
      if (a.cobrada != b.cobrada) return a.cobrada ? 1 : -1;
      return b.montoComision.compareTo(a.montoComision);
    });
    return lista;
  }

  Stream<List<Comision>> todas() => _col
      .snapshots()
      .map((s) => _ordenar(s.docs.map(Comision.desdeDoc)));

  Stream<List<Comision>> deProfesional(String uid) => _col
      .where('profesionalId', isEqualTo: uid)
      .snapshots()
      .map((s) => _ordenar(s.docs.map(Comision.desdeDoc)));

  Future<void> marcarCobrada(String id, bool cobrada) => _col.doc(id).update({
        'estado': cobrada ? 'cobrada' : 'pendiente',
        'cobradoEn': cobrada ? FieldValue.serverTimestamp() : null,
      });
}
