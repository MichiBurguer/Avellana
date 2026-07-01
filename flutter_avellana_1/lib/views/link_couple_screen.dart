import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

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

  void _handleLink() async {
    String inputCode = _codeController.text.trim().toUpperCase();
    if (inputCode.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    bool success = await _authService.linkWithCouple(
      widget.currentUid,
      widget.myCode,
      inputCode,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Conexión establecida con éxito! Bienvenidos.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código incorrecto o pareja ya vinculada.'), backgroundColor: Colors.red),
      );
    }
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
            const SizedBox(height: 20),
            Icon(Icons.lock_person_rounded, size: 70, color: Colors.lightBlue[400]),
            const SizedBox(height: 24),

            // Sección 1: Tu código
            Card(
              color: Colors.lightBlue[50],
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'Comparte tu código único con tu pareja:',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
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
                            Clipboard.setData(ClipboardData(text: widget.myCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Código copiado al portapapeles')),
                            );
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Vincular Pareja',
                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}