import { LightningElement, wire, track } from 'lwc';
import getAgentForCurrentUser from '@salesforce/apex/AgentPerformanceManagerView.getAgentForCurrentUser';

export default class AgentPerformanceManagerView extends LightningElement {
    @track agentList = [];
    @track error;

    @wire(getAgentForCurrentUser)
    wiredAgents({ error, data }) {
        if (data) {
            this.agentList = data.map((agent) => {
                let processInsights = {};
                let agentInsights = {};

                try {
                    processInsights = agent.Process_Improvement_Insights__c
                        ? JSON.parse(agent.Process_Improvement_Insights__c)
                        : {};
                } catch (e) {
                    console.error("Failed to parse Process JSON", e);
                }

                try {
                    agentInsights = agent.Agent_Improvement_Insights__c
                        ? JSON.parse(agent.Agent_Improvement_Insights__c)
                        : {};
                } catch (e) {
                    console.error("Failed to parse Agent JSON", e);
                }

                const processGuidanceArray = processInsights.Guidance
                    ? Object.keys(processInsights.Guidance)
                          .sort((a, b) => Number(a) - Number(b))
                          .map((key) => ({
                              key,
                              value: processInsights.Guidance[key]
                          }))
                    : [];

                const agentGuidanceArray = agentInsights.Guidance
                    ? Object.keys(agentInsights.Guidance)
                          .sort((a, b) => Number(a) - Number(b))
                          .map((key) => ({
                              key,
                              value: agentInsights.Guidance[key]
                          }))
                    : [];
                    console.error("agent.User__r?.FullPhotoUrl", agent.User__r?.FullPhotoUrl);

                return {
                    ...agent,
                    //userImage: '/img/avatar1.png', // fallback image
                    userName: agent.User__r?.Name || 'Unknown User',
                    isExpanded: false,
                    userImage: agent.User__r?.FullPhotoUrl,

                    // Parsed fields
                    processRecommendation: processInsights.Recommendation,
                    processOpportunity: processInsights.Opportunity,
                    processGuidance: processGuidanceArray,

                    agentRecommendation: agentInsights.Recommendation,
                    agentOpportunity: agentInsights.Opportunity,
                    agentGuidance: agentGuidanceArray
                };
            });
        } else if (error) {
            this.error = error;
            this.agentList = [];
        }
    }

    toggleDetails(event) {
        const clickedId = event.currentTarget.dataset.id;
        this.agentList = this.agentList.map(agent => ({
            ...agent,
            isExpanded: agent.Id === clickedId ? !agent.isExpanded : false
        }));
    }
}