import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:home_widget/home_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'chat_screen.dart';
import 'mood_screen.dart';

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
  final TextEditingController _taskController = TextEditingController();
  int _currentIndex = 0;

  final List<String> _titles = [
    'Nuestro Espacio',
    'Mensajes Privados',
    'Estado de Ánimo',
    'Galería Compartida',
  ];

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  void _handleAddTask() {
    final title = _taskController.text;
    if (title.trim().isNotEmpty) {
      _authService.addTask(widget.relationshipId, widget.currentUid, title);
      _taskController.clear();
      FocusScope.of(context).unfocus(); // Cierra el teclado
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      _buildMuroPrincipal(),
      ChatScreen(
        currentUid: widget.currentUid,
        relationshipId: widget.relationshipId,
      ),
      MoodScreen(
        currentUid: widget.currentUid,
        relationshipId: widget.relationshipId,
      ),
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
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.lightBlue[600],
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
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
            icon: Icon(Icons.favorite_rounded),
            label: 'Ánimo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library_rounded),
            label: 'Fotos',
          ),
        ],
      ),
    );
  }

  // MURO PRINCIPAL CON METAS/TAREAS COMPARTIDAS
  Widget _buildMuroPrincipal() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de bienvenida
          Center(
            child: CircleAvatar(
              radius: 45,
              backgroundColor: Colors.lightBlue[50],
              child: Icon(
                Icons.pets,
                size: 50,
                color: Colors.lightBlue[400],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '¡Bienvenidos!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // SECCIÓN: Tarjeta de Tareas/Metas Compartidas
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.lightBlue[400]),
                      const SizedBox(width: 8),
                      const Text(
                        'Metas y Tareas Compartidas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Input rápido para crear nueva meta
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taskController,
                          decoration: InputDecoration(
                            hintText: 'Añadir nueva tarea o meta...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onSubmitted: (_) => _handleAddTask(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.lightBlue),
                        iconSize: 32,
                        onPressed: _handleAddTask,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stream de Tareas desde Firestore
                  StreamBuilder<QuerySnapshot>(
                    stream: _authService.getTasksStream(widget.relationshipId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Error al cargar tareas.');
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Text(
                              '¡No hay metas pendientes!\nAñadan una tarea arriba para empezar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final bool isCompleted = data['is_completed'] ?? false;
                          final String title = data['title'] ?? '';

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Checkbox(
                              value: isCompleted,
                              activeColor: Colors.lightBlue[400],
                              onChanged: (bool? value) {
                                _authService.toggleTaskStatus(
                                  widget.relationshipId,
                                  doc.id,
                                  isCompleted,
                                );
                              },
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: isCompleted ? Colors.grey : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                              onPressed: () {
                                _authService.deleteTask(widget.relationshipId, doc.id);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modulo widget de fotos compartidas
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
              'Selecciona una foto de tu galería y aparecerá directamente en el widget de su teléfono.',
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

  Future<void> _seleccionarYEnviarImagen() async {
  final ImagePicker picker = ImagePicker();

  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 70, // Reducimos un poco el tamaño
  );

  if (image != null) {
    File imageFile = File(image.path);
    // diálogo de carga
    if (!await imageFile.exists()) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enviando foto...'),
      ),
    );

    bool success = await _authService.uploadWidgetPhoto(
      widget.relationshipId,
      imageFile,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Foto enviada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al enviar la imagen. Inténtalo de nuevo.'),
            backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}