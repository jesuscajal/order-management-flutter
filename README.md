# 📋 Sistema de Gestión de Pedidos

**Aplicación Flutter para administrar clientes, cotizaciones y seguimiento de servicios de limpieza**

## 🚀 Características

- ✅ **Gestión de Clientes**: CRUD completo con base de datos SQLite
- 📱 **Integración de Contactos**: Selección directa desde la agenda del teléfono
- 💰 **Estados de Pago**: Seguimiento de pagos (Pendiente, Señalado, Pagado)
- 🎨 **Modo Oscuro/Claro**: Interfaz adaptable automáticamente
- 📞 **Integración WhatsApp**: Contacto directo con clientes
- 🔍 **Búsqueda Inteligente**: Filtros por tipo de cliente y búsqueda rápida
- 📊 **Base de Datos Local**: Persistencia con Drift (SQLite)

## 🛠️ Tecnologías

- **Flutter** 3.2.3+
- **Dart** 3.0+
- **Drift** (SQLite ORM)
- **flutter_contacts** (Acceso a contactos)
- **url_launcher** (WhatsApp integration)
- **font_awesome_flutter** (Iconos)

## 📱 Capturas de Pantalla

_[Agregar capturas cuando esté funcionando]_

## 🔧 Instalación

### Prerrequisitos

- Flutter SDK 3.2.3 o superior
- Android Studio / VS Code
- Android NDK 27.0.12077973 (recomendado)

### Pasos

1. **Clonar el repositorio**

   ```bash
   git clone https://github.com/jesuscajal/order-management-flutter.git
   cd order-management-flutter
   ```

2. **Instalar dependencias**

   ```bash
   flutter pub get
   ```

3. **Generar archivos de base de datos**

   ```bash
   flutter packages pub run build_runner build
   ```

4. **Ejecutar la aplicación**
   ```bash
   flutter run
   ```

## 🚨 Problemas Conocidos

### Errores de Compilación

Si encuentras errores de compilación, prueba estas soluciones:

1. **Limpiar proyecto**

   ```bash
   flutter clean
   flutter pub get
   ```

2. **Actualizar NDK** (en `android/app/build.gradle.kts`):

   ```kotlin
   android {
       ndkVersion = "27.0.12077973"
   }
   ```

3. **Problemas con contactos**: Los plugins de contactos pueden tener conflictos. Ver [CHANGELOG.md](CHANGELOG.md) para detalles.

## 📁 Estructura del Proyecto

```
lib/
├── data/
│   ├── app_database.dart      # Configuración de base de datos
│   └── daos/                  # Data Access Objects
├── models/                    # Modelos de datos
├── screens/                   # Pantallas de la aplicación
│   ├── home_screen.dart
│   ├── clients_screen.dart
│   └── quotes_screen.dart
└── main.dart                  # Punto de entrada
```

## 🤝 Contribuir

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📋 Roadmap

- [ ] Resolver problemas de compilación con plugins de contactos
- [ ] Implementar módulo de cotizaciones completo
- [ ] Agregar reportes y estadísticas
- [ ] Implementar sincronización en la nube
- [ ] Agregar notificaciones push
- [ ] Modo offline mejorado

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 👥 Equipo

- **Desarrollador Principal**: [Tu Nombre]
- **Colaboradores**: [Lista de colaboradores]

## 📞 Soporte

Si tienes problemas o preguntas:

1. Revisa los [Issues](https://github.com/jesuscajal/order-management-flutter/issues)
2. Crea un nuevo issue si no encuentras solución
3. Contacta al equipo de desarrollo

---

⭐ **¡No olvides dar una estrella al proyecto si te resulta útil!**
