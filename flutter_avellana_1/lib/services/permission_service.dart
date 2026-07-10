import 'package:permission_handler/permission_handler.dart';

class PermissionService {

  // Solicitar permiso de notificaciones de forma explícita
  Future<bool> requestNotificationPermission() async {
    // Comprobamos el estado actual del permiso
    PermissionStatus status = await Permission.notification.status;

    if (status.isDenied) {
      // Si está denegado o es la primera vez, se lo pedimos al usuario
      status = await Permission.notification.request();
    }

    return status.isGranted;
  }

  // Solicitar múltiples permisos juntos (Ideal para la primera vez que abren la app)
  Future<void> requestInitialPerms() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.camera,
      // Usamos storage para versiones antiguas de Android o fotos
      Permission.photos,
    ].request();

    print("Estado de notificaciones: ${statuses[Permission.notification]}");
  }
}