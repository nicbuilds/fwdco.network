# NODO 1.0 build 3 · AltStore Classic

## Qué cambia

Se conserva íntegro NODOApp.swift y su funcionalidad. Se incrementa CFBundleVersion a 3. Bundle Identifier help.nodo.mobile, versión 1.0, deployment target 16.0 y UIDeviceFamily [1,2] permanecen iguales.

Esta variante incorpora una firma **ad hoc local** completa, no una firma Apple de desarrollo. La firma sella el ejecutable y los recursos, incluye un diccionario de entitlements vacío y puede ser reemplazada por AltStore Classic/AltServer. No solicita App Groups, iCloud, notificaciones push, permisos privados, keychain groups ni un Team ID ajeno.

No se incorpora embedded.mobileprovision: el perfil válido lo debe emitir Apple para la cuenta y dispositivo del usuario durante la instalación. Fabricar un perfil, copiar uno ajeno o incluir uno vencido no resolvería ese requisito.

Info.plist se normaliza a XML antes de firmar. El IPA usa ZIP estándar, contiene únicamente Payload/NODO.app, conserva 0755 en el ejecutable y omite AppleDouble, atributos extendidos y entradas Zip64. No hay extensiones ni frameworks embebidos que requieran firmas adicionales.

## Validaciones automatizadas

El workflow ejecuta compilación Release para dispositivo y Debug para simulador; inspecciona versión, plataforma, arm64, mínimo 16.0 y familia iPhone/iPad. Después:

- codesign --verify --deep --strict sobre el bundle completo.
- Lectura de LC_CODE_SIGNATURE y CodeDirectory ad hoc.
- Comprobación de binario no cifrado y entitlements XML vacíos en el slot que lee AltSign.
- Lectura de entitlements por codesign y comparación con un diccionario vacío.
- Re-firma ad hoc de una copia y nueva verificación estricta, sin modificar el producto entregado.
- Comprobación de integridad, rutas y permisos del ZIP.

Estas pruebas verifican la estructura, firma ad hoc y capacidad de reemplazarla localmente. **No equivalen a una instalación probada con AltStore y una cuenta Apple gratuita.** Esa prueba exige la cuenta del usuario y su dispositivo.

Ejecución: https://github.com/nicbuilds/fwdco.network/actions/runs/37361738104
Commit: 0088c0e438f636b36cca1402f6262c1070ca858e

## Sobre AltServer.ServerError 2005

La documentación oficial lo define como una solicitud inválida recibida por AltServer y recomienda actualizar AltServer. No demuestra que un IPA unsigned sea la causa. El build 2 tenía Mach-O e Info.plist válidos y no tenía firma. Esta nueva variante añade una firma estructural completa para eliminar esa variable; no se puede prometer que corrija un fallo del protocolo cliente-servidor.

Referencia: https://faq.altstore.io/altstore-classic/error-codes
Revisión del código: https://github.com/rileytestut/AltServer-Windows/blob/master/AltSign/Application.cpp

## Instalación

Actualiza AltServer Windows y AltStore Classic a sus versiones oficiales actuales. Abre AltStore Classic → My Apps → + y selecciona NODO-1.0-build3-AltStore-Classic.ipa con AltServer disponible. Alternativamente, desde Windows, Shift + clic en AltServer → Sideload .ipa… permite probar la instalación directa por USB.

AltStore sustituirá la firma ad hoc por una firma de desarrollo y añadirá el perfil de tu cuenta. Si vuelve a aparecer 2005, conserva el detalle completo del error y las versiones de AltServer/AltStore; el paquete no puede corregir una incompatibilidad de comunicación entre ellos.
