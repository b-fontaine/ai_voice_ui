/// Fonction de sortie du processus (frontière plateforme, `exit` en prod).
typedef ExitHandler = void Function(int code);
