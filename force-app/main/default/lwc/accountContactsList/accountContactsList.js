import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { NavigationMixin } from 'lightning/navigation';
import getAccountContacts from '@salesforce/apex/AccountContactsController.getAccountContacts';
import deleteContact from '@salesforce/apex/AccountContactsController.deleteContact';

export default class AccountContactsList extends NavigationMixin(LightningElement) {
   // ID de la cuenta enviado automáticamente por la página de detalle
    @api recordId; 
    
    @track contacts = [];
    @track columns = [];
    @track searchKey = '';
    @track isLoading = true;
    @track isFlowModalOpen = false;
    @track isEditModalOpen = false;
    @track editContactId = null;

    // Variables para ordenar
    @track sortedBy = 'Name';
    @track sortedDirection = 'asc';

    wiredContactsResult;

    // Wire para obtener datos de Apex usando Field Sets y Búsqueda
    @wire(getAccountContacts, { accountId: '$recordId', searchText: '$searchKey' })
    wiredContacts(result) {
        this.wiredContactsResult = result;
        this.isLoading = true;

        if (!this.recordId) {
            this.contacts = [];
            this.columns = [];
            this.isLoading = false;
            return;
        }

        if (result.data) {
            const fieldSetMembers = result.data.fields || [];
            const rawContacts = result.data.contacts || [];

            // Construir dinámicamente las columnas desde el Field Set
            this.buildColumns(fieldSetMembers);

            // Procesar contactos para ordenar y visualizar
            this.contacts = rawContacts.map(contact => ({
                ...contact,
                ContactUrl: `/lightning/r/Contact/${contact.Id}/view`
            }));
            this.sortData(this.sortedBy, this.sortedDirection);

            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error', 'Error al cargar contactos: ' + result.error.body?.message, 'error');
            this.isLoading = false;
        }
    }

    // Construye dinámicamente las columnas basándose en el Field Set
    buildColumns(fieldSetMembers) {
        let dynamicColumns = fieldSetMembers.map(field => {
            const column = {
                label: field.label,
                fieldName: field.fieldPath,
                type: field.type || 'text',
                sortable: true
            };

            if (field.fieldPath === 'Name') {
                column.fieldName = 'ContactUrl';
                column.type = 'url';
                column.typeAttributes = {
                    label: { fieldName: 'Name' },
                    target: '_self'
                };
            }

            return column;
        });

        // Añadir columna de acciones (editar y eliminar)
        dynamicColumns.push({
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Editar', name: 'edit_contact', iconName: 'utility:edit' },
                    { label: 'Eliminar', name: 'remove_contact', iconName: 'utility:delete' }
                ]
            }
        });

        this.columns = dynamicColumns;
    }

    // Getter para verificar si hay contactos
    get hasContacts() {
        return this.contacts && this.contacts.length > 0;
    }

    // Manejador del buscador
    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    // Manejador de acciones en las filas (editar y eliminar)
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit_contact') {
            this.openEditModal(row.Id);
        } else if (actionName === 'remove_contact') {
            this.handleDeleteContact(row.Id);
        }
    }

    // Abre un modal interno para editar el contacto sin salir de la página
    openEditModal(contactId) {
        this.editContactId = contactId;
        this.isEditModalOpen = true;
    }

    closeEditModal() {
        this.isEditModalOpen = false;
        this.editContactId = null;
    }

    // Manejadores de éxito y error al editar un contacto
    handleEditSuccess() {
        this.showToast('Éxito', 'Contacto actualizado correctamente', 'success', 'short');
        this.closeEditModal();
        this.refreshContacts();
    }

    handleEditError(event) {
        const message = event.detail?.detail || 'No se pudo actualizar el contacto.';
        const translated = message
            .replace(/Contact/gi, 'Contacto')
            .replace(/was saved/gi, 'se guardó')
            .replace(/was not saved/gi, 'no se guardó')
            .replace(/Error/gi, 'Error');
        this.showToast('Error', translated, 'error', 'short');
    }

    // Refresca la lista sin depender del flujo de navegación
    refreshContacts() {
        if (this.wiredContactsResult) {
            refreshApex(this.wiredContactsResult);
        }
    }

    // Llamada a refreshContacts en connectedCallback y renderedCallback para asegurar que los datos se carguen correctamente
    connectedCallback() {
        this.refreshContacts();
    }

    renderedCallback() {
        if (this._hasRenderedOnce) {
            return;
        }
        this._hasRenderedOnce = true;
        this.refreshContacts();
    }

    // Eliminar contacto mediante Apex
    async handleDeleteContact(contactId) {
        try {
            const confirmed = await LightningConfirm.open({
                label: 'Confirmar eliminación',
                message: '¿Estás seguro de que deseas eliminar este contacto?',
                variant: 'header'
            });

            if (!confirmed) {
                return;
            }

            this.isLoading = true;
            await deleteContact({ contactId: contactId });
            this.showToast('Éxito', 'Contacto eliminado correctamente', 'success', 'short');
            this.refreshContacts();
        } catch (error) {
            const message = error?.body?.message || error?.message || 'Error inesperado.';
            this.showToast('Error', 'No se pudo completar la eliminación: ' + message, 'error', 'short');
        } finally {
            this.isLoading = false;
        }
    }

    // Manejo de ordenar en la datatable
    handleSort(event) {
        const { fieldName: sortedBy, sortDirection: sortedDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortedDirection;
        this.sortData(sortedBy, sortedDirection);
    }

    // Función para ordenar los datos de la tabla
    sortData(fieldname, direction) {
        const sortField = fieldname === 'ContactUrl' ? 'Name' : fieldname;
        const parseData = [...(this.contacts || [])];
        const isReverse = direction === 'desc' ? -1 : 1;

        if (!sortField) {
            this.contacts = parseData;
            return;
        }

        parseData.sort((a, b) => {
            const valueA = a?.[sortField];
            const valueB = b?.[sortField];

            if (valueA == null && valueB == null) {
                return 0;
            }
            if (valueA == null) {
                return 1 * isReverse;
            }
            if (valueB == null) {
                return -1 * isReverse;
            }

            const normalizedA = typeof valueA === 'string' ? valueA.toLowerCase() : valueA;
            const normalizedB = typeof valueB === 'string' ? valueB.toLowerCase() : valueB;

            if (typeof normalizedA === 'number' && typeof normalizedB === 'number') {
                return (normalizedA - normalizedB) * isReverse;
            }

            const textA = String(normalizedA).toLowerCase();
            const textB = String(normalizedB).toLowerCase();
            return textA.localeCompare(textB) * isReverse;
        });

        this.contacts = parseData;
    }

    // Lógica para abrir el modal del Screen Flow
    handleOpenFlowModal() {
        this.isFlowModalOpen = true;
    }

    // Lógica para cerrar el modal del Screen Flow
    handleCloseFlowModal() {
        this.isFlowModalOpen = false;
    }

    // Pasa la variable recordId al Screen Flow
    get flowInputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    // Refrescar automáticamente al terminar el flujo
    handleFlowStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            this.showToast('Éxito', 'Contacto creado correctamente', 'success', 'short');
            this.isFlowModalOpen = false;
            this.refreshContacts();
        }
    }

    // Notificación Toast auxiliar
    showToast(title, message, variant, duration = 'short') {
        const normalizedMessage = message
            .replace(/Contact\s+"/gi, 'Contacto "')
            .replace(/ was saved\./gi, ' se guardó.')
            .replace(/ was saved/gi, ' se guardó')
            .replace(/saved\./gi, 'guardado.')
            .replace(/saved/gi, 'guardado');

        this.dispatchEvent(new ShowToastEvent({ title, message: normalizedMessage, variant, mode: 'dismissible', duration }));
    }
}