public with sharing class CallLogInsightsController {
    @AuraEnabled(cacheable=true)
    public static CallLog__c getCallLogInsights(Id recordId) {
        return [
            SELECT Id,
                   Name,
                   Process_Improvement_Insights__c,
                   Agent_Improvement_Insights__c,
                   Quality_Of_Call__c
            FROM CallLog__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }
}