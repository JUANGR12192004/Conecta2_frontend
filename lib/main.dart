import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// OJO: respeta las mayúsculas/minúsculas EXACTAS de tus archivos/clases
import 'pages/Login.dart';
import 'pages/RegisterWorker.dart';
import 'pages/RegisterClient.dart';
import 'pages/ClientHome.dart';
import 'pages/WorkerHome.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // ✅ Localizations para DatePicker, etc.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'CO'),
        Locale('es', ''), // fallback
        Locale('en', 'US'),
      ],
      title: 'Conecta2',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      initialRoute: "/",
      routes: {
        "/": (context) => const HomePage(),
        "/login": (context) =>
            const LoginPage(), // Login único que recibe el rol por arguments
        "/registerWorker": (context) =>
            const RegisterWorkerPage(), // ✅ nombre correcto de la clase
        "/registerClient": (context) => const RegisterClientPage(),
        "/clientHome": (context) =>
            const ClientHome(), // Pantalla principal del Cliente
        "/workerHome": (context) =>
            const WorkerHome(), // Panel inicial del Trabajador
      },
    );
  }
}

/// Pantalla principal con el logo y selección de rol
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? selectedRole; // "worker" o "client"

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.white;
    if (selectedRole == "worker") {
      bgColor = Colors.blue.shade50;
    } else if (selectedRole == "client") {
      bgColor = Colors.green.shade50;
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Conecta2 (asegúrate de tenerlo en assets y pubspec.yaml)
                Image.asset("assets/LogoConecta2.png", height: 140),
                const SizedBox(height: 24),
                const Text(
                  "Bienvenido a Conecta2",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Botón Trabajador
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => selectedRole = "worker");
                      Navigator.pushNamed(
                        context,
                        "/login",
                        arguments: {"role": "worker"},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Soy Trabajador"),
                  ),
                ),
                const SizedBox(height: 14),

                // Botón Cliente
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => selectedRole = "client");
                      Navigator.pushNamed(
                        context,
                        "/login",
                        arguments: {"role": "client"},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Soy Cliente"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
