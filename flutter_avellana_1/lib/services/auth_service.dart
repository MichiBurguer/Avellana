import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:convert';

const String _imgBbApiKey = 'd5835e62364dabbcded49ad1b7fb220e';
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Función para generar un código único de pareja
  String _generateCoupleCode(String name) {
    final random = Random();
    String prefix = name.length >= 3 ? name.substring(0, 3).toUpperCase() : 'APP';
    int number = 1000 + random.nextInt(9000);
    return '$prefix-$number';
  }

  // Registrar un nuevo usuario
  Future<User?> registerWithEmailAndPassword(String name, String email, String password) async {
    try {
      // 1. Crea el usuario en Firebase Authentication
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // 2. Genera el código único para la pareja
        String code = _generateCoupleCode(name);

        // 3. Crea el modelo de usuario
        UserModel newUser = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          coupleCode: code,
        );

        // 4. Guarda la información en la colección 'users' de Firestore
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
    await _auth.signOut();
  }
  // Vincular con el código de la pareja
  Future<String?> linkWithCouple(String currentUid, String currentCode, String partnerCode) async {
    try {
      if (partnerCode == currentCode) return null;

      // 1. Buscar pareja
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

      // Obtener el documento de la pareja
      DocumentSnapshot partnerDoc = partnerQuery.docs.first;
      Map<String, dynamic> partnerData = partnerDoc.data() as Map<String, dynamic>;
      if (partnerData['status'] == 'linked') return null;

      String partnerUid = partnerDoc.id;
      String relationshipId = _db.collection('relationships').doc().id;


      // Crear el documento en la colección 'relationships'
      await _db.collection('relationships').doc(relationshipId).set({
        'id': relationshipId,
        'user_1': currentUid,
        'user_2': partnerUid,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Actualizar el estado de ambos usuarios en Firestore
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
  // Iniciar sesión con correo y contraseña
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
  // Chat

// mensajes en tiempo real ordenados por fecha
  Stream<QuerySnapshot> getMessagesStream(String relationshipId) {
    return _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

// Enviar un mensaje
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
  // Etados de animo

// Guardar un nuevo estado de ánimo
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

// Escuchar los estados de ánimo
  Stream<QuerySnapshot> getMoodLogsStream(String relationshipId) {
    return _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('mood_logs')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
  // Tareas y metas compartidas

// Crear una nueva tarea
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

// Cambiar estado de la tarea (completada / pendiente)
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

// Eliminar tarea
  Future<void> deleteTask(String relationshipId, String taskId) async {
    await _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

// Escuchar tareas en tiempo real
  Stream<QuerySnapshot> getTasksStream(String relationshipId) {
    return _db
        .collection('relationships')
        .doc(relationshipId)
        .collection('tasks')
        .orderBy('created_at', descending: true)
        .snapshots();

// Widget de la pareja
  }
  Future<bool> uploadWidgetPhoto(String relationshipId, File imageFile) async {
    try {

      // convertimos la imagen local a Base64
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // petición POST a la API de ImgBB
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


        // guardar url de la imagen firestore
        await _db.collection('relationships').doc(relationshipId).update({
          'widget_photo_url': downloadUrl,
          'widget_updated_at': FieldValue.serverTimestamp(),
        });

        return true;
      } else {
        return false;
      }
    } catch (e, stack) {
      return false;
    }
  }
  void listenAndSyncCoupleWidget(String relationshipId) {
    _db.collection('relationships').doc(relationshipId).snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data();
      final String? photoUrl = data?['widget_photo_url'];

      if (photoUrl != null && photoUrl.isNotEmpty) {
        await _downloadAndSetWidgetImage(photoUrl);
      }
    });
  }

  // Descarga y actualiza el widget
  Future<void> _downloadAndSetWidgetImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();

        // Nombre de archivo
        final String fileName = 'partner_widget_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        await HomeWidget.saveWidgetData<String>('imagePath', null);

        await HomeWidget.saveWidgetData<String>('imagePath', file.path);

        await HomeWidget.updateWidget(
          name: 'AppWidgetProvider',
          androidName: 'AppWidgetProvider',
          qualifiedAndroidName: 'com.example.flutter_avellana_1.AppWidgetProvider',
        );

        print('¡Widget de Android notificado con la nueva foto!');
      }
    } catch (e) {
      print('Error al actualizar el Widget: $e');
    }
  }
}
