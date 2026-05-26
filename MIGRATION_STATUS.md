# Estado de migracion Flutter

Proyecto generado en `controller_app_flutter` a partir de la app Android Java/Kotlin existente.

## Incluido

- App Flutter compilable para Android con `applicationId` original: `interrapidisimo.controllerapp`.
- Version de app migrada a formato Flutter: `1.1109.136+1109136`.
- Assets base: logo, imagen del login y fuentes Montserrat/Prospero.
- Pantallas base: login, home, notificaciones, ambientes, rutas Android inventariadas.
- Modulos iniciales: Vender, Entregar, Recoger, Asignar envios, Mis Pagos, Estado Cuenta, Mis Mensajeros, Reimprimir, Anular, Bloques, Enrutamiento, Auditoria y PrePago.
- Matriz de ambientes tomada de `app/src/main/res/values/strings.xml`.
- Permisos Android principales migrados desde el `AndroidManifest.xml` nativo.
- Login real conectado contra `Seguridad/AuthenticaUsuarioControllerApp`, con validacion de version, Base64, MD5, AES-256 compatible con Android, canal nativo para `ANDROID_ID` y secreto AES, headers HTTP nativos y persistencia `sqflite`.
- Persistencia posterior al login: credenciales locales, tokens, roles, modulos, informacion de usuario, ubicacion autorizada, estado de sesion y estado de sincronizacion local.
- Sincronizacion inicial migrada al flujo por archivos de Android: esquemas `SincronizadorDatos/ObtenerEsquema/true`, esquema de producto, descarga HTTPS de zips S3 (`Sincronizacion.zip`, `Producto_PRD.zip` y archivos filtrados), extraccion local y carga de `.txt` con `INSERT OR REPLACE` por lotes.
- Mapeo de `SyncSchema` corregido contra el contrato real de API: `BatchSize`, `Error`, `Filtro`, `NombreTabla`, `NumeroCampos`, `Pk` y `QueryCreacion`.
- Feature login separado en `lib/features/login`: fachada `login.dart`, `presentation/login_page.dart`, `data/models`, `data/datasources`, `data/repositories` y `data/services`.
- Feature Vender separado en `lib/features/vender`: flujo de admision automatica por pasos, vistas independientes (`Datos envio`, `Liquidacion`, `Remitente`, `Destinatario`, `Resumen`), controlador de flujo, repositorio local de tarifas/catalogos/suministros y repositorio remoto para preenvio, guia, token Torre Direcciones, cliente contado, georreferenciacion y recarga de suministros.
- Impresion de Vender separada en `lib/features/vender/impresion`: guarda el payload `ObjetoADGuiaImpresion`, genera etiqueta PDF local, detecta impresora Bluetooth conectada por puente nativo y usa PDF como fallback.
- Reimpresion desde Home separada en `lib/features/home/reimpresion`: consulta local por numero de guia, cae al endpoint `AdmisionMensajeria/ObtenerGuiaNumeroGuia` cuando hay red, registra auditoria de reimpresion y reutiliza el motor de etiqueta/PDF de Vender.
- Feature Bloques separado en `lib/features/bloques`: flujo desde Home con diseno basado en `BlocksMainActivity`, validacion por QR real o codigo, consulta de entregas, bloques pendientes, gestion de bloque y persistencia local `sqflite`.
- Componentes compartidos en `lib/shared`: bridge nativo, configuracion de API Controller, cliente HTTP base con headers nativos y cifrado Controller.
- Firebase Cloud Messaging migrado para login: inicializacion Firebase, obtencion de token FCM con reintentos y regeneracion, envio en `TokenFirebase` del login, envio en `TokenDispositivo` al registrar dispositivo, persistencia local y escucha de `onTokenRefresh`.
- Header publico `IdKey` migrado desde Android: consulta `Autenticacion/GenerarTokenTemporal`, arma payload `Token`/`IdKey`, cifra AES/PBKDF2 compatible con `Encryptor.kt` y lo agrega a `getUserInfo` y sincronizacion inicial de Controller.
- Extraccion ZIP de sincronizacion ajustada para validar rutas inseguras con canonicalizacion estable sin depender de symlinks de Android.
- Sincronizacion post-login de Torre Direcciones agregada como en `NavigationViewModel`: obtiene token de Torre, consulta `Sincronizacion/ObtenerTablas`, crea esquemas locales, lee credenciales AWS desde `ParametrosFramework`, las descifra y descarga zips por centro de servicio para cargar registros locales.
- Selectores de catalogos de Vender convertidos a busqueda por nombre/id y catalogos grandes ampliados para evitar cortes de listas como `Localidad_PAR`.

## Validacion

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

APK generado:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Pendiente funcional

- Migrar el resto de entidades Room/SQLite a `sqflite` o Isar modulo por modulo.
- Completar el cierre online de admision/facturacion/impresion de Vender despues del registro offline inicial.
- Reimplementar flujos de impresion Bluetooth, firma, camara, mapas, recepcion de notificaciones FCM y WorkManager.
- Portar DTOs/repositorios por modulo y reemplazar los datos de muestra de las pantallas.
