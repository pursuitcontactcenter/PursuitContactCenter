import { LightningElement, api, wire, track } from 'lwc';
import getFilePathways from '@salesforce/apex/CallDetailsController.getFilePathways';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = [
    'CallLog__c.Client__r.Name',
    'CallLog__c.Client__r.Account__r.Name',
    'CallLog__c.AgentID__r.Name',
    'CallLog__c.Category__c',
    'CallLog__c.CallType__c',
    'CallLog__c.CallDuration__c',
    'CallLog__c.Engagement_Date__c',
    'CallLog__c.Quality_Of_Call__c',
    'CallLog__c.isMerged__c' // Added field
];

export default class ShowCallDetails extends LightningElement {
    @api recordId;
    @track clientName;
    @track accountName;
    @track agent;
    @track category;
    @track callType;
    @track duration;
    @track engagementDate;
    @track quality;
    @track isMerged = false; // Track merged status
    @track filePathways;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.clientName = data.fields.Client__r.displayValue;
            this.accountName = data.fields.Client__r.value.fields.Account__r.displayValue;
            this.agent = data.fields.AgentID__r.displayValue;
            this.category = data.fields.Category__c.value;
            this.callType = data.fields.CallType__c.value;
            this.duration = data.fields.CallDuration__c.value;
            this.engagementDate = data.fields.Engagement_Date__c.value;
            this.quality = data.fields.Quality_Of_Call__c.value;
            this.isMerged = data.fields.isMerged__c.value === true; // store boolean
        } else if (error) {
            console.error('Error loading CallLog:', error);
        }
    }

    @wire(getFilePathways, { callLogId: '$recordId' })
    wiredFilePaths({ error, data }) {
        if (data) {
            const grouped = {};
            data.forEach(item => {
                const l1 = item.L1_Prompt__r?.L1_Prompt_Name__c || 'General';
                if (!grouped[l1]) {
                    grouped[l1] = [];
                }
                grouped[l1].push({
                    l2: item.L2_Prompt__r?.Name,
                    answer: item.Prompt_Answer__c
                });
            });

            this.filePathways = Object.keys(grouped).map(l1 => ({
                l1Prompt: l1,
                entries: grouped[l1]
            }));
        } else if (error) {
            console.error('Error loading file pathways:', error);
        }
    }

    get starString() {
        const full = Math.floor(this.quality / 2);
        const half = this.quality % 2 >= 1 ? 1 : 0;
        const empty = 5 - full - half;
        return '★'.repeat(full) + (half ? '⯨' : '') + '☆'.repeat(empty);
    }

    get showDisconnectedCall() {
        return this.isMerged;
    }
}