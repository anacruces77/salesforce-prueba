@IsTest
private class AccountContactsControllerTest {
  private static final String TEST_ACCOUNT_NAME = 'AccountContactsControllerTest Account';

  @TestSetup
  static void createTestData() {
    Account account = new Account(Name = TEST_ACCOUNT_NAME);
    insert account;

    insert new List<Contact>{
      new Contact(
        FirstName = 'Ana',
        LastName = 'Alfa',
        Email = 'ana.alfa@example.test',
        Phone = '555-0101',
        Title = 'Directora',
        AccountId = account.Id
      ),
      new Contact(
        FirstName = 'Bea',
        LastName = 'Beta',
        Email = 'bea.beta@example.test',
        Phone = '555-0102',
        Title = 'Analista',
        AccountId = account.Id
      ),
      new Contact(
        FirstName = 'Zoe',
        LastName = 'Zulu',
        Email = 'zoe.zulu@example.test',
        Phone = '555-0103',
        Title = 'Gestora',
        AccountId = account.Id
      )
    };
  }

  @IsTest
  static void returnsContactsAndFieldSetColumnsInNameOrder() {
    Account account = getTestAccount();

    Test.startTest();
    AccountContactsController.ContactDataWrapper result = AccountContactsController.getAccountContacts(
      account.Id,
      null
    );
    Test.stopTest();

    System.assertEquals(
      3,
      result.contacts.size(),
      'Debe devolver los contactos de la cuenta.'
    );
    System.assertEquals(
      'Ana Alfa',
      result.contacts[0].Name,
      'Debe ordenar los contactos por nombre.'
    );
    System.assertEquals(
      'Bea Beta',
      result.contacts[1].Name,
      'Debe ordenar los contactos por nombre.'
    );
    System.assertEquals(
      'Zoe Zulu',
      result.contacts[2].Name,
      'Debe ordenar los contactos por nombre.'
    );

    List<String> returnedFieldPaths = new List<String>();
    for (AccountContactsController.FieldColumnWrapper field : result.fields) {
      returnedFieldPaths.add(field.fieldPath);
      System.assertNotEquals(
        null,
        field.label,
        'Cada columna debe incluir su etiqueta.'
      );
      System.assertNotEquals(
        null,
        field.type,
        'Cada columna debe incluir un tipo.'
      );
    }

    List<String> expectedFieldPaths = new List<String>();
    Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
    for (
      Schema.FieldSetMember member : Schema.SObjectType.Contact.FieldSets.AccountContactsList.getFields()
    ) {
      String fieldPath = member.getFieldPath();
      Schema.SObjectField fieldToken = contactFields.get(fieldPath);
      if (
        fieldPath != 'Id' &&
        fieldToken != null &&
        fieldToken.getDescribe().isAccessible()
      ) {
        expectedFieldPaths.add(fieldPath);
      }
    }

    System.assertEquals(
      expectedFieldPaths,
      returnedFieldPaths,
      'Las columnas devueltas deben coincidir con los campos directos accesibles del Field Set.'
    );
  }

  @IsTest
  static void searchesByNameEmailAndPhone() {
    Account account = getTestAccount();

    Test.startTest();
    AccountContactsController.ContactDataWrapper nameResult = AccountContactsController.getAccountContacts(
      account.Id,
      'Beta'
    );
    AccountContactsController.ContactDataWrapper emailResult = AccountContactsController.getAccountContacts(
      account.Id,
      'bea.beta@example.test'
    );
    AccountContactsController.ContactDataWrapper phoneResult = AccountContactsController.getAccountContacts(
      account.Id,
      '555-0102'
    );
    Test.stopTest();

    System.assertEquals(
      1,
      nameResult.contacts.size(),
      'Debe buscar por nombre.'
    );
    System.assertEquals('Bea Beta', nameResult.contacts[0].Name);
    System.assertEquals(
      1,
      emailResult.contacts.size(),
      'Debe buscar por email.'
    );
    System.assertEquals('Bea Beta', emailResult.contacts[0].Name);
    System.assertEquals(
      1,
      phoneResult.contacts.size(),
      'Debe buscar por teléfono.'
    );
    System.assertEquals('Bea Beta', phoneResult.contacts[0].Name);
  }

  @IsTest
  static void returnsEmptyDataWhenAccountIdIsNull() {
    Test.startTest();
    AccountContactsController.ContactDataWrapper result = AccountContactsController.getAccountContacts(
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result.fields);
    System.assertNotEquals(null, result.contacts);
    System.assertEquals(0, result.fields.size());
    System.assertEquals(0, result.contacts.size());
  }

  @IsTest
  static void deletesContactById() {
    Contact contact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'bea.beta@example.test'
      LIMIT 1
    ];

    Test.startTest();
    AccountContactsController.deleteContact(contact.Id);
    AccountContactsController.deleteContact(null);
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Contact WHERE Id = :contact.Id],
      'El contacto debe eliminarse.'
    );
  }

  private static Account getTestAccount() {
    return [
      SELECT Id
      FROM Account
      WHERE Name = :TEST_ACCOUNT_NAME
      LIMIT 1
    ];
  }
}
