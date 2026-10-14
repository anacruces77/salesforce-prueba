public with sharing class AccountContactsController {

    // Clase interna para envolver los datos de contacto y sus definiciones de campo.
    public class ContactDataWrapper {
        @AuraEnabled public List<FieldColumnWrapper> fields { get; set; }
        @AuraEnabled public List<Contact> contacts { get; set; }
    }

    // Clase interna para definir la estructura de los campos de contacto.
    public class FieldColumnWrapper {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String fieldPath { get; set; }
        @AuraEnabled public String type { get; set; }
    }

    // Obtiene los contactos asociados a una cuenta, y opcionalmente filtrados por texto de búsqueda.
    @AuraEnabled(cacheable=true)
    public static ContactDataWrapper getAccountContacts(Id accountId, String searchText) {
        ContactDataWrapper result = new ContactDataWrapper();
        result.fields = new List<FieldColumnWrapper>();
        result.contacts = new List<Contact>();

        if (accountId == null) {
            return result;
        }

        // Verifica si el usuario tiene acceso al objeto Contact.
        if (!Contact.SObjectType.getDescribe().isAccessible()) {
            throw new AuraHandledException('No tienes permiso para consultar contactos.');
        }

        // Verifica si el usuario tiene acceso a los campos del objeto Contact.
        List<String> selectedFields = new List<String>{ 'Id' };
        List<String> searchableFields = new List<String>();
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();

        // Agrega campos de búsqueda predeterminados si son accesibles.
        for (String fieldName : new List<String>{ 'Name', 'Email', 'Phone' }) {
            Schema.SObjectField fieldToken = contactFields.get(fieldName);
            if (fieldToken != null && fieldToken.getDescribe().isAccessible()) {
                searchableFields.add(fieldName);
            }
        }

        // Las columnas y los campos de la consulta proceden del Field Set.
        for (Schema.FieldSetMember member : Schema.SObjectType.Contact.FieldSets.AccountContactsList.getFields()) {
            String fieldName = member.getFieldPath();
            Schema.SObjectField fieldToken = contactFields.get(fieldName);

            // El datatable necesita propiedades simples, no rutas de relaciones.
            if (fieldToken == null || selectedFields.contains(fieldName)) {
                continue;
            }

            // Verifica si el campo es accesible antes de agregarlo a la lista de campos seleccionados.
            Schema.DescribeFieldResult d = fieldToken.getDescribe();
            if (!d.isAccessible()) {
                continue;
            }

            // Agrega el campo a la lista de campos seleccionados y construye la columna correspondiente.
            FieldColumnWrapper col = new FieldColumnWrapper();
            col.label = d.getLabel();
            col.fieldPath = fieldName;
            col.type = getDatatableType(d.getType());
            result.fields.add(col);
            selectedFields.add(fieldName);
        }

        // Construye la consulta SOQL para obtener los contactos.
        String query = 'SELECT ' + String.join(selectedFields, ', ')
            + ' FROM Contact WHERE AccountId = :accountId';
        if (String.isNotBlank(searchText)) {
            if (searchableFields.isEmpty()) {
                return result;
            }

            // Agrega condiciones de búsqueda para los campos accesibles.
            String term = '%' + searchText.trim() + '%';
            List<String> searchConditions = new List<String>();
            for (String fieldName : searchableFields) {
                searchConditions.add(fieldName + ' LIKE :term');
            }
            query += ' AND (' + String.join(searchConditions, ' OR ') + ')';
        }
        if (contactFields.get('Name').getDescribe().isAccessible()) {
            query += ' ORDER BY Name ASC';
        }
        query += ' LIMIT 50';

        result.contacts = Database.query(query);
        return result;
    }

    // Mapea los tipos de campo de Salesforce a los tipos de columna del datatable.
    private static String getDatatableType(Schema.DisplayType fieldType) {
        if (fieldType == Schema.DisplayType.Email) return 'email';
        if (fieldType == Schema.DisplayType.Phone) return 'phone';
        if (fieldType == Schema.DisplayType.Url) return 'url';
        if (fieldType == Schema.DisplayType.Boolean) return 'boolean';
        if (fieldType == Schema.DisplayType.Date) return 'date-local';
        if (fieldType == Schema.DisplayType.DateTime) return 'date';
        if (fieldType == Schema.DisplayType.Currency) return 'currency';
        if (fieldType == Schema.DisplayType.Percent) return 'percent';
        if (fieldType == Schema.DisplayType.Double
            || fieldType == Schema.DisplayType.Integer
            || fieldType == Schema.DisplayType.Long) {
            return 'number';
        }
        return 'text';
    }

    // Elimina un contacto por su Id.
    @AuraEnabled
    public static void deleteContact(Id contactId) {
        if (contactId == null) return;

        delete [SELECT Id FROM Contact WHERE Id = :contactId LIMIT 1];
    }
}