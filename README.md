# Gestión de contactos de una cuenta

Proyecto Salesforce desarrollado como prueba técnica. Añade a la página de registro de una cuenta un componente para consultar y gestionar sus contactos.

## Funcionalidades verificadas en el código

- Consulta los contactos relacionados con la cuenta actual.
- Muestra las columnas definidas en el Field Set `Contact.AccountContactsList`. En el metadata incluido, el Field Set contiene `Name`, `Phone`, `Email` y `Title`.
- Permite ordenar los datos de la tabla y ofrece orden inicial ascendente por nombre.
- Si `Name` forma parte del Field Set, el nombre se presenta como enlace al registro del contacto.
- Permite buscar contactos por nombre, email o teléfono. Los criterios de búsqueda están definidos en el código y son independientes de las columnas configuradas en el Field Set.
- Permite editar el contacto mediante `lightning-record-edit-form`. Los campos editables están definidos actualmente de forma fija: nombre, email, teléfono y cargo.
- Permite eliminar el contacto desde las acciones de fila, con confirmación `LightningConfirm`.
- Permite crear un contacto mediante un Screen Flow activo. El Flow recibe el ID de la cuenta y lo asigna al nuevo contacto.
- Refresca la lista después de crear, editar o eliminar un contacto.
- Limita a 50 los resultados devueltos por Apex.

El Field Set `AccountContactsList` permite personalizar las columnas que se muestran en la tabla de contactos. Los campos del formulario de edición y los criterios de búsqueda se definen por separado en el código. Además, cuando el campo `Name` está incluido en el Field Set, el nombre del contacto se muestra como un enlace a su registro.

## Arquitectura y archivos principales

| Ruta | Responsabilidad |
| --- | --- |
| `force-app/main/default/lwc/accountContactsList/accountContactsList.html` | Interfaz: tarjeta, buscador, tabla, formulario de edición y contenedor del Flow. |
| `force-app/main/default/lwc/accountContactsList/accountContactsList.js` | Estado e interacción del componente: invoca Apex, construye columnas, ordena y refresca los datos. |
| `force-app/main/default/lwc/accountContactsList/accountContactsList.js-meta.xml` | Expone el componente en páginas de registro de Salesforce para el objeto `Account`. |
| `force-app/main/default/classes/AccountContactsController.cls` | Devuelve contactos y definiciones de columna, y elimina contactos. |
| `force-app/main/default/classes/AccountContactsController.cls-meta.xml` | Metadata de la clase Apex. |
| `force-app/main/default/objects/Contact/fieldSets/AccountContactsList.fieldSet-meta.xml` | Define las columnas iniciales de la tabla. |
| `force-app/main/default/flows/Crear_Contacto_Asociado_Cuenta.flow-meta.xml` | Screen Flow activo que recopila datos y crea un contacto asociado a la cuenta. |
| `sfdx-project.json` | Configuración de Salesforce DX y directorio de paquete `force-app`. |
| `force-app/main/default/lwc/accountContactsList/__tests__/accountContactsList.test.js` | Prueba Jest generada por CLI, su único caso todavía es un placeholder. |
| `force-app/main/default/classes/AccountContactsControllerTest.cls` | Contiene las pruebas unitarias Apex de `AccountContactsController`. |
| `force-app/main/default/classes/AccountContactsControllerTest.cls-meta.xml` | Define los metadatos de la clase de pruebas Apex. |

### Comunicación entre LWC, Apex y Flow

El LWC usa el método `getAccountContacts` mediante `@wire`, pasando el `recordId` de la página y el texto de búsqueda. Apex lee los miembros del Field Set, devuelve las etiquetas, los nombres API y los tipos de columna, y construye una consulta SOQL con esos campos. El LWC convierte la respuesta en columnas de `lightning-datatable`.

La búsqueda añade condiciones para `Name`, `Email` y `Phone` cuando el usuario introduce texto. Tras la edición, la eliminación o la finalización correcta del Flow, el componente llama a `refreshApex` para volver a consultar los datos.

Para crear contactos, el LWC inicia `Crear_Contacto_Asociado_Cuenta` y le pasa `recordId` como variable de entrada. El Flow asigna ese valor a `Contact.AccountId`. Según su metadata, apellidos, email y teléfono son obligatorios, nombre y rol son opcionales.


## Pruebas y calidad
El proyecto incluye pruebas unitarias Apex para la clase AccountContactsController, que comprueban el funcionamiento de sus métodos principales.

Las pruebas se han ejecutado correctamente desde Visual Studio Code, con 5 pruebas superadas y ninguna fallida.

El componente Lightning Web Component incluye también un archivo de pruebas Jest, aunque actualmente contiene únicamente una prueba básica de ejemplo.

## Seguridad y permisos

- La clase Apex declara `with sharing`, por lo que respeta el acceso a registros a nivel de compartición.
- En la consulta de lectura se comprueba el acceso al objeto Contact y el acceso de campo para los campos del Field Set antes de incorporarlos a las columnas/selección.
- La consulta usa variables enlazadas para el ID de cuenta y el término de búsqueda.
- Los errores del acceso a contactos se comunican al LWC mediante un error controlado, el componente informa de resultados y fallos mediante notificaciones.
- La edición utiliza componentes estándar de Lightning para formularios de registro.

  
## Acceso y demostración

El proyecto está desplegado en un entorno de desarrollo de Salesforce para facilitar la revisión de su funcionamiento.

Las credenciales de acceso se facilitan por correo electrónico junto con el enlace al repositorio.

Para probar el componente, accede a una cuenta de Salesforce y comprueba las funcionalidades de consulta, búsqueda, ordenación, edición, creación y eliminación de contactos.


## Autora

- **Nombre:** Ana Cruces López.
- **Tecnologías:** Salesforce, Lightning Web Components (LWC), Apex y Screen Flow.
