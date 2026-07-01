class UserModel {
  final String uid;
  final String name;
  final String email;
  final String coupleCode;
  final String relationshipId;
  final String status;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.coupleCode,
    this.relationshipId = '',
    this.status = 'single',
  });

  // Convierte los datos a JSON para guardarlos en Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'couple_code': coupleCode,
      'relationship_id': relationshipId,
      'status': status,
    };
  }
}