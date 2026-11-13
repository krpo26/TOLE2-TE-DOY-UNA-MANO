import 'package:firebase_core/firebase_core.dart';

/// Configuración de la versión web.
/// Firebase > Configuración del proyecto > Tus apps > Agregar app web,
/// y copiá los valores que te muestra.
const opcionesWeb = FirebaseOptions(
  apiKey: 'REEMPLAZAR',
  appId: 'REEMPLAZAR',
  messagingSenderId: 'REEMPLAZAR',
  projectId: 'REEMPLAZAR',
  authDomain: 'REEMPLAZAR.firebaseapp.com',
  storageBucket: 'REEMPLAZAR.appspot.com',
);

/// Clave de sitio reCAPTCHA v3 para App Check en la web.
/// Si la dejás vacía, App Check no se activa en la web.
const kRecaptchaSiteKey = '';
