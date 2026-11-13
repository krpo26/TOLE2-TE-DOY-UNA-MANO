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

## Versión web (sin instalar nada)
1. Firebase > Configuración del proyecto > Agregar app web: copiar los valores a `lib/firebase_options_web.dart`.
2. Firebase > Hosting: activarlo (Comenzar).
3. Google Cloud > IAM > Cuentas de servicio: crear una con rol "Administrador de Firebase Hosting", generar una clave JSON y pegarla en Codemagic como variable `FIREBASE_SERVICE_ACCOUNT`; agregar también `FIREBASE_PROJECT_ID`.
4. Correr el workflow "TE DOY UNA MANO - Web". La página queda en `https://TU-PROYECTO.web.app`.
5. Si activás App Check con "Enforce": crear una clave reCAPTCHA v3 y pegarla en `kRecaptchaSiteKey`, o la web dejará de funcionar.
6. Google Cloud > Credenciales: restringir la API key web al dominio de tu página.

## Administrador
En la pantalla de inicio: "Ingresar como administrador". La cuenta debe tener `rol: admin` en Firestore. La contraseña vive solo en Firebase Authentication, nunca en el código.

## Registro y aprobación de profesionales
- Todos los usuarios cargan email, contraseña y celular al registrarse.
- Los profesionales completan su currículum en "Mi perfil y CV". Quedan "Pendientes" y no aparecen en las listas ni pueden presupuestar hasta que el administrador los apruebe en Menú > Profesionales.
- Los profesionales que ya estaban aprobados siguen aprobados. Los usuarios anteriores deberán cargar su celular al entrar.

## Verificación de email
- Al registrarse se envía un email de confirmación. Hasta que lo confirmen, los usuarios ven una pantalla que se lo pide (el administrador está exceptuado).
- Firebase también exige el email confirmado para crear pedidos y presupuestos.
- En Firebase > Authentication > Plantillas, poné el idioma en español y personalizá el texto del email de verificación.
