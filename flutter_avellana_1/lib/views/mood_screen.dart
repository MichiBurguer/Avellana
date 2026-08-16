import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class MoodScreen extends StatefulWidget {
  final String currentUid;
  final String relationshipId;

  const MoodScreen({
    super.key,
    required this.currentUid,
    required this.relationshipId,
  });

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _noteController = TextEditingController();

  // Opciones de estados de animo preconfiguradas
  final List<Map<String, String>> _moodOptions = [
    {'emoji': '😊', 'label': 'Feliz'},
    {'emoji': '🥰', 'label': 'Enamorado/a'},
    {'emoji': '😴', 'label': 'Cansado/a'},
    {'emoji': '🥺', 'label': 'Sensible'},
    {'emoji': '😤', 'label': 'Estresado/a'},
    {'emoji': '😔', 'label': 'Triste'},
  ];

  int _selectedMoodIndex = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveMood() async {
    setState(() => _isSaving = true);

    final selected = _moodOptions[_selectedMoodIndex];

    await _authService.logMood(
      relationshipId: widget.relationshipId,
      userId: widget.currentUid,
      emoji: selected['emoji']!,
      label: selected['label']!,
      note: _noteController.text.trim(),
    );

    _noteController.clear();

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Estado de ánimo actualizado!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SECCIÓN 1: Formulario para publicar estado
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    '¿Cómo te sientes en este momento?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Selector Horizontal de Emojis
                  SizedBox(
                    height: 75,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _moodOptions.length,
                      itemBuilder: (context, index) {
                        final item = _moodOptions[index];
                        final isSelected = index == _selectedMoodIndex;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMoodIndex = index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.lightBlue[100] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.lightBlue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(item['emoji']!, style: const TextStyle(fontSize: 24)),
                                const SizedBox(height: 2),
                                Text(
                                  item['label']!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Campo de nota opcional
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: 'Añade una nota breve (opcional)...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botón para publicar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveMood,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue[400],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text('Actualizar Estado', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Historial Compartido',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // SECCIÓN 2: Historial en tiempo real de estados de ánimo
          StreamBuilder<QuerySnapshot>(
            stream: _authService.getMoodLogsStream(widget.relationshipId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error al cargar historial.'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'Aún no hay estados registrados.\n¡Sé el primero en compartir cómo te sientes!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final bool isMe = data['user_id'] == widget.currentUid;
                  final String emoji = data['emoji'] ?? '😊';
                  final String label = data['label'] ?? '';
                  final String note = data['note'] ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isMe ? Colors.lightBlue[50] : Colors.pink[50],
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                      title: Text(
                        '$label (${isMe ? "Tú" : "Tu Pareja"})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: note.isNotEmpty ? Text(note) : null,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}