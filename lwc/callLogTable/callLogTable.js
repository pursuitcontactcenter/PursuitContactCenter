import { LightningElement, wire, track } from 'lwc';
import getCallLogs from '@salesforce/apex/CallDetailsController.getCallLogs';

export default class CallLogTable extends LightningElement {
    @track callLogs = [];
    @track selectedCallLogId = null;

    @track sortedBy = '';
    @track sortedDirection = 'asc';

    @wire(getCallLogs)
    wiredCallLogs({ data, error }) {
        if (data) {
            this.callLogs = data.map(log => {
                const quality = log.Quality_Of_Call__c || 0;
                return {
                    ...log,
                    CallLogId__c: log.CallLogId__c,
                    agentName: log.AgentID__r?.Name || '',
                    clientName: log.Client__r?.Name || '',
                    qualityLabel: `${quality}/10`
                };
            });
        } else if (error) {
            console.error('Error loading call logs:', error);
        }
    }

    handleDetailsClick(event) {
        this.selectedCallLogId = event.currentTarget.dataset.id;
    }

    handleBackClick() {
        this.selectedCallLogId = null;
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (!field) return;

        const isSameField = this.sortedBy === field;
        this.sortedDirection = isSameField && this.sortedDirection === 'asc' ? 'desc' : 'asc';
        this.sortedBy = field;

        this.sortData(field, this.sortedDirection);
    }

    sortData(field, direction) {
        const list = [...this.callLogs];

        list.sort((a, b) => {
            let va = this._normalizeForSort(a[field], field);
            let vb = this._normalizeForSort(b[field], field);

            if (typeof va === 'number' && typeof vb === 'number') {
                return direction === 'asc' ? va - vb : vb - va;
            }

            if (va instanceof Date && vb instanceof Date && !isNaN(va) && !isNaN(vb)) {
                return direction === 'asc' ? va - vb : vb - va;
            }

            const sa = (va === null || va === undefined) ? '' : String(va).toLowerCase();
            const sb = (vb === null || vb === undefined) ? '' : String(vb).toLowerCase();

            return direction === 'asc'
                ? sa.localeCompare(sb, 'en', { numeric: true })
                : sb.localeCompare(sa, 'en', { numeric: true });
        });

        this.callLogs = list;
    }

    _normalizeForSort(value, field) {
    if (value === null || value === undefined) return '';

    // CallLogId__c like "CL-0094"
    if (field === 'CallLogId__c' && typeof value === 'string') {
        const match = value.match(/\d+/);
        return match ? parseInt(match[0], 10) : value;
    }

    // Quality like "6.5/10"
    if (field === 'qualityLabel' && typeof value === 'string') {
        const match = value.match(/^[0-9]+(\.[0-9]+)?/);
        return match ? parseFloat(match[0]) : value;
    }

    // Engagement Date yyyy-mm-dd (date sorting)
    if (field === 'Engagement_Date__c' && typeof value === 'string') {
        const parsedDate = Date.parse(value);
        return isNaN(parsedDate) ? value : parsedDate;
    }

    // Mobile like "+918234629035"
    if (field === 'Mobile__c' && typeof value === 'string') {
        const match = value.match(/\d+/);
        return match ? parseInt(match[0], 10) : value;
    }

    // Client like "Client_+918234629035"
    if (field === 'Client__c' && typeof value === 'string') {
        const match = value.match(/\d+/);
        return match ? parseInt(match[0], 10) : value;
    }

    // Duration numeric
    if (field === 'CallDuration__c' && typeof value === 'string') {
        const num = parseFloat(value);
        return isNaN(num) ? value : num;
    }

    if (value instanceof Date) return value;

    if (typeof value === 'object' && value.value !== undefined) {
        value = value.value;
    }

    if (typeof value === 'string' && value.trim() !== '') {
        const num = Number(value.replace(/,/g, ''));
        if (!isNaN(num)) return num;
    } else if (typeof value === 'number') {
        return value;
    }

    const parsed = Date.parse(value);
    if (!isNaN(parsed)) return new Date(parsed);

    return String(value);
}


    get callLogIdArrow() {
        return this.sortedBy === 'CallLogId__c' ? (this.sortedDirection === 'asc' ? '▲' : '▼') : '';
    }
    get categoryArrow() {
        return this.sortedBy === 'Category__c' ? (this.sortedDirection === 'asc' ? '▲' : '▼') : '';
    }
    get agentArrow() {
        return this.sortedBy === 'agentName' ? (this.sortedDirection === 'asc' ? '▲' : '▼') : '';
    }
    get clientArrow() {
        return this.sortedBy === 'clientName' ? (this.sortedDirection === 'asc' ? '▲' : '▼') : '';
    }
    get durationArrow() {
        return this.sortedBy === 'CallDuration__c' ? (this.sortedDirection === 'asc' ? '▲' : '▼') : '';
    }
    get qualityArrow() {
        return this.sortedBy === 'qualityLabel' ? (this.sortedDirection === 'asc' ? '▲' : '▼') : '';
    }
    get mobileArrow() {
        return this.sortedBy === 'Mobile_Number__c' ? (this.sortedDirection === 'asc' ? '▲' : '▼') : '';
    }
    get engagementDateArrow() {
        return this.sortedBy === 'Engagement_Date__c' ? (this.sortedDirection === 'asc' ? '▲' : '▼') : '';
    }
}