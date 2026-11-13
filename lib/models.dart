import 'package:cloud_firestore/cloud_firestore.dart';

import 'legal_config.dart';

class Usuario {
  final String uid;
  final String nombre;
  final String email;
  final String rol; // cliente | profesional | admin
  final bool aceptoTerminos;
  final bool tieneTelefono;

  const Usuario({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.rol,
    this.aceptoTerminos = false,
    this.tieneTelefono = false,
  });

  bool get esAdmin => rol == 'admin';

  factory Usuario.desdeDoc(String uid, Map<String, dynamic>? d) => Usuario(
        uid: uid,
        nombre: d?['nombre'] ?? '',
        email: d?['email'] ?? '',
        rol: d?['rol'] ?? 'cliente',
        aceptoTerminos:
            d?['aceptoTerminos'] == true && d?['versionTerminos'] == kVersionTerminos,
        tieneTelefono: d?['tieneTelefono'] == true,
      );
}

class Oficio {
  final String id;
  final String nombre;
  final String descripcion;
  final bool activo;

  const Oficio({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.activo,
  });

  factory Oficio.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Oficio(
      id: doc.id,
      nombre: d['nombre'] ?? '',
      descripcion: d['descripcion'] ?? '',
      activo: d['activo'] ?? true,
    );
  }
}

class Profesional {
  final String uid;
  final String nombre;
  final String zona;
  final String descripcion;
  final int anios;
  final List<String> oficioIds;
  final bool activo;

  const Profesional({
    required this.uid,
    required this.nombre,
    required this.zona,
    required this.descripcion,
    required this.anios,
    required this.oficioIds,
    required this.activo,
  });

  factory Profesional.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Profesional(
      uid: doc.id,
      nombre: d['nombre'] ?? '',
      zona: d['zona'] ?? '',
      descripcion: d['descripcion'] ?? '',
      anios: (d['anios'] ?? 0) as int,
      oficioIds: List<String>.from(d['oficioIds'] ?? const []),
      activo: d['activo'] ?? true,
    );
  }
}

String pesos(int n) =>
    '\$${n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

class Pedido {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String oficioId;
  final String oficioNombre;
  final String descripcion;
  final String zona;
  final String estado; // abierto | asignado | cerrado
  final String? presupuestoElegidoId;
  final String? profesionalElegidoId;
  final int? montoAcordado;
  final DateTime? creado;

  const Pedido({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.oficioId,
    required this.oficioNombre,
    required this.descripcion,
    required this.zona,
    required this.estado,
    this.presupuestoElegidoId,
    this.profesionalElegidoId,
    this.montoAcordado,
    this.creado,
  });

  bool get abierto => estado == 'abierto';

  factory Pedido.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Pedido(
      id: doc.id,
      clienteId: d['clienteId'] ?? '',
      clienteNombre: d['clienteNombre'] ?? '',
      oficioId: d['oficioId'] ?? '',
      oficioNombre: d['oficioNombre'] ?? '',
      descripcion: d['descripcion'] ?? '',
      zona: d['zona'] ?? '',
      estado: d['estado'] ?? 'abierto',
      presupuestoElegidoId: d['presupuestoElegidoId'],
      profesionalElegidoId: d['profesionalElegidoId'],
      montoAcordado: (d['montoAcordado'] as num?)?.toInt(),
      creado: (d['creado'] as Timestamp?)?.toDate(),
    );
  }
}

class Presupuesto {
  final String id;
  final String pedidoId;
  final String clienteId;
  final String profesionalId;
  final String profesionalNombre;
  final int anios;
  final int monto;
  final String mensaje;
  final String estado; // pendiente | aceptado

  const Presupuesto({
    required this.id,
    required this.pedidoId,
    required this.clienteId,
    required this.profesionalId,
    required this.profesionalNombre,
    required this.anios,
    required this.monto,
    required this.mensaje,
    required this.estado,
  });

  factory Presupuesto.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Presupuesto(
      id: doc.id,
      pedidoId: d['pedidoId'] ?? '',
      clienteId: d['clienteId'] ?? '',
      profesionalId: d['profesionalId'] ?? '',
      profesionalNombre: d['profesionalNombre'] ?? '',
      anios: (d['anios'] as num?)?.toInt() ?? 0,
      monto: (d['monto'] as num?)?.toInt() ?? 0,
      mensaje: d['mensaje'] ?? '',
      estado: d['estado'] ?? 'pendiente',
    );
  }
}

String fmtPct(double p) =>
    p == p.roundToDouble() ? p.toInt().toString() : p.toString();

class Comision {
  final String id; // igual al id del pedido
  final String profesionalId;
  final String profesionalNombre;
  final String oficioNombre;
  final int montoAcordado;
  final double porcentaje;
  final int montoComision;
  final String estado; // pendiente | cobrada

  const Comision({
    required this.id,
    required this.profesionalId,
    required this.profesionalNombre,
    required this.oficioNombre,
    required this.montoAcordado,
    required this.porcentaje,
    required this.montoComision,
    required this.estado,
  });

  bool get cobrada => estado == 'cobrada';

  factory Comision.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Comision(
      id: doc.id,
      profesionalId: d['profesionalId'] ?? '',
      profesionalNombre: d['profesionalNombre'] ?? '',
      oficioNombre: d['oficioNombre'] ?? '',
      montoAcordado: (d['montoAcordado'] as num?)?.toInt() ?? 0,
      porcentaje: (d['porcentaje'] as num?)?.toDouble() ?? 0,
      montoComision: (d['montoComision'] as num?)?.toInt() ?? 0,
      estado: d['estado'] ?? 'pendiente',
    );
  }
}

String soloDigitos(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
