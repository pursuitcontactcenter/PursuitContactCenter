import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import CALLLOG_FIELDS from '@salesforce/schema/CallLog__c';
import getFilePathways from '@salesforce/apex/CallDetailsController.getFilePathways';


const FIELDS = [
    'CallLog__c.Agent_Improvement_Insights__c',
    'CallLog__c.Process_Improvement_Insights__c',
    'CallLog__c.Quality_Of_Call__c'
];

export default class CallLogInsights extends LightningElement {
    @api recordId;
    @track agentInsights;
    @track processInsights;
    @track quality;
    @track qualityColor = '';
    @track filePathways;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.quality = data.fields.Quality_Of_Call__c.value;
            this.setQualityColor();

            const agentJson = data.fields.Agent_Improvement_Insights__c.value;
            const processJson = data.fields.Process_Improvement_Insights__c.value;

            this.agentInsights = this.parseInsights(agentJson);
            this.processInsights = this.parseInsights(processJson);
        } else if (error) {
            console.error('Error fetching CallLog__c record', error);
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

    parseInsights(jsonString) {
        try {
            const parsed = JSON.parse(jsonString);
            const guidance = parsed.Guidance ? Object.values(parsed.Guidance) : [];
            return {
                Recommendation: parsed.Recommendation || '',
                Opportunity: parsed.Opportunity || '',
                Guidance: guidance
            };
        } catch (e) {
            console.error('Error parsing JSON:', e);
            return null;
        }
    }

    setQualityColor() {
        if (this.quality < 4) {
            this.qualityColor = 'background-color:#ffe6e6'; // red tint
        } else if (this.quality >= 4 && this.quality < 7) {
            this.qualityColor = 'background-color:#fff8e1'; // yellow tint
        } else {
            this.qualityColor = 'background-color:#e8f5e9'; // green tint
        }
    }

}