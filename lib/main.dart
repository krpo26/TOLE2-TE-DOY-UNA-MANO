import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'apariencia_config.dart';
import 'firebase_options_web.dart';
import 'screens.dart';
import 'services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(options: opcionesWeb);
  } else {
    await Firebase.initializeApp();
  }
  try {
    // Solo la app original (Play Store o tu página web) puede usar tu Firebase.
    if (kIsWeb) {
      if (kRecaptchaSiteKey.isNotEmpty) {
        await FirebaseAppCheck.instance
            .activate(webProvider: ReCaptchaV3Provider(kRecaptchaSiteKey));
      }
    } else {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      );
    }
  } catch (_) {
    // Si App Check falla, la app sigue; la protección la impone Firebase.
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => SesionService()..escuchar(),
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: AparienciaService().fuente(),
      builder: (context, snap) {
        final fuente = snap.data ?? kFuenteDefecto;
        final base = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        );
        return MaterialApp(
          title: 'TE DOY UNA MANO!',
          debugShowCheckedModeBanner: false,
          theme: fuente == kFuenteDefecto
              ? base
              : base.copyWith(
                  textTheme: GoogleFonts.getTextTheme(fuente, base.textTheme)),
          // En pantallas anchas (web) el contenido queda centrado y angosto.
          builder: (context, child) => ColoredBox(
            color: const Color(0xFFEFEFEF),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: child,
              ),
            ),
          ),
          home: const Puerta(),
        );
      },
    );
  }
}
