#!/usr/bin/env python3
"""Prepara el proyecto Android que genera `flutter create` (Codemagic):
plugin google-services, minSdk 23 y firma de release con el keystore de Codemagic.
Funciona con build.gradle.kts (Flutter nuevo) y con build.gradle (Flutter viejo)."""
import os
import pathlib
import re
import sys

root = pathlib.Path('android')
kts = (root / 'app' / 'build.gradle.kts').exists()
ext = '.gradle.kts' if kts else '.gradle'
settings = root / ('settings' + ext)
app = root / 'app' / ('build' + ext)


def fallar(msg):
    sys.exit('ERROR preparar_android: ' + msg)


# La firma es opcional: sin keystore (build debug) se omite y se usa la firma debug.
firmar = bool(os.environ.get('CM_KEYSTORE_PATH'))
if not firmar:
    print('AVISO: sin keystore, se omite la firma de release (build debug).')

# 1) settings: plugin google-services
s = settings.read_text()
if 'com.google.gms.google-services' not in s:
    if kts:
        pat = r'(id\("com\.android\.application"\)[^\n]*\n)'
        nuevo = r'\1    id("com.google.gms.google-services") version "4.4.2" apply false\n'
    else:
        pat = r'(id\s+"com\.android\.application"[^\n]*\n)'
        nuevo = r'\1    id "com.google.gms.google-services" version "4.4.2" apply false\n'
    s, n = re.subn(pat, nuevo, s, count=1)
    if n != 1:
        fallar('no encontré el plugin de Android en ' + settings.name)
    settings.write_text(s)

# 2) app: plugin, minSdk y firma
a = app.read_text()
if 'com.google.gms.google-services' not in a:
    if kts:
        a = a.replace('id("com.android.application")',
                      'id("com.android.application")\n    id("com.google.gms.google-services")', 1)
    else:
        a = a.replace('id "com.android.application"',
                      'id "com.android.application"\n    id "com.google.gms.google-services"', 1)

if kts:
    a = a.replace('minSdk = flutter.minSdkVersion',
                  'minSdk = maxOf(23, flutter.minSdkVersion)', 1)
    firma = '''    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("CM_KEYSTORE_PATH"))
            storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("CM_KEY_ALIAS")
            keyPassword = System.getenv("CM_KEY_PASSWORD")
        }
    }

'''
    if firmar:
        a = a.replace('signingConfigs.getByName("debug")',
                      'signingConfigs.getByName("release")', 1)
else:
    a = a.replace('minSdkVersion flutter.minSdkVersion',
                  'minSdkVersion Math.max(23, flutter.minSdkVersion)', 1)
    firma = '''    signingConfigs {
        release {
            storeFile file(System.getenv("CM_KEYSTORE_PATH"))
            storePassword System.getenv("CM_KEYSTORE_PASSWORD")
            keyAlias System.getenv("CM_KEY_ALIAS")
            keyPassword System.getenv("CM_KEY_PASSWORD")
        }
    }

'''
    if firmar:
        a = a.replace('signingConfig signingConfigs.debug',
                      'signingConfig signingConfigs.release', 1)

if firmar and 'signingConfigs {' not in a:
    if '    buildTypes {' not in a:
        fallar('no encontré buildTypes en ' + app.name)
    a = a.replace('    buildTypes {', firma + '    buildTypes {', 1)
app.write_text(a)

if firmar and 'signingConfigs.getByName("release")' not in a and 'signingConfigs.release' not in a:
    fallar('no pude activar la firma de release')

print('OK. Revisá el targetSdk que usa tu Flutter:')
for linea in a.splitlines():
    if 'targetSdk' in linea or 'compileSdk' in linea or 'minSdk' in linea:
        print('  ', linea.strip())
