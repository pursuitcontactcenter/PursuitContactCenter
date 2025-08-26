//********************************************************** Previous Code ******************************************************
/*public class TranscriptProcessorQueueable implements Queueable, Database.AllowsCallouts {
    private Id logId;
    private String transcriptId;
    private String callStatus;
    private String promptStatus;

    public TranscriptProcessorQueueable(Id logId, String transcriptId, String callStatus, String promptStatus) {
    this.logId = logId;
    this.transcriptId = transcriptId;
    this.callStatus = callStatus;
    this.promptStatus = promptStatus;
    }


    public void execute(QueueableContext context) {
        try {
            if(callStatus == 'In-Progress'){
            String result = AssemblyAIFromSalesforce_UP_1.getTranscriptionResult(transcriptId);
            //System.debug('=== result ===' + result);
            
            if (!String.isBlank(result)) {
                CallLog__c log = new CallLog__c(
                    Id = logId,
                    transcript_Desc__c = result,
                    Call_Status__c = 'Closed'
                );
                try {
                    String jsonData = PromptInvoker_1.FetchRulesDetails(log.Id);
                    PromptInvoker_1.StringToJson(jsonData,  callStatus );
                    System.debug('Prompt invoked successfully');
                } catch (Exception ex) {
                    System.debug('Prompt error for log ' + log.Id + ': ' + ex.getMessage());
                }
                update log;
            }        
        }
         else if (callStatus == 'Closed' && (promptStatus == 'Failed' || promptStatus == null)) {
                try {
                    String jsonData = PromptInvoker_1.FetchRulesDetails(logId);
                    PromptInvoker_1.StringToJson(jsonData ,  callStatus );
                    System.debug('Prompt invoked successfully');
                } catch (Exception e) {
                    System.debug('Prompt error for log ' + logId + ': ' + e.getMessage());
                }
            }else{
                System.debug('Nothing....');
            }  
        } catch (Exception e) {
            System.debug('Error fetching transcript for ID ' + transcriptId + ': ' + e.getMessage());
        }
    }
}*/
//**********************************************************  Updated Code  ******************************************************
public class TranscriptProcessorQueueable implements Queueable, Database.AllowsCallouts {
    private Id logId;
    private String transcriptText;
    private String callStatus;
    private String promptStatus;
    private String Feature_CC;
    
    public TranscriptProcessorQueueable(Id logId, String transcriptText, String callStatus, String promptStatus,String Feature_CC) {
        this.logId = logId;
        this.transcriptText = transcriptText;
        this.callStatus = callStatus;
        this.promptStatus = promptStatus;
        this.Feature_CC =  Feature_CC;
    }


    public void execute(QueueableContext context) {
        try {
            //System.debug('Entry =========================================> ');
            if(callStatus == 'In-Progress'){
              //String result = transcriptText;  
            //String result = AssemblyAIFromSalesforce_UP_1.getTranscriptionResult(transcriptId);
            //System.debug('=== result ===' + result);
            
            if (!String.isBlank(transcriptText)) {
                CallLog__c log = new CallLog__c(
                    Id = logId,
                    transcript_Desc__c = transcriptText,
                    Call_Status__c = 'Closed'
                );
                try {
                    String jsonData = PromptInvoker_1.FetchRulesDetails(log.Id , this.Feature_CC);
                    PromptInvoker_1.StringToJson(jsonData,  callStatus , this.Feature_CC);
                    System.debug('Prompt invoked successfully');
                } catch (Exception ex) {
                    System.debug('Prompt error for log ' + log.Id + ': ' + ex.getMessage());
                }
                update log;
            }        
        }
         else if (callStatus == 'Closed' && (promptStatus == 'Failed' || promptStatus == null)) {
                try {
                    String jsonData = PromptInvoker_1.FetchRulesDetails(logId , this.Feature_CC);
                    PromptInvoker_1.StringToJson(jsonData ,  callStatus , this.Feature_CC);
                    System.debug('Prompt invoked successfully');
                } catch (Exception e) {
                    System.debug('Prompt error for log ' + logId + ': ' + e.getMessage());
                }
            }else{
                System.debug('Nothing....');
            }  
        } catch (Exception e) {
            System.debug('Error fetching transcript for ID ' + transcriptText + ': ' + e.getMessage());
        }
    }
}