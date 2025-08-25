/*public with sharing class AgentPerformanceManagerView {
    @AuraEnabled(cacheable=true)
    public static List<Agent__c> getAgentForCurrentUser() {
        return [
    SELECT Id, Name, Agent_Improvement_Insights__c, Process_Improvement_Insights__c,
           User__r.Name, User__r.Profile.Name
    FROM Agent__c
    WHERE User__r.Profile.Name != 'System Administrator'
];

    }
}*/
public with sharing class AgentPerformanceManagerView {

    @AuraEnabled(cacheable=true)
    public static List<Agent__c> getAgentForCurrentUser() {
        User currentUser = [SELECT Id, Profile.Name, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId()];

        if (currentUser.UserRole.Name == 'CC Agents') {
            // Fetch only agent record related to current user
            return [
                SELECT Id, Name, Agent_Improvement_Insights__c, Process_Improvement_Insights__c,
                       User__r.Name, User__r.Profile.Name,User__r.FullPhotoUrl
                FROM Agent__c
                WHERE User__c = :UserInfo.getUserId()
            ];
        } else if (currentUser.UserRole.Name == 'CC Manager') {
            // Fetch all agents except those linked to System Admins
            return [
                SELECT Id, Name, Agent_Improvement_Insights__c, Process_Improvement_Insights__c,
                       User__r.Name, User__r.Profile.Name,User__r.FullPhotoUrl
                FROM Agent__c
                //WHERE User__r.Profile.Name != 'System Administrator'
            ];
        } else {
            // Default fallback: return no records
            //return new List<Agent__c>();
            return [
                SELECT Id, Name, Agent_Improvement_Insights__c, Process_Improvement_Insights__c,
                       User__r.Name, User__r.Profile.Name,User__r.FullPhotoUrl FROM Agent__c
                //WHERE User__r.Profile.Name != 'System Administrator'
                //WHERE User__r.Profile.Name != 'System Administrator'
            ];
        }
    }
}