# DEVOPS

> [!ATENCION]
> **Todo el software desplegado en este directorio son pruebas laboratorio**

> Los componentes documentados en este directorio están destinados a entornos de desarrollo, laboratorio y pruebas de concepto. Antes de utilizarlos en otros entornos, será necesario revisar y adaptar siempre.
>
> Su uso, configuración y despliegue son responsabilidad de quien los ejecuta. **No tiene ninguna garantía en ningún entorno.**

## Instalación de cf

Los comandos cf son necesarios para poder ejecutar todo las instación de docker.

Se instalan ejecutando:

```text
curl https://coronadofactory.github.io/cf-install-server.sh | sh
````

## 🐳 Configuración de componentes bajo Docker

- Se debe estar posicionado en el directorio donde está la aplicación
- En este directorio debe encontrarse en: `cf.docker.properties`
- Para instalar se debe ejecutar: `cf docker run`

Esta guía recoge la configuración necesaria para desplegar los siguientes servicios:

| Servicio | Propósito | Configuración |
|---|---|---|
| **MongoDB** | Persistencia de datos y carga inicial | `cf.docker.properties` |
| **Nginx** | Publicación de contenido web | `cf.docker.properties` |

La instalación tambien instala previamente Docker.

## Instalación de MongoDB bajo Docker

### Estructura de directorios

```text
proyecto/
├── cf.docker.properties
└── mongo-data/
    └── db_collection.json
```

### Configuración del fichero cf.docker.properties

```properties
# Versión de la imagen de MongoDB
mongodb.version=latest

# Directorio externo para almacenar los datos
mongodb.dir=/ruta/externa/mongo-data

# Directorio local con los recursos de inicialización
mongodb.data=./mongo-data
```

> [!IMPORTANT]
> Sustituye `/ruta/externa/mongo-data` por una ruta válida en tu máquina. El proceso crea el directorio otorgando los permisos necesarios a Docker.
>
> El nombre de los ficheros .json es importante `db_collection.json` porque db es la base de datos y collection la colección a insertar.


## Instalación de NgInx bajo Docker

### Descripción

Despliegue de Nginx mediante Docker para publicar contenido web estático utilizando una imagen personalizada y su correspondiente configuración.

### Estructura de directorios

```text
proyecto/
├── cf.docker.properties
└── html-app/
    ├── Dockerfile
    ├── html-pages.zip
    └── nginx.conf
```

### Configuración del fichero cf.docker.properties

```properties
# Directorio que contiene los recursos de Nginx
nginx.documents.folder=./html-app
```

### Recursos

- `Dockerfile`: define los pasos para construir la imagen Docker personalizada.
- `html-pages.zip`: La descompresión y el nombre de este fichero o ficheros, se especifica en Dockerfile.
- `nginx.conf`: fichero de configuración del servidor Nginx.

---

## ✅ Comprobaciones previas al despliegue

- [ ] Instalar el comando `cf`.
- [ ] Configurar las propiedades de `cf.docker.properties`.
- [ ] Revisar las versiones de las imágenes Docker.
- [ ] Confirmar que los puertos y las configuraciones de red son los esperados.
- [ ] Validar los requisitos de seguridad antes de utilizar estos componentes fuera del laboratorio.

---

**Fin de la guía de despliegue.**
