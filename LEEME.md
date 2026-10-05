# NODO · instalar desde Windows 11

## Archivo que debes instalar

`NODO-1.0-build2-unsigned.ipa` es el paquete de dispositivo previo a firma. Contiene `Payload/NODO.app`, compilado para arm64. No se instala tocándolo desde Archivos: AltStore/AltServer debe firmarlo con tu cuenta Apple y generar el perfil de tu dispositivo. No necesitas proporcionar claves de Apple a GitHub ni a ChatGPT.

`NODO-1.0-build2-unsigned.app.zip` contiene la misma aplicación compilada antes de empaquetarla como IPA. No selecciones este ZIP en AltStore.

## Configuración

| Parámetro | Valor |
|---|---|
| Bundle Identifier del proyecto | `help.nodo.mobile` |
| Versión | `1.0` |
| Build | `2` |
| Mínimo | iOS / iPadOS 16.0 |
| Dispositivos | iPhone e iPad (`UIDeviceFamily` 1 y 2) |
| Arquitectura del dispositivo | arm64 |
| Cloud | GitHub Actions, macOS 15, Xcode 16.4 |

AltStore puede adaptar el identificador para tu equipo de firma; conserva la misma cuenta y procedimiento al actualizar para mantener continuidad. El identificador del proyecto no supone un registro reservado en Apple Developer.

## 1. Preparar Windows y AltStore Classic

1. Descarga [AltServer para Windows](https://altstore.io/) e instala `Setup.exe`.
2. Sigue los enlaces de [la guía oficial para Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) para instalar iTunes e iCloud desde Apple, no las versiones de Microsoft Store. Si necesitas conservar iCloud de Store, usa la alternativa de la guía oficial de solución de problemas enlazada abajo.
3. Ejecuta AltServer como administrador. Permite acceso en redes privadas si Windows lo solicita.
4. Conecta por USB el iPhone desbloqueado, pulsa **Confiar** y comprueba que aparece en iTunes. Activa la sincronización por Wi-Fi en iTunes.
5. En la bandeja del sistema de Windows, abre AltServer → **Install AltStore** → tu iPhone. Introduce tu cuenta Apple y completa las verificaciones que solicite.
6. En el teléfono: Ajustes → General → VPN y gestión de dispositivos → confía en tu cuenta de desarrollador. Activa Ajustes → Privacidad y seguridad → Modo de desarrollador; reinicia y confirma si se solicita.

## 2. Firmar e instalar NODO

**Ruta AltStore, útil para renovar después:**

1. Guarda `NODO-1.0-build2-unsigned.ipa` en Archivos del iPhone, por ejemplo mediante iCloud Drive desde Windows.
2. Mantén AltServer abierto en la PC y ambos dispositivos en la misma red; para la primera instalación conserva además el cable USB.
3. Abre AltStore Classic, inicia sesión con la misma cuenta Apple si se solicita y entra a **My Apps → +**. Selecciona el IPA.
4. Espera a que AltStore termine de firmar e instalar. Abre NODO e inicia sesión por separado en cada portal.

**Ruta directa desde Windows:** mantén pulsada **Shift** al hacer clic en el icono de AltServer. Elige **Sideload .ipa…**, selecciona tu dispositivo y `NODO-1.0-build2-unsigned.ipa`; completa el acceso Apple solicitado. AltServer firma e instala desde la PC. Esta función está documentada en las [notas oficiales de AltServer](https://faq.altstore.io/release-notes/altserver). Para renovar cómodamente dentro de AltStore, usa la primera ruta; no dependas de que una instalación directa aparezca automáticamente en My Apps.

No se requiere jailbreak, certificado empresarial ni activar AltJIT.

## 3. Probar también en iPad

Repite la preparación de confianza, Developer Mode e instalación de AltStore en el iPad. Usa el MISMO IPA y elige el iPad al instalar; su perfil de firma se genera por separado. Requiere iPadOS 16 o posterior. Las sesiones de NODO son locales a cada dispositivo, de modo que tendrás que iniciar sesión allí también.

## 4. Mantener funcionando la prueba

Con cuenta Apple gratuita, renueva antes de siete días. Abre AltStore → My Apps → Refresh All con AltServer disponible en la misma red o por cable. El límite habitual es de tres apps instaladas mediante este mecanismo por dispositivo; AltStore ocupa una. Consulta [Getting Started](https://faq.altstore.io/altstore-classic/your-altstore). No hace falta pagar Apple Developer para esta vía de prueba personal.

Si aparece “Could not find AltServer”, prueba USB, verifica que AltServer esté abierto y que el firewall permita su acceso en la red privada. No desactives todo el firewall. Consulta [solución oficial de problemas](https://faq.altstore.io/altstore-classic/troubleshooting-guide). Usa AltServer actualizado: las notas oficiales documentan correcciones para firma y arranque en iOS reciente.

## 5. Build cloud reproducible

Rama independiente: https://github.com/nicbuilds/fwdco.network/tree/nodo-ios-cloud

La rama contiene solo el proyecto iOS. No fusionarla en `main`: `main` sigue siendo la web. El workflow `.github/workflows/ios-build.yml` compila dispositivo y simulador, valida el binario y publica el IPA sin firma junto con logs y SHA-256. No contiene secretos ni pasos de publicación en App Store.

Para repetir el build existente desde Windows: abre el enlace de la ejecución indicado en `VERIFICACION.md`, inicia sesión en GitHub y usa **Re-run all jobs**. Al terminar, descarga el artefacto **NODO-iOS-unsigned** y descomprime el ZIP exterior. También se ejecuta automáticamente cuando cambian los archivos de build o código en `nodo-ios-cloud`. `workflow_dispatch` está preparado, pero el botón manual puede no aparecer mientras el workflow no exista en la rama por defecto; no cambies ni fusiones la rama de la web para resolverlo.

El build tiene un límite de 20 minutos y conserva artefactos 30 días. Los registros identifican la versión de Xcode usada. Si GitHub cambia su imagen y retira Xcode 16.4, habrá que actualizar la selección; el build falla de forma visible en lugar de usar silenciosamente otro compilador.

## Prueba de funcionamiento con tus cuentas

En iPhone e iPad: abre ambos portales, comprueba tus permisos, navega atrás/adelante, gira la pantalla, abre un documento y descarga un PDF. No se han usado tus cuentas ni probado operaciones autenticadas. La compilación y la validación del paquete no sustituyen esa prueba. La funcionalidad de Rukovoditel, InvoicePlane y su sincronización permanece en tus servidores.
