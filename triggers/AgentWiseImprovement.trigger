/*trigger AgentWiseImprovement on CallLog__c (after update) {
    List<CallLog__c> logsToProcess = new List<CallLog__c>();
    Id agentId;
    String collectedProcessImprovementData = '';
    String collectedAgentImprovementData = '';

    for (CallLog__c cl : Trigger.new) {
        CallLog__c oldCl = Trigger.oldMap.get(cl.Id);
        CallLog__c newCl = cl;

        if (cl.Process_Improvement_Insights__c != null && cl.Agent_Improvement_Insights__c != null) {
            logsToProcess.add(cl);            
            collectedProcessImprovementData += 'Process_Improvement_Insights__c : ' + cl.Process_Improvement_Insights__c + ','+'\n';
            collectedAgentImprovementData += 'Agent_Improvement_Insights__c : ' + cl.Agent_Improvement_Insights__c + ','+ '\n';

            if (agentId == null && cl.AgentID__c != null) {
                agentId = cl.AgentID__c;
            }
        }
    }

    if (logsToProcess.isEmpty() || agentId == null) {
        return;
    }

    Agent__c agent = [
        SELECT Id, Process_Improvement_Insights__c, Agent_Improvement_Insights__c
        FROM Agent__c
        WHERE Id = :agentId
        LIMIT 1
    ];

    if (agent != null) {
        if (agent.Process_Improvement_Insights__c != null) {
            collectedProcessImprovementData += 'Process_Improvement_Insights__c: ' + agent.Process_Improvement_Insights__c + '\n';
        }
        if (agent.Agent_Improvement_Insights__c != null) {
            collectedAgentImprovementData += 'Agent_Improvement_Insights__c: ' + agent.Agent_Improvement_Insights__c + '\n';
        }
    }
    //System.debug(collectedProcessImprovementData + '' + collectedAgentImprovementData);
    //----------------------------------- Call Agent_Process_Improvement_Prompt prompt -----------------------
    try{
  
            ConnectApi.WrappedValue callLogInstance = new ConnectApi.WrappedValue();
            callLogInstance.value = collectedProcessImprovementData;
            ConnectApi.WrappedValue callLogInstance1 = new ConnectApi.WrappedValue();
            callLogInstance1.value = collectedAgentImprovementData;
    
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

        } catch (Exception e) {
            System.debug('⚠️ Error: ' + e.getMessage());
        }
}*/
trigger AgentWiseImprovement on CallLog__c (after update) {
    AgentImprovementHelper.processCallLogs(Trigger.new, Trigger.oldMap);
}