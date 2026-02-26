import 'dart:async';
import 'package:ecoplaycaicara/screens/games/toca-do-caranguejo/game.dart';
import 'package:ecoplaycaicara/screens/games/toca-do-caranguejo/start.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_scroll_behavior.dart';
import 'screens/games/missao-reciclagem/start.dart';
import 'theme/theme_provider.dart';
import 'screens/home.dart';
import 'services/backend_client.dart';
import 'services/asset_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    debugPrintStack(stackTrace: details.stack);
  };

  WidgetsBinding.instance.platformDispatcher.onError =
      (Object error, StackTrace stack) {
        debugPrint('PlatformDispatcher error: ${error.runtimeType} - $error');
        debugPrintStack(stackTrace: stack);
        return true;
      };

  runZonedGuarded<void>(
    () {
      runApp(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: const EcoplayCaicaraApp(),
        ),
      );
      unawaited(_primeStartupTasks());
    },
    (Object error, StackTrace stack) {
      debugPrint('Uncaught zone error: ${error.runtimeType} - $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

Future<void> _primeStartupTasks() async {
  // Evita bloquear o primeiro frame no web/Safari.
  try {
    await BackendClient.instance.clearSession();
  } catch (error, stack) {
    debugPrint('Startup clearSession falhou: $error');
    debugPrintStack(stackTrace: stack);
  }

  try {
    await AssetCache.warmUp().timeout(const Duration(seconds: 12));
  } catch (error, stack) {
    debugPrint('Startup warmUp falhou/timeout: $error');
    debugPrintStack(stackTrace: stack);
  }
}

class EcoplayCaicaraApp extends StatelessWidget {
  const EcoplayCaicaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final ThemeData baseTheme = themeProvider.currentTheme;
    final ThemeData themed = baseTheme.copyWith(
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 250),
      ),
    );

    return ColorFiltered(
      colorFilter: themeProvider.colorBlindnessFilter,
      child: MaterialApp(
        title: 'Ecoplay Caiçara',
        debugShowCheckedModeBanner: false,
        theme: themed,
        scrollBehavior: const AppScrollBehavior(),
        routes: {
          '/missao-reciclagem': (context) =>
              const MissaoReciclagemStartScreen(),
        },
        builder: (context, child) {
          final scale = themeProvider.textScale;
          final reduceMotion = themeProvider.reduceMotion;
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaleFactor: scale,
              disableAnimations: reduceMotion,
            ),
            child: child!,
          );
        },
        home: const TocaStartScreen(),
      ),
    );
  }
}
