public with sharing class TranscriptRecordHelper {
    public static final Id ACCOUNT_ID = '001gL000009JGYiQAO';
    public static final Id USER_ID = '005gL000003cILZQA2';
    public static final Id Contact_ID = '003gL000006BSbqQAG';

    // Use this in batch insert logic
    public static CallLog__c buildTranscriptRecord(String transcriptId, String fileName, String transcriptText) {
        return new CallLog__c(
            Name = fileName,
            transcriptId__c = transcriptId,
            //AgentID__c = USER_ID,
            //Client__c = ACCOUNT_ID,
            //Contact__c = Contact_ID,
            Call_Status__c = transcriptText.startsWith('In-Progress') ? 'In-Progress' : 'Completed',
            transcript_Desc__c = transcriptText
        );
    }

    // Keep this for single insert if needed elsewhere
    public static void createTranscriptRecord(String transcriptId, String fileName, String transcriptText) {
        insert buildTranscriptRecord(transcriptId, fileName, transcriptText);
    }

    public static void updateTranscriptDescriptions() {
        List<CallLog__c> allRecords = [
            SELECT Id, transcriptId__c, transcript_Desc__c
            FROM CallLog__c
            WHERE transcriptId__c != null
            LIMIT 200
        ];
        System.debug('allRecords: ' + allRecords);
        List<CallLog__c> recordsToUpdate = new List<CallLog__c>();

        for (CallLog__c rec : allRecords) {
            System.debug('rec.transcript_Desc__c ' + rec.transcript_Desc__c);
            if (String.isBlank(rec.transcript_Desc__c) || rec.transcript_Desc__c == null || rec.transcript_Desc__c == 'Processing' || rec.transcript_Desc__c == 'Processing...') {
                try {
                    String text = AssemblyAIFromSalesforce.getTranscriptionResult(rec.transcriptId__c);
                    if (!String.isBlank(text) && !text.startsWith('Processing')) {
                        rec.transcript_Desc__c = text;
                        rec.Call_Status__c = 'Completed';
                        try {
                            String StringJsonData = PromptInvoker.FetchRulesDetails(rec.Id);
                            InsertDataWithPromptResult.StringToJson(StringJsonData);
                            recordsToUpdate.add(rec);
                            System.debug('Completed: -------->');
                        } catch (Exception ex) {
                            System.debug('Error invoking prompt for record ' + rec.Id + ': ' + ex.getMessage());
                        }               
                    }
                } catch (Exception e) {
                    System.debug('Error processing transcript ID ' + rec.transcriptId__c + ': ' + e.getMessage());
                }
            }
        }

        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }
    }
}