<div align="center">
  <h1>Precarium</h1>
  <p><strong>Descarga y organiza música de YouTube en tu Android</strong></p>
  <p>
    <a href="https://github.com/JKrlozz/Precarium/releases">Descargar APK</a>
    ·
    <a href="https://github.com/JKrlozz/Precarium-Web">Sitio web</a>
    ·
    <a href="https://github.com/users/JKrlozz/projects">Reportar problema</a>
  </p>
</div>

---

## 🎯 Descripción

**Precarium** es una aplicación Android nativa (Flutter) que permite buscar canciones en YouTube, extraer el audio y descargarlo al almacenamiento local para escucharlo sin conexión. También organiza tu biblioteca musical, importa playlists desde Spotify y respalda tus canciones en Google Drive.

Sin servidores, sin suscripciones — todo funciona directamente en tu dispositivo.

## ✨ Características

- **Buscador integrado** — Busca canciones, artistas o álbumes directamente desde la app
- **Descarga de audio** — Extrae el audio de cualquier video de YouTube en formato M4A/Opus mediante NewPipe Extractor
- **Importar desde Spotify** — Importa playlists completas desde Spotify y descarga automáticamente cada canción
- **Reproductor local** — Reproduce tu música descargada con control de lista, reproducción aleatoria y repetición
- **Respaldo en Google Drive** — Respaldá tu biblioteca, playlists y configuración en tu Drive personal
- **Respaldo automatico programado** — Programa respaldos periodicos a la hora que prefieras (incluso con la app cerrada)
- **Restauracion completa** — Restaura desde Drive incluyendo archivos de audio o solo metadatos

## 🛠️ Tecnologías

| Capa | Tecnología |
|------|-----------|
| **Framework** | Flutter 3.x (Dart) |
| **Reproducción** | just_audio |
| **Extracción YouTube** | NewPipe Extractor (nativo Kotlin) + youtube_explode_dart |
| **Base de datos** | sqflite (SQLite local) |
| **Autenticación Drive** | google_sign_in + Google Drive API v3 (OAuth 2.0) |
| **Respaldo automático** | android_alarm_manager_plus |
| **Background** | wakelock_plus (CPU activa en descargas) |
| **Estado** | Provider (ChangeNotifier) |

## 📁 Estructura del proyecto

```
lib/
├── models/           # Modelos de datos (Song, DownloadTask, etc.)
├── providers/        # Lógica de estado (ChangeNotifier providers)
├── screens/          # Pantallas de la UI
├── services/         # Servicios (Drive, descarga, búsqueda, DB, etc.)
├── widgets/          # Widgets reutilizables
├── theme/            # Temas claro/oscuro
├── app.dart          # Widget raíz de la app
└── main.dart         # Punto de entrada
android/
├── app/src/main/kotlin/   # Código nativo Kotlin
│   ├── NativeExecutor.kt        # Extracción y descarga de audio
│   ├── NewPipeDownloader.kt     # Downloader para NewPipe
│   ├── MediaNotificationPlugin.kt  # Notificaciones de reproducción
│   └── MediaForegroundService.kt   # Servicio foreground de audio
└── app/src/main/AndroidManifest.xml
```

## 🚀 Compilación

```bash
# Requisitos: Flutter SDK 3.12+, Android SDK 36

# Obtener dependencias
flutter pub get

# Ejecutar en modo debug
flutter run

# Compilar APK release firmado
flutter build apk --release
```

### Notas de compilación
- `compileSdk = 36`
- Se requiere un **keystore release** configurado en `android/app/build.gradle.kts`
- ProGuard activado con reglas en `android/app/proguard-rules.pro`

## 📦 Descargas

Los APK release están disponibles en la sección [Releases](https://github.com/JKrlozz/Precarium/releases) de GitHub.

## 📄 Licencia

Este proyecto es de código abierto. Consultá los términos de servicio y política de privacidad en el [sitio web oficial](https://jkrlozz.github.io/Precarium-Web/).

---

<div align="center">
  <sub>Precarium no está afiliada ni respaldada por YouTube, Google o Spotify.</sub>
</div>
