import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_avellana_1/services/notification_service.dart';
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
  void initState() {
    super.initState();
    if (widget.relationshipId.isNotEmpty) {
      _authService.listenAndSyncCoupleWidget(widget.relationshipId, widget.currentUid);
      NotificationService.initialize(widget.currentUid);

      _authService.initRelationshipListeners(widget.relationshipId, widget.currentUid);
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    _authService.cancelRelationshipListeners();
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/home_screen.png',
                height: 110,
                width: 110,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 15),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tarjeta de Vista Previa de la Foto Actual
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('relationships')
                .doc(widget.relationshipId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox.shrink();
              }

              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final String? photoUrl = data?['widget_photo_url'];
              final String? senderId = data?['widget_sender_id'];
              final Timestamp? updatedAt = data?['widget_updated_at'];

              if (photoUrl == null || photoUrl.isEmpty) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(Icons.photo_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'Aún no hay fotos en el widget',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '¡Sé el primero en enviar una foto a tu pareja!',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final bool isSentByMe = senderId == widget.currentUid;
              final String senderText = isSentByMe ? 'Enviada por ti' : 'Enviada por tu pareja';

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSentByMe ? Colors.lightBlue[50] : Colors.pink[50],
                        child: Icon(
                          isSentByMe ? Icons.arrow_upward_rounded : Icons.favorite_rounded,
                          color: isSentByMe ? Colors.lightBlue[400] : Colors.pink[400],
                          size: 20,
                        ),
                      ),
                      title: Text(
                        senderText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        updatedAt != null
                            ? _formatTimestamp(updatedAt.toDate())
                            : 'Recientemente',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[100],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: Colors.grey[50],
                      child: const Text(
                        'Foto visible actualmente en el Widget',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _seleccionarYEnviarImagen,
            icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
            label: const Text(
              'Enviar Nueva Foto al Widget',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue[400],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} hrs';
    return 'Hace ${diff.inDays} días';
  }
  Future<void> _seleccionarYEnviarImagen() async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      File imageFile = File(image.path);
      if (!await imageFile.exists()) {
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enviando foto...')),
        );
      }

      bool success = await _authService.uploadWidgetPhoto(
        widget.relationshipId,
        widget.currentUid,
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