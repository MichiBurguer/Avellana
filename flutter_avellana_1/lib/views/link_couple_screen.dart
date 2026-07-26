import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LinkCoupleScreen extends StatefulWidget {
  final String currentUid;
  final String myCode;

  const LinkCoupleScreen({
    super.key,
    required this.currentUid,
    required this.myCode,
  });

  @override
  State<LinkCoupleScreen> createState() => _LinkCoupleScreenState();
}

class _LinkCoupleScreenState extends State<LinkCoupleScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    // Liberamos la memoria del controlador
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleLink() async {
    final String inputCode = _codeController.text.trim().toUpperCase();
    if (inputCode.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final String? relId = await _authService.linkWithCouple(
        widget.currentUid,
        widget.myCode,
        inputCode,
      );

      if (!mounted) return;

      if (relId == null) {
        setState(() => _isLoading = false);
        _showSnackBar('Codigo incorrecto o pareja ya vinculada.', Colors.red);
        return;
      }

      setState(() => _isLoading = false);
      _showSnackBar('¡Conexión establecida con éxito! Bienvenidos.', Colors.green);

      // 2. Redirigimos al HomeScreen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            currentUid: widget.currentUid,
            relationshipId: relId,
          ),
        ),
            (route) => false,
      );
    } catch (e) {
      debugPrint("Error durante la vinculación: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error al cargar el espacio compartido.', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Vincular Pareja'),
        centerTitle: true,
        backgroundColor: Colors.lightBlue[400],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/linkcouple.png',
                  height: 175,
                  width: 175,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sección: Tu código
            Card(
              color: Colors.lightBlue[50],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'Comparte tu código único con tu pareja:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.myCode,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.lightBlue[800],
                            letterSpacing: 2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.grey),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.myCode),
                            );
                            _showSnackBar(
                              'Código copiado al portapapeles',
                              Colors.black87,
                            );
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
            const Text(
              'O ingresa el código de tu pareja:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Campo para el código del otro
            TextField(
              controller: _codeController,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código de tu pareja (Ej: MIC-1234)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.favorite),
              ),
            ),
            const SizedBox(height: 24),

            // Botón de Enlace
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _handleLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue[400],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Vincular Pareja',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}