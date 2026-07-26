import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

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
}
