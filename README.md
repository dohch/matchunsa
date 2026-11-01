# MatchUNSA

Aplicación Flutter para Android y Web. Esta primera base contiene únicamente la configuración inicial y una pantalla de arranque.

## Requisitos

- Flutter SDK instalado y disponible en `PATH`.
- Android Studio y Android SDK para ejecutar en Android.
- Chrome para ejecutar en Web.

## Preparación y ejecución

Desde la raíz del repositorio, genera los archivos de plataforma y descarga las dependencias declaradas:

```sh
flutter create --platforms=android,web .
flutter pub get
```

Ejecuta en Android con un emulador abierto o un dispositivo conectado:

```sh
flutter run -d <device-id>
```

Ejecuta en Chrome:

```sh
flutter run -d chrome
```

Para compilar una versión Web:

```sh
flutter build web
```
