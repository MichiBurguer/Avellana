import 'package:permission_handler/permission_handler.dart';

class PermissionService {

  // Solicitar permiso de notificaciones
  Future<bool> requestNotificationPermission() async {
    // Comprobamos el estado actual del permiso
    PermissionStatus status = await Permission.notification.status;

    if (status.isDenied) {
      // Si está denegado o es la primera vez, se lo pedimos al usuario
      status = await Permission.notification.request();
    }

    return status.isGranted;
  }

  // Solicitar permisos
  Future<void> requestInitialPerms() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.camera,
      Permission.photos,
    ].request();

    print("Estado de notificaciones: ${statuses[Permission.notification]}");
  }
}