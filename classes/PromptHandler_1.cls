public class PromptHandler_1 {
    @future(callout=true)
    public static void invokePrompt(List<Id> callLogIds) {
        for (Id callLogId : callLogIds) {
            try {
                String jsonData = PromptInvoker_1.FetchRulesDetails(callLogId);
                PromptInvoker_1.StringToJson(jsonData, 'In-Progress');
                System.debug('Prompt invoked successfully for: ' + callLogId);
            } catch (Exception ex) {
                System.debug('Prompt invocation failed for: ' + callLogId + ' => ' + ex.getMessage());
            }
        }
        
    }
}