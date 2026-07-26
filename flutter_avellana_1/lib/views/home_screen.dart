import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final String currentUid;
  final String relationshipId;

  const HomeScreen({
    super.key,
    required this.currentUid,
    required this.relationshipId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0; // Controla qué pestaña está activa

  // Lista de títulos para el AppBar según la pestaña activa
  final List<String> _titles = [
    'Nuestro Espacio',
    'Mensajes Privados',
    'Galería Compartida',
  ];

  @override
  Widget build(BuildContext context) {
    // Definimos las pantallas
    final List<Widget> _screens = [
      // Pestaña 0: Inicio/Muro
      _buildMuroPrincipal(),

      // Pestaña 1: Chat en tiempo real
      ChatScreen(
        currentUid: widget.currentUid,
        relationshipId: widget.relationshipId,
      ),

      // Pestaña 2: Galería
      _buildModuloWidgetFotos(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        backgroundColor: Colors.lightBlue[400],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),

      // Muestra la pantalla activa
      body: _screens[_currentIndex],

      // BARRA DE NAVEGACIÓN INFERIOR
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.lightBlue[600],
        unselectedItemColor: Colors.grey[400],
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library_rounded),
            label: 'Fotos',
          ),
        ],
      ),
    );
  }
  Widget _buildModuloWidgetFotos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded, size: 80, color: Colors.lightBlue[200]),
            const SizedBox(height: 16),
            const Text(
              '¡Actualiza el Widget de tu Pareja!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona una foto de tu galería y aparecerá directamente en la pantalla de inicio de su teléfono.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _seleccionarYEnviarImagen,
              icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
              label: const Text('Elegir de la Galería', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue[400],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Función para abrir la galería y mandársela al widget
  Future<void> _seleccionarYEnviarImagen() async {
    final ImagePicker picker = ImagePicker();

    // Abrimos la galería nativa
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      //Guardamos la ruta de la foto para el Widget
      await HomeWidget.saveWidgetData<String>('imagePath', image.path);


      await HomeWidget.updateWidget(
        name: 'AppWidgetProvider',
        androidName: 'AppWidgetProvider',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Foto enviada al Widget con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  // primera pestaña (Inicio)
  Widget _buildMuroPrincipal() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.lightBlue[50],
              child: Icon(
                Icons.pets,
                size: 65,
                color: Colors.lightBlue[400],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '¡Bienvenidos!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Utiliza la barra inferior para navegar entre el chat y tus otras actividades.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            // Boton para ir al Chat
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentIndex = 1; // Cambia a la pestaña de Chat
                });
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
              label: const Text(
                'Abrir Chat',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue[400],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}