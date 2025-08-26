public class AgentImprovementHelper {
    public static void processCallLogs(List<CallLog__c> newLogs, Map<Id, CallLog__c> oldLogs) {
        List<CallLog__c> logsToProcess = new List<CallLog__c>();
        Id agentId;
        String collectedProcessImprovementData = '';
        String collectedAgentImprovementData = '';

        for (CallLog__c cl : newLogs) {
            if (cl.Process_Improvement_Insights__c != null && cl.Agent_Improvement_Insights__c != null) {
                logsToProcess.add(cl);
                collectedProcessImprovementData += 'Process_Improvement_Insights : ' + cl.Process_Improvement_Insights__c + ',\n';
                collectedAgentImprovementData += 'Agent_Improvement_Insights : ' + cl.Agent_Improvement_Insights__c + ',\n';

                if (agentId == null && cl.AgentID__c != null) {
                    agentId = cl.AgentID__c;
                }
            }
        }

        if (logsToProcess.isEmpty() || agentId == null) return;

        Agent__c agent = [SELECT Id, Process_Improvement_Insights__c, Agent_Improvement_Insights__c
                          FROM Agent__c WHERE Id = :agentId LIMIT 1];

        if (agent != null) {
            if (agent.Process_Improvement_Insights__c != null) {
                collectedProcessImprovementData += 'Process_Improvement_Insights: ' + agent.Process_Improvement_Insights__c + '\n';
            }
            if (agent.Agent_Improvement_Insights__c != null) {
                collectedAgentImprovementData += 'Agent_Improvement_Insights: ' + agent.Agent_Improvement_Insights__c + '\n';
            }
        }

        callPromptAndStoreInsights(collectedProcessImprovementData, collectedAgentImprovementData,agentId);
    }

    private static void callPromptAndStoreInsights(String processData, String agentData, String agentId) {
        try {
            ConnectApi.WrappedValue callLogInstance = new ConnectApi.WrappedValue();
            callLogInstance.value = processData;
            ConnectApi.WrappedValue callLogInstance1 = new ConnectApi.WrappedValue();
            callLogInstance1.value = agentData;
    
            Map<String, ConnectApi.WrappedValue> inputParamsMap = new Map<String, ConnectApi.WrappedValue>();
            inputParamsMap.put('Input:Process_Improvement_Insights', callLogInstance);
            inputParamsMap.put('Input:Agent_Improvement_Insights', callLogInstance1);

            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.inputParams = inputParamsMap;
            promptInput.isPreview = false;

            promptInput.additionalConfig = new ConnectApi.EinsteinLLmAdditionalConfigInput();

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Agent_Process_Improvement_Prompt', promptInput);

            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
            System.debug('Prompt response text: ' + response.text);
            
            String jsonDetails = response.text.substring(response.text.indexOf('{'))
    .replaceAll('```', '')
    .replaceAll('`', '') 
    .replaceAll('\u00A0', ' ')
    .trim();
            //String jsonDetails = response.text.substring(response.text.indexOf('{'))
            CallLogResponse parsed = (CallLogResponse)JSON.deserialize(jsonDetails, CallLogResponse.class);

            System.debug('Process Opportunity: ' + JSON.serialize(parsed.Process_Improvement_Insights));
            System.debug('Agent Guidance: ' + JSON.serialize(parsed.Agent_Improvement_Insights));
            // ----------------------- INSERT INTO AGENT OBJECT -----------------------
            
        if (agentId != null) {
            Agent__c agentToUpdate = new Agent__c(
                Id = agentId,
                Process_Improvement_Insights__c = JSON.serialize(parsed.Process_Improvement_Insights),
                Agent_Improvement_Insights__c = JSON.serialize(parsed.Agent_Improvement_Insights)
            );
            
            update agentToUpdate;
        } else {
            System.debug('Agent Id not found, update skipped.');
        }

        } catch (Exception e) {
            System.debug('Prompt Error: ' + e.getMessage());
        }
    }

    public class CallLogResponse {
    public Insights Agent_Improvement_Insights;
    public Insights Process_Improvement_Insights;

}
    public class Insights {
    public String Opportunity;
    public String Recommendation;
    public Map<String, String> Guidance;
}
}