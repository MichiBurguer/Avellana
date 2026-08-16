import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class TasksScreen extends StatefulWidget {
  final String currentUid;
  final String relationshipId;

  const TasksScreen({
    super.key,
    required this.currentUid,
    required this.relationshipId,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _taskController = TextEditingController();

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Campo para agregar nueva tarea/meta
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taskController,
                      decoration: const InputDecoration(
                        hintText: 'Añadir nueva meta o tarea...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleAddTask(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.lightBlue),
                    iconSize: 32,
                    onPressed: _handleAddTask,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lista de tareas en vivo
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _authService.getTasksStream(widget.relationshipId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar tareas.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      '¡Sin metas ni tareas aún!\nAgreguen la primera meta juntos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bool isCompleted = data['is_completed'] ?? false;
                    final String title = data['title'] ?? '';
                    final bool isMyTask = data['created_by'] == widget.currentUid;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
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
                        subtitle: Text(
                          isMyTask ? 'Creada por ti' : 'Creada por tu pareja',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () {
                            _authService.deleteTask(widget.relationshipId, doc.id);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}