<div align="center">
  <img src="https://jkrlozz.github.io/Precarium-Web/ic_launcher.png" width="96" height="96" alt="Precarium">
  <h1>Precarium</h1>
  <p><strong>Descarga y organiza musica de YouTube en tu Android</strong></p>
  <p>
    <a href="https://github.com/JKrlozz/Precarium/releases">Descargar APK</a>
    ·
    <a href="https://jkrlozz.github.io/Precarium-Web/">Sitio web</a>
    ·
    <a href="https://github.com/JKrlozz/Precarium/issues">Reportar problema</a>
  </p>
</div>

---

## Descripcion

**Precarium** es una aplicacion Android nativa (Flutter) que permite buscar canciones en YouTube, extraer el audio y descargarlo al almacenamiento local para escucharlo sin conexion. Tambien organiza tu biblioteca musical, importa playlists desde Spotify y respalda tus canciones en Google Drive.

Sin servidores, sin suscripciones — todo funciona directamente en tu dispositivo.

## Caracteristicas

- **Buscador integrado** — Busca canciones, artistas o albumes directamente desde la app
- **Descarga de audio** — Extrae el audio de cualquier video de YouTube en formato M4A/Opus mediante NewPipe Extractor
- **Importar desde Spotify** — Importa playlists completas desde Spotify y descarga automaticamente cada cancion
- **Reproductor local** — Reproduce tu musica descargada con control de lista, reproduccion aleatoria y repeticion
- **Respaldo en Google Drive** — Respaldá tu biblioteca, playlists y configuracion en tu Drive personal
- **Respaldo automatico programado** — Programa respaldos periodicos a la hora que prefieras (incluso con la app cerrada)
- **Restauracion completa** — Restaura desde Drive incluyendo archivos de audio o solo metadatos

## Tecnologias

| Capa | Tecnologia |
|------|-----------|
| **Framework** | Flutter 3.x (Dart) |
| **Reproduccion** | just_audio |
| **Extraccion YouTube** | NewPipe Extractor (nativo Kotlin) + youtube_explode_dart |
| **Base de datos** | sqflite (SQLite local) |
| **Autenticacion Drive** | google_sign_in + Google Drive API v3 (OAuth 2.0) |
| **Respaldo automatico** | android_alarm_manager_plus |
| **Background** | wakelock_plus (CPU activa en descargas) |
| **Estado** | Provider (ChangeNotifier) |

## Estructura del proyecto

```
lib/
├── models/           # Modelos de datos (Song, DownloadTask, etc.)
├── providers/        # Logica de estado (ChangeNotifier providers)
├── screens/          # Pantallas de la UI
├── services/         # Servicios (Drive, descarga, busqueda, DB, etc.)
├── widgets/          # Widgets reutilizables
├── theme/            # Temas claro/oscuro
├── app.dart          # Widget raiz de la app
└── main.dart         # Punto de entrada
android/
├── app/src/main/kotlin/   # Codigo nativo Kotlin
│   ├── NativeExecutor.kt        # Extraccion y descarga de audio
│   ├── NewPipeDownloader.kt     # Downloader para NewPipe
│   ├── MediaNotificationPlugin.kt  # Notificaciones de reproduccion
│   └── MediaForegroundService.kt   # Servicio foreground de audio
└── app/src/main/AndroidManifest.xml
```

## Compilacion

```bash
# Requisitos: Flutter SDK 3.12+, Android SDK 36

# Obtener dependencias
flutter pub get

# Ejecutar en modo debug
flutter run

# Compilar APK release firmado
flutter build apk --release
```

### Notas de compilacion
- `compileSdk = 36`
- Se requiere un **keystore release** configurado en `android/app/build.gradle.kts`
- ProGuard activado con reglas en `android/app/proguard-rules.pro`

## Descargas

Los APK release estan disponibles en la seccion [Releases](https://github.com/JKrlozz/Precarium/releases) de GitHub.

## Licencia

Este proyecto es de codigo abierto. Consulta los terminos de servicio y politica de privacidad en el [sitio web oficial](https://jkrlozz.github.io/Precarium-Web/).

---

<div align="center">
  <sub>Precarium no esta afiliada ni respaldada por YouTube, Google o Spotify.</sub>
</div>
