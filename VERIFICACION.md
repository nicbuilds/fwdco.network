# Verificación · 5 octubre 2026

**Compilación real completada correctamente**, tanto Release para dispositivo iOS como Debug para simulador, en GitHub Actions con Xcode 16.4 (16F6).

- Ejecución: https://github.com/nicbuilds/fwdco.network/actions/runs/37354429421
- Commit compilado: `b73134b167bad252277d4df082d5f83ceb753278`.
- Job: `111913123088`.
- Ambos registros contienen `BUILD SUCCEEDED`.
- Validación del producto: `help.nodo.mobile`, versión 1.0, build 2, arm64, mínimo 16.0, familia de dispositivos [1, 2].
- iPad declara las cuatro orientaciones.
- IPA inspeccionado después de descargarlo: contiene un ejecutable de dispositivo real (322320 bytes), sin perfil de aprovisionamiento ni directorio de firma.
- SHA-256 IPA: `1f6b44b1c01216a258b75e8473ec8eb9b6c404932cc0f4e35749edebec5b3d39`.

No se encontraron errores de compilación. El código Swift es idéntico al de NODO-iOS-v1.0.zip. Se cambiaron únicamente ajustes de empaquetado: build 2, orientaciones de iPad, exclusión explícita de Catalyst y declaración de cifrado estándar. Se añadieron scripts de build, validación, workflow y documentación. Los portales y su funcionalidad permanecen iguales.

Aviso no bloqueante de Xcode: se omitió extracción de metadatos AppIntents porque la app no depende de AppIntents. No afecta a las funciones existentes. GitHub también informó migración del runtime Node de sus acciones; el job terminó correctamente.

El artefacto entregado es previo a firma. Falta exclusivamente la firma y aprovisionamiento con una cuenta Apple mediante AltStore/AltServer, instalación y prueba en tus dispositivos. No se han probado las cuentas autenticadas ni el comportamiento en hardware físico.

Los logs originales están en `logs/`. El ZIP exterior incluye el IPA, el ZIP de la .app, SHA256SUMS y la guía. Los fuentes completos y workflow están conservados en la rama `nodo-ios-cloud`; la web en `main` no se modificó. No fusionar esa rama en main: tiene un árbol independiente para la app.
