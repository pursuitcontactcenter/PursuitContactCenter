public class CallLogPromptBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id FROM CallLog__c WHERE PromptStatus__c = NULL'
        );
    }

    public void execute(Database.BatchableContext bc, List<CallLog__c> scope) {
        for (CallLog__c lc : scope) {
            try {
                String jsonData = PromptInvoker_1.FetchRulesDetails(lc.Id, 'Real Estate CC');
                PromptInvoker_1.StringToJson(jsonData, 'In-Progress', 'Real Estate CC');
                System.debug(' Prompt invoked successfully for CallLog Id: ' + lc.Id);
            } catch (Exception e) {
                System.debug(' Error for CallLog Id: ' + lc.Id + ' → ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('🎯 All CallLog records processed.');
    }
}

/*
CallLogProcessor.processDriveFiles();

CallLogPromptBatch batchJob = new CallLogPromptBatch();
Database.executeBatch(batchJob, 10); // 10 records per batch = safe
*/