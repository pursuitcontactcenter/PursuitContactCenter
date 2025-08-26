// 4. DML-only queueable: does client/agent resolution and inserts CallLog__c
public with sharing class GeminiTranscriptionDMLQueueable implements Queueable {
    private TranscriptPayload payload;

    public GeminiTranscriptionDMLQueueable(TranscriptPayload payload) {
        this.payload = payload;
    }

    public void execute(QueueableContext ctx) {
        try {
            if (payload == null) return;

            // client lookup/create
            Client__c client;
            List<Client__c> foundClients = [
                SELECT Id FROM Client__c WHERE Mobile_Number__c = :payload.mobileNumber LIMIT 1
            ];
            if (!foundClients.isEmpty()) {
                client = foundClients[0];
            } 
            else {
                List<Account> acctList = [SELECT Id FROM Account WHERE Name = 'Dickenson plc' LIMIT 1];
                if (acctList.isEmpty()) return;
                Account acct = acctList[0];
                client = new Client__c(
                    Name = 'Client_' + payload.mobileNumber,
                    Mobile_Number__c = payload.mobileNumber,
                    Account__c = acct.Id
                );
                Database.SaveResult clientSr = Database.insert(client, false);
                if (!clientSr.isSuccess()) return;
            }

            // agent lookup
            Id agentId, agentUserId;
            /*List<Agent__c> agents = [
                SELECT Id, User__c FROM Agent__c LIMIT 1
            ];*/
            List<Agent__c> agents = [
                SELECT Id, User__c FROM Agent__c WHERE Name = :payload.transcriptAgentId LIMIT 1
            ];
            if (!agents.isEmpty()) {
                agentId = agents[0].Id;
                agentUserId = agents[0].User__c;
            }
            
            //check merge call
            System.debug('payload ' + payload + ' => ' + payload.isMerged);

            // insert CallLog
            CallLog__c newLog = new CallLog__c(
                Name = payload.transcriptName,
                File_Link__c = payload.fileDisplayUrl,
                Download_File_Link__c = payload.fileUrl,
                transcript_Desc__c = (payload.parentMergedCallLog != null) ? (payload.parentMergedCallLog + '\n\n' + payload.finalTranscript) : payload.finalTranscript,
                Call_Status__c = 'In-Progress',
                AgentID__c = agentId,
                Client__c = client.Id,
                Contact__c = GoogleDriveGeminiTranscriberQueueable.FALLBACK_ContactID,
                CallStartTime__c = payload.callStart,
                CallEndTime__c = payload.callEnd,
                Mobile_Number__c = payload.mobileNumber,
                //isMerged__c = (payload.isMerged != null) ? String.isNotBlank(payload.isMerged) : null ,
                mergedCall__c = (payload.parentMergedCallId != null) ? payload.parentMergedCallId : null,
                historyTrack__c = (payload.historyTrack != null) ? payload.historyTrack : null,
                //Sector_Type_H__c = (payload.historyTrack != null) ? payload.historyTrack : null,
                //Test_Report_H__c = (payload.historyTrack != null) ? payload.historyTrack : null,
                //Patient_Age_H__c = (payload.historyTrack != null) ? payload.historyTrack : null,
                Feature_CC__c = (payload.Feature_CC != null) ? payload.Feature_CC : null,
                OwnerId = agentUserId
            );
            insert newLog;
            
            // If isMerged is true, update the parent call log
            if ( payload.parentMergedCallId != null) {
                try {
                    CallLog__c parentLog = [
                        SELECT Id, transcript_Desc__c , isMerged__c
                        FROM CallLog__c
                        WHERE Id = :payload.parentMergedCallId
                        LIMIT 1
                    ];
                    
                    // update value
                    parentLog.isMerged__c = true;
                    //parentLog.mergedCall__c = newLog.Id;
                    //parentLog.historyTrack__c = (payload.historyTrack != null) ? payload.historyTrack : null;
                    
                    update parentLog;
                } catch (Exception updateEx) {
                    System.debug('Failed to update parent CallLog__c: ' + updateEx.getMessage());
                }
            }

        } catch (Exception e) {
            CallLog__c errorLog = new CallLog__c(
                Name = payload != null ? payload.transcriptName : 'Unknown Transcript',
                File_Link__c = payload != null ? payload.fileDisplayUrl : null,
                transcript_Desc__c = 'Error during transcription DML: ' + e.getMessage()
            );
            insert errorLog;
        }
    }
}