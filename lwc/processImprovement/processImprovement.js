import { LightningElement, wire } from "lwc";
import getLastFiveCallDetails from "@salesforce/apex/CallDetailsController.getLastFiveCallDetails";

export default class ProcessImprovement extends LightningElement {
    opportunities = [];
    selectedCall = null;
    showDetail = false;
    rating_wise_color = {};

    @wire(getLastFiveCallDetails)
    wiredCallLogs({ error, data }) {
        if (data) {
            this.opportunities = data.map((item) => {
                // Parse the JSON fields
                let processInsights = {};
                let agentInsights = {};

                try {
                    processInsights = item.Process_Improvement_Insights__c
                        ? JSON.parse(item.Process_Improvement_Insights__c)
                        : {};
                } catch (e) {
                    console.error("Failed to parse Process JSON", e);
                }

                try {
                    agentInsights = item.Agent_Improvement_Insights__c
                        ? JSON.parse(item.Agent_Improvement_Insights__c)
                        : {};
                } catch (e) {
                    console.error("Failed to parse Agent JSON", e);
                }

                return {
                    id: item.Id,
                    title: item.Name,
                    rating: item.Quality_Of_Call__c,
                    time: item.Engagement_Date__c,
                    callDuration: item.CallDuration__c,
                    // rating_color : item.rating_color ? item.rating_color : '',

                    // Parsed process insights
                    processRecommendation: processInsights.Recommendation,
                    processOpportunity: processInsights.Opportunity,
                    processGuidance: processInsights.Guidance,

                    // Parsed agent insights
                    agentRecommendation: agentInsights.Recommendation,
                    agentOpportunity: agentInsights.Opportunity,
                    agentGuidance: agentInsights.Guidance
                };
            });
        } else if (error) {
            console.error("Error:", error);
        }
    }

    get styledOpportunities() {
        return this.opportunities.map((item) => {
            let color = "";
            // if(!this.opportunities[item.id].rating_color ){
            //     this.opportunities[item.id].rating_color = '';
            // }
            if (item.rating >= 7) {
                color = "#52bd69cf"; // green
            } else if (item.rating >= 4) {
                color = "#c4a12ba6"; // yellow
            } else {
                color = "#e39174db"; // red
            }
            this.rating_wise_color[item.id] = {
                ...this.rating_wise_color[item.id],
                color: color
            }
            // this.opportunities[item.id].rating_color = color ? color : '';
            return {
                ...item,
                style: `background-color: ${color};`,
                // styleBorder : `border-left: 4px solid ${color};`
            };
        });
    }

    handleCallClick(event) {
        const callId = event.currentTarget.dataset.id;
        this.selectedCall = this.opportunities.find((item) => item.id === callId);
        this.selectedCall = {
            ...this.selectedCall,
            style: `background-color: ${this.rating_wise_color[callId].color};`,
            styleBorder : `border-left: 4px solid ${this.rating_wise_color[callId].color};`
        }
        this.showDetail = true;

        // Log formatted JSON
        console.log('Rating Color Map:', JSON.stringify(this.selectedCall, null, 2));
    }


    handleBack() {
        this.selectedCall = null;
        this.showDetail = false;
    }

    get processGuidanceSteps() {
        if (!this.selectedCall || !this.selectedCall.processGuidance) {
            return [];
        }

        // Return array of { key, value } for template iteration
        return Object.keys(this.selectedCall.processGuidance)
            .sort((a, b) => Number(a) - Number(b)) // optional sort
            .map((key) => ({
                key,
                value: this.selectedCall.processGuidance[key]
            }));
    }
    get agentGuidanceSteps() {
        if (!this.selectedCall || !this.selectedCall.agentGuidance) {
            return [];
        }

        // Return array of { key, value } for template iteration
        return Object.keys(this.selectedCall.agentGuidance)
            .sort((a, b) => Number(a) - Number(b)) // optional sort
            .map((key) => ({
                key,
                value: this.selectedCall.agentGuidance[key]
            }));
    }
}