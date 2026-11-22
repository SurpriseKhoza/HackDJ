import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'audio/engine.dart';
import 'ui/dj_screen.dart';
import 'ui/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  Object? startupError;
  try {
    await DjEngine.instance.init();
  } catch (e) {
    startupError = e;
  }
  runApp(HackDjApp(startupError: startupError));
}

class HackDjApp extends StatelessWidget {
  const HackDjApp({super.key, this.startupError});

  final Object? startupError;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'HackDJ',
      color: Palette.bg,
      debugShowCheckedModeBanner: false,
      textStyle: const TextStyle(color: Palette.text, fontSize: 14),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
      home: startupError == null
          ? const DjScreen()
          : ColoredBox(
              color: Palette.bg,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'HackDJ could not start the audio engine:\n$startupError',
                    textAlign: TextAlign.center,
                    style: ts(14, color: Palette.rec),
                  ),
                ),
              ),
            ),
    );
  }
}
