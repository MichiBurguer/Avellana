import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/user_model.dart';
import 'notification_service.dart';

const String _imgBbApiKey = 'd5835e62364dabbcded49ad1b7fb220e';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot>? _chatSubscription;
  StreamSubscription<DocumentSnapshot>? _relationshipSubscription;
  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  StreamSubscription<QuerySnapshot>? _moodsSubscription;

  bool _isInitialChatLoad = true;
  bool _isInitialTasksLoad = true;
  bool _isInitialMoodsLoad = true;

  /// Inicializa los escuchadores para notificaciones en tiempo real
  void initRelationshipListeners(String relationshipId, String currentUid) {
    cancelRelationshipListeners();

    _listenToChat(relationshipId, currentUid);
    _listenToWidgetPhoto(relationshipId, currentUid);
    _listenToTasks(relationshipId, currentUid);
    _listenToMoods(relationshipId, currentUid);
  }

  // Escuchar Chat
  void _listenToChat(String relationshipId, String currentUid) {
    _isInitialChatLoad = true;

    _chatSubscription = _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (_isInitialChatLoad) {
        _isInitialChatLoad = false;
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final senderId = data['sender_id'] ?? '';
            final text = data['text'] ?? 'Nuevo mensaje';

            if (senderId != currentUid) {
              NotificationService.showLocalNotification(
                title: 'Nuevo mensaje',
                body: text,
              );
            }
          }
        }
      }
    });
  }

  // Escuchar Cambios en la Foto del Widget
  void _listenToWidgetPhoto(String relationshipId, String currentUid) {
    String? lastPhotoUrl;

    _relationshipSubscription = _db
        .collection('relationships')
        .doc(relationshipId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data != null) {
        final photoUrl = data['widget_photo_url'] as String?;
        final senderId = data['widget_sender_id'] as String?;

        if (photoUrl != null && photoUrl.isNotEmpty) {
          if (lastPhotoUrl != null &&
              lastPhotoUrl != photoUrl &&
              senderId != currentUid) {
            NotificationService.showLocalNotification(
              title: '¡Nueva foto en el Widget! ',
              body: 'Tu pareja ha cambiado la foto compartida.',
            );
          }

          lastPhotoUrl = photoUrl;
        }
      }
    });
  }

  // 3. Escuchar Tareas
  void _listenToTasks(String relationshipId, String currentUid) {
    _isInitialTasksLoad = true;

    _tasksSubscription = _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('tasks')
        .snapshots()
        .listen((snapshot) {
      if (_isInitialTasksLoad) {
        _isInitialTasksLoad = false;
        return;
      }

      for (var change in snapshot.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final createdBy = data['created_by'] ?? '';
        final title = data['title'] ?? 'Tarea';

        if (change.type == DocumentChangeType.added && createdBy != currentUid) {
          NotificationService.showLocalNotification(
            title: 'Nueva tarea compartida ',
            body: title,
          );
        }

        if (change.type == DocumentChangeType.modified) {
          final isCompleted = data['is_completed'] ?? false;
          if (isCompleted && createdBy != currentUid) {
            NotificationService.showLocalNotification(
              title: '¡Tarea completada! ',
              body: '"$title" fue marcada como hecha.',
            );
          }
        }
      }
    });
  }

  // 4. Escuchar Estado de Ánimo (Colección 'mood_logs')
  void _listenToMoods(String relationshipId, String currentUid) {
    _isInitialMoodsLoad = true;

    _moodsSubscription = _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('mood_logs')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (_isInitialMoodsLoad) {
        _isInitialMoodsLoad = false;
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final userId = data['user_id'] ?? '';
            final emoji = data['emoji'] ?? '❤️';
            final label = data['label'] ?? '';

            if (userId != currentUid) {
              NotificationService.showLocalNotification(
                title: 'Estado de ánimo actualizado $emoji',
                body: label.isNotEmpty
                    ? 'Tu pareja se siente: $label'
                    : 'Tu pareja ha actualizado su estado de ánimo.',
              );
            }
          }
        }
      }
    });
  }

  /// Cancela las suscripciones
  void cancelRelationshipListeners() {
    _chatSubscription?.cancel();
    _relationshipSubscription?.cancel();
    _tasksSubscription?.cancel();
    _moodsSubscription?.cancel();
  }

  // Generar código de pareja
  String _generateCoupleCode(String name) {
    final random = Random();
    String prefix = name.length >= 3 ? name.substring(0, 3).toUpperCase() : 'APP';
    int number = 1000 + random.nextInt(9000);
    return '$prefix-$number';
  }

  // Registrar usuario
  Future<User?> registerWithEmailAndPassword(String name, String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        String code = _generateCoupleCode(name);
        UserModel newUser = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          coupleCode: code,
        );

        await _db.collection('users').doc(user.uid).set(newUser.toMap());
      }
      return user;
    } catch (e) {
      print('Error en el registro: ${e.toString()}');
      return null;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    cancelRelationshipListeners();
    await _auth.signOut();
  }

  // Vincular con pareja
  Future<String?> linkWithCouple(String currentUid, String currentCode, String partnerCode) async {
    try {
      if (partnerCode == currentCode) return null;

      QuerySnapshot partnerQuery = await _db
          .collection('users')
          .where('couple_code', isEqualTo: partnerCode)
          .get();

      if (partnerQuery.docs.isEmpty) {
        partnerQuery = await _db
            .collection('users')
            .where('coupleCode', isEqualTo: partnerCode)
            .get();
      }

      if (partnerQuery.docs.isEmpty) return null;

      DocumentSnapshot partnerDoc = partnerQuery.docs.first;
      Map<String, dynamic> partnerData = partnerDoc.data() as Map<String, dynamic>;
      if (partnerData['status'] == 'linked') return null;

      String partnerUid = partnerDoc.id;
      String relationshipId = _db.collection('relationships').doc().id;

      await _db.collection('relationships').doc(relationshipId).set({
        'id': relationshipId,
        'user_1': currentUid,
        'user_2': partnerUid,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _db.collection('users').doc(currentUid).update({
        'status': 'linked',
        'relationship_id': relationshipId,
      });

      await _db.collection('users').doc(partnerUid).update({
        'status': 'linked',
        'relationship_id': relationshipId,
      });

      return relationshipId;
    } catch (e) {
      print('Error al vincular: $e');
      return null;
    }
  }

  // Iniciar sesión
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('Error en el inicio de sesión: ${e.toString()}');
      return null;
    }
  }

  // --- CHAT ---
  Stream<QuerySnapshot> getMessagesStream(String relationshipId) {
    return _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> sendMessage(String relationshipId, String senderId, String text) async {
    if (text.trim().isEmpty) return;

    await _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('messages')
        .add({
      'sender_id': senderId,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- ESTADOS DE ANIMo ---
  Future<void> logMood({
    required String relationshipId,
    required String userId,
    required String emoji,
    required String label,
    String? note,
  }) async {
    await _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('mood_logs')
        .add({
      'user_id': userId,
      'emoji': emoji,
      'label': label,
      'note': note ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getMoodLogsStream(String relationshipId) {
    return _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('mood_logs')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // --- TAREAS Y METAS ---
  Future<void> addTask(String relationshipId, String userId, String title) async {
    if (title.trim().isEmpty) return;

    await _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('tasks')
        .add({
      'title': title.trim(),
      'is_completed': false,
      'created_by': userId,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleTaskStatus(String relationshipId, String taskId, bool currentStatus) async {
    await _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('tasks')
        .doc(taskId)
        .update({
      'is_completed': !currentStatus,
    });
  }

  Future<void> deleteTask(String relationshipId, String taskId) async {
    await _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

  Stream<QuerySnapshot> getTasksStream(String relationshipId) {
    return _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('tasks')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // --- WIDGET DE FOTOS ---
  Future<bool> uploadWidgetPhoto(String relationshipId, String senderId, File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      var response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {
          'key': _imgBbApiKey,
          'image': base64Image,
        },
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        String downloadUrl = jsonResponse['data']['url'];

        await _db.collection('relationships').doc(relationshipId).update({
          'widget_photo_url': downloadUrl,
          'widget_sender_id': senderId,
          'widget_updated_at': FieldValue.serverTimestamp(),
        });

        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  void listenAndSyncCoupleWidget(String relationshipId, String currentUid) {
    _db.collection('relationships').doc(relationshipId).snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data();
      final String? photoUrl = data?['widget_photo_url'];
      final String? senderId = data?['widget_sender_id'];

      if (photoUrl != null && photoUrl.isNotEmpty && senderId != currentUid) {
        await _downloadAndSetWidgetImage(photoUrl);
      }
    });
  }

  Future<void> _downloadAndSetWidgetImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final String fileName = 'partner_widget_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        await HomeWidget.saveWidgetData<String>('imagePath', file.path);

        await HomeWidget.updateWidget(
          name: 'AppWidgetProvider',
          androidName: 'AppWidgetProvider',
          qualifiedAndroidName: 'com.example.flutter_avellana_1.AppWidgetProvider',
        );

        print('¡Widget actualizado!');
      }
    } catch (e) {
      print('Error al actualizar el Widget: $e');
    }
  }
}