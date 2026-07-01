import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Función para generar un código único de pareja (Ej: KEV-4829)
  String _generateCoupleCode(String name) {
    final random = Random();
    String prefix = name.length >= 3 ? name.substring(0, 3).toUpperCase() : 'APP';
    int number = 1000 + random.nextInt(9000); // Número de 4 dígitos
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
}