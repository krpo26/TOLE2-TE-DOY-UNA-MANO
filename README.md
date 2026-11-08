# TE DOY UNA MANO!
1. Crear repo nuevo en GitHub y subir estos archivos (carpeta lib/, pubspec.yaml, codemagic.yaml, firestore.rules).
2. Firebase: proyecto nuevo, app Android con paquete com.tedoyunamano.te_doy_una_mano, activar Auth (email/contraseña) y Firestore, pegar firestore.rules.
3. Codemagic: grupo de variables firebase_tdum con GOOGLE_SERVICES_JSON (contenido del google-services.json).
4. Para ser admin: en Firestore, usuarios/<tu uid>, cambiar el campo rol a "admin".

## Antes de publicar en Google Play
1. Editar `lib/legal_config.dart`: links públicos de Términos, Privacidad y eliminación de cuenta, y el email de contacto.
2. Codemagic > Code signing identities > Android keystores: generar un keystore, guardarlo con la referencia `tdum_keystore`.
3. Firebase > App Check: registrar la app con Play Integrity. Activar "Enforce" en Firestore y Authentication recién cuando la app ya esté en la prueba cerrada de Play.
4. Pegar `firestore.rules` en Firebase.
