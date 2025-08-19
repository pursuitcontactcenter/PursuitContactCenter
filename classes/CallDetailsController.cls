public with sharing class CallDetailsController {
    /*
    @AuraEnabled(cacheable=true)
    public static List<FilePathDetail__c> getFilePathways(Id callLogId) {
        return [
            SELECT Id, Name, 
                   L1_Prompt__r.Name, 
                   L1_Prompt__r.L1_Prompt_Name__c,
                   L2_Prompt__r.Name
            FROM FilePathDetail__c
            WHERE CallLog__c = :callLogId
        ];
    }
    

    @AuraEnabled(cacheable=true)
    public static List<FilePathDetail__c> getFilePathways(Id callLogId) {
        return [
            SELECT Id, Prompt_Answer__c,
                   L1_Prompt__r.L1_Prompt_Name__c,
                   L2_Prompt__r.Name,
                   L2_Prompt__r.L2_Prompt_Name__c
            FROM FilePathDetail__c
            WHERE CallLog__c = :callLogId
        ];
    }
    */

    @AuraEnabled(cacheable=true)
    public static List<FilePathDetail__c> getFilePathways(Id callLogId) {
        List<FilePathDetail__c> allPaths = [
            SELECT Id, Prompt_Answer__c,
                L1_Prompt__r.L1_Prompt_Name__c,
                L2_Prompt__r.Name,
                L2_Prompt__r.L2_Prompt_Name__c,
                CreatedDate
            FROM FilePathDetail__c
            WHERE CallLog__c = :callLogId
            ORDER BY L2_Prompt__r.Name, CreatedDate ASC
        ];

    Map<String, FilePathDetail__c> uniqueByL2 = new Map<String, FilePathDetail__c>();
    for (FilePathDetail__c path : allPaths) {
        String l2Id = path.L2_Prompt__r?.Name;
        if (l2Id != null && !uniqueByL2.containsKey(l2Id)) {
            uniqueByL2.put(l2Id, path);
        }
    }

    return uniqueByL2.values();
}


    // For creating the dashboard
    @AuraEnabled(cacheable=true)
    public static List<CallLog__c> getCallLogs() {
        return [
            SELECT CallLogId__c, Id, Name, Category__c, AgentID__c, AgentID__r.Name,
                Client__c, Client__r.Name, Mobile_Number__c, 
                CallDuration__c, Quality_Of_Call__c, Engagement_Date__c, PromptStatus__c, isMerged__c
            FROM CallLog__c
            WHERE PromptStatus__c = 'Success'
            ORDER BY Engagement_Date__c DESC
            LIMIT 100
        ];
    }


    @AuraEnabled(cacheable=true)
    public static List<CallLog__c> getLastFiveCallDetails() {
        return [
    SELECT 
        Id, 
        Name, 
        Quality_Of_Call__c, 
        Engagement_Date__c, 
        Process_Improvement_Insights__c, 
        Agent_Improvement_Insights__c, 
        CallDuration__c
    FROM CallLog__c
    WHERE 
        Call_Status__c = 'Closed' 
        AND PromptStatus__c != 'Failed'
    ORDER BY CreatedDate DESC
    LIMIT 10
];
    }
}