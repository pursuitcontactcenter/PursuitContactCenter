//********************************************************** Previous Code ( with assembly ai ) ******************************************************
/*public with sharing class AssemblyAIFromSalesforce_UP_1 {
    
    public static final String API_KEY = '7a84eca123cd4d8b92e9bfcf59eb78bb'; // Replace with your key
    public static final Id ContactID = '003gL000006BSbqQAG';
    
    // Step 1: Triggered when a file is uploaded to CallLog__c
    
    public static void handleFileUpload(Set<Id> contentDocumentIds) {
        System.debug('=== handleFileUpload START ===');
        
        Id currentUserId = UserInfo.getUserId();
        
        // Step 1: Map Document -> CallLog
        Map<Id, Id> docToEntityMap = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocumentIds
        ]) {
            if (cdl.LinkedEntityId != null) {
                docToEntityMap.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
            }
        }
        
        // Step 2: Get file content
        Map<Id, ContentVersion> docVersionMap = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, VersionData, Title, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId IN :docToEntityMap.keySet()
            ORDER BY CreatedDate DESC
        ]) {
            if (!docVersionMap.containsKey(cv.ContentDocumentId)) {
                docVersionMap.put(cv.ContentDocumentId, cv);
            }
        }
        
        Set<String> supportedTypes = new Set<String>{'ogg', 'aac', 'mp3', 'wav', 'm4a', 'flac'};
            List<CallLog__c> logsToUpdate = new List<CallLog__c>();
        
        // 🔁 Fetch agent record dynamically
        Agent__c agent = [SELECT Id FROM Agent__c WHERE User__c = :currentUserId LIMIT 1];
        
        for (Id docId : docToEntityMap.keySet()) {
            ContentVersion cv = docVersionMap.get(docId);
            if (cv == null || !supportedTypes.contains(cv.FileExtension.toLowerCase())) {
                System.debug('Unsupported file type: ' + cv.Title);
                continue;
            }
            
            try {
                String uploadUrl = uploadAudioToAssemblyAI(cv.Id);
                String transcriptId = requestTranscription(uploadUrl);
                
                // 🔍 Parse the Title
                List<String> parts = cv.Title.split('_');
                DateTime callStart, callEnd;
                String mobileNumber;
                
                if (parts.size() >= 5) {
                    String dateStr = parts[1];
                    String startTimeStr = parts[2];
                    String endTimeStr = parts[3];
                    mobileNumber = parts[0]; // assumed phone number is in position 4
                    
                    String formattedStart = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                        + ' ' + startTimeStr.substring(0,2) + ':' + startTimeStr.substring(2,4) + ':' + startTimeStr.substring(4,6);
                    String formattedEnd = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                        + ' ' + endTimeStr.substring(0,2) + ':' + endTimeStr.substring(2,4) + ':' + endTimeStr.substring(4,6);
                    
                    callStart = DateTime.valueOf(formattedStart);
                    callEnd = DateTime.valueOf(formattedEnd);
                } else {
                    System.debug('Invalid filename format for: ' + cv.Title);
                    continue;
                }
                
                // 👤 Fetch or create Client
                Client__c client;
                List<Client__c> foundClients = [
                    SELECT Id FROM Client__c WHERE Mobile_Number__c = :mobileNumber LIMIT 1
                ];
                if (!foundClients.isEmpty()) {
                    client = foundClients[0];
                } else {
                    // Fetch Account: Dickenson plc
                    Account acct = [SELECT Id FROM Account WHERE Name = 'Dickenson plc' LIMIT 1];
                    
                    client = new Client__c(
                        Name = 'Client_' + mobileNumber,
                        Mobile_Number__c = mobileNumber,
                        Account__c = acct.Id // Make sure this field exists on Client__c
                    );
                    insert client;
                }
                
                
                // ➕ Add CallLog update
                logsToUpdate.add(new CallLog__c(
                    Id = docToEntityMap.get(docId),
                    transcriptId__c = transcriptId,
                    transcript_Desc__c = 'Processing...',
                    Call_Status__c = 'In-Progress',
                    AgentID__c = agent.Id,
                    Client__c = client.Id,
                    Contact__c = ContactID,  // You can make this dynamic as well later
                    Name = cv.Title,
                    CallEndTime__c = callEnd,
                    CallStartTime__c = callStart,
                    Mobile_Number__c = mobileNumber
                ));
            } catch (Exception e) {
                System.debug('Error processing docId ' + docId + ': ' + e.getMessage());
            }
        }
        
        if (!logsToUpdate.isEmpty()) {
            update logsToUpdate;
        }
        
        System.debug('=== handleFileUpload END ===');
    }
    
    // Step 2: Upload audio to AssemblyAI
    public static String uploadAudioToAssemblyAI(Id contentVersionId) {
        ContentVersion cv = [
            SELECT VersionData, Title, FileExtension
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.assemblyai.com/v2/upload');
        req.setMethod('POST');
        req.setHeader('Authorization', API_KEY);
        req.setHeader('Transfer-Encoding', 'chunked');
        req.setBodyAsBlob(cv.VersionData);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('upload_url');
        } else {
            throw new CalloutException('Upload failed: ' + res.getBody());
        }
    }
    
    // Step 3: Request transcription from AssemblyAI
    public static String requestTranscription(String uploadUrl) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.assemblyai.com/v2/transcript');
        req.setMethod('POST');
        req.setHeader('Authorization', API_KEY);
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"audio_url": "' + uploadUrl + '"}');
        //req.setBody('{"audio_url": "' + uploadUrl + '", "language_code": "bn"}');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('id');
        } else {
            throw new CalloutException('Transcription request failed: ' + res.getBody());
        }
    }

    
    // Step 4: Get transcription result using transcript ID
    public static String getTranscriptionResult(String transcriptId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.assemblyai.com/v2/transcript/' + transcriptId);
        req.setMethod('GET');
        req.setHeader('Authorization', API_KEY);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String status = (String) result.get('Call_Status__c');
            
            return (String) result.get('text');
        } else {
            throw new CalloutException('Failed to get transcript status: ' + res.getBody());
        }
    }
    
    // Step 5: Poll and update completed transcripts
    public static void updateTranscriptDescriptions() {
        System.debug('=== updateTranscriptDescriptions START ===');
        
        List<CallLog__c> pending = [
            SELECT Id, transcriptId__c, Call_Status__c,PromptStatus__c
            FROM CallLog__c
            WHERE transcriptId__c != null 
            //AND 
            //    Call_Status__c = 'In-Progress'
            LIMIT 100
        ];
        
        for (CallLog__c log : pending) {
            System.enqueueJob(new TranscriptProcessorQueueable(log.Id, log.transcriptId__c, log.Call_Status__c, log.PromptStatus__c));
        }
        System.debug('=== updateTranscriptDescriptions END ===');
    }   
}*/
//**********************************************************  Updated Code 1 ( with gemini with small files ) ******************************************************
/*public with sharing class AssemblyAIFromSalesforce_UP_1 {

private static final String ENDPOINT = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=AIzaSyAIsml4zQwvz0pvMOovajYMEMUM-m_C13o';
public static final Id ContactID = '003gL000006BSbqQAG';

public static void handleFileUpload(Set<Id> contentDocumentIds) {

Id currentUserId = UserInfo.getUserId();

// Step 1: Map Document -> CallLog
Map<Id, Id> docToEntityMap = new Map<Id, Id>();
for (ContentDocumentLink cdl : [
SELECT ContentDocumentId, LinkedEntityId
FROM ContentDocumentLink
WHERE ContentDocumentId IN :contentDocumentIds
]) {
if (cdl.LinkedEntityId != null) {
docToEntityMap.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
}
}

// Step 2: Get file content
Map<Id, ContentVersion> docVersionMap = new Map<Id, ContentVersion>();
for (ContentVersion cv : [
SELECT Id, ContentDocumentId, VersionData, Title, FileExtension
FROM ContentVersion
WHERE ContentDocumentId IN :docToEntityMap.keySet()
ORDER BY CreatedDate DESC
]) {
if (!docVersionMap.containsKey(cv.ContentDocumentId)) {
docVersionMap.put(cv.ContentDocumentId, cv);
}
}

Set<String> supportedTypes = new Set<String>{'ogg', 'aac', 'mp3', 'wav', 'm4a', 'flac'};
List<CallLog__c> logsToUpdate = new List<CallLog__c>();

// 🔁 Fetch agent record dynamically
Agent__c agent = [SELECT Id FROM Agent__c WHERE User__c = :currentUserId LIMIT 1];

for (Id docId : docToEntityMap.keySet()) {
ContentVersion cv = docVersionMap.get(docId);
if (cv == null || !supportedTypes.contains(cv.FileExtension.toLowerCase())) {
System.debug('Unsupported file type: ' + cv.Title);
continue;
}

try {
String transcript = requestTranscription(cv.Id);

// 🔍 Parse the Title
List<String> parts = cv.Title.split('_');
DateTime callStart, callEnd;
String mobileNumber;

if (parts.size() >= 5) {
String dateStr = parts[1];
String startTimeStr = parts[2];
String endTimeStr = parts[3];
mobileNumber = parts[0]; // assumed phone number is in position 4

String formattedStart = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
+ ' ' + startTimeStr.substring(0,2) + ':' + startTimeStr.substring(2,4) + ':' + startTimeStr.substring(4,6);
String formattedEnd = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
+ ' ' + endTimeStr.substring(0,2) + ':' + endTimeStr.substring(2,4) + ':' + endTimeStr.substring(4,6);

callStart = DateTime.valueOf(formattedStart);
callEnd = DateTime.valueOf(formattedEnd);
} else {
System.debug('Invalid filename format for: ' + cv.Title);
continue;
}

// 👤 Fetch or create Client
Client__c client;
List<Client__c> foundClients = [
SELECT Id FROM Client__c WHERE Mobile_Number__c = :mobileNumber LIMIT 1
];
if (!foundClients.isEmpty()) {
client = foundClients[0];
} else {
// Fetch Account: Dickenson plc
Account acct = [SELECT Id FROM Account WHERE Name = 'Dickenson plc' LIMIT 1];

client = new Client__c(
Name = 'Client_' + mobileNumber,
Mobile_Number__c = mobileNumber,
Account__c = acct.Id // Make sure this field exists on Client__c
);
insert client;
}

// ➕ Add CallLog update
logsToUpdate.add(new CallLog__c(
Id = docToEntityMap.get(docId),
//transcriptId__c = transcriptId,
transcript_Desc__c = transcript,
//transcript_Desc__c = 'Processing...',
Call_Status__c = 'In-Progress',
AgentID__c = agent.Id,
Client__c = client.Id,
Contact__c = ContactID,  // You can make this dynamic as well later
Name = cv.Title,
CallEndTime__c = callEnd,
CallStartTime__c = callStart,
Mobile_Number__c = mobileNumber
));
//updateTranscriptDescriptions(docToEntityMap.get(docId), transcript, 'In-Progress',null);
//or
//System.enqueueJob(new TranscriptProcessorQueueable(docToEntityMap.get(docId), transcript, 'In-Progress',null));
//or
String jsonData = PromptInvoker_1.FetchRulesDetails(docToEntityMap.get(docId));
PromptInvoker_1.StringToJson(jsonData,  'In-Progress' );
System.debug('Prompt invoked successfully'); 
} catch (Exception e) {
System.debug('Error processing docId ' + docId + ': ' + e.getMessage());
}
}

if (!logsToUpdate.isEmpty()) {
update logsToUpdate;
}
}


public static void updateTranscriptDescriptions(Id logId, String transcriptText, String callStatus, String promptStatus) {

// If all values are provided, enqueue a single job
if (logId != null && transcriptText != null && callStatus != null && promptStatus != null) {
System.debug('Enqueuing job for specific CallLog');
System.enqueueJob(new TranscriptProcessorQueueable(logId, transcriptText, callStatus, promptStatus));
} 
else {
// Otherwise, fetch CallLog__c records from DB and enqueue jobs
List<CallLog__c> pending = [
SELECT Id, transcript_Desc__c, Call_Status__c, PromptStatus__c
FROM CallLog__c
//WHERE transcriptId__c != null
LIMIT 100
];

System.debug('*********************************************************************************************');

for (CallLog__c log : pending) {
System.enqueueJob(new TranscriptProcessorQueueable(log.Id, log.transcript_Desc__c, log.Call_Status__c, log.PromptStatus__c));
}
}

}

// Step 3: Request transcription from AssemblyAI
public static String requestTranscription(Id contentVersionId) {
ContentVersion cv = [
SELECT Id, VersionData, Title, FileExtension
FROM ContentVersion
WHERE Id = :contentVersionId
LIMIT 1
];

// Convert audio to base64
String base64Audio = EncodingUtil.base64Encode(cv.VersionData);

// Get MIME type
String mimeType = 'audio/wav';
if (cv.FileExtension == 'mp3') mimeType = 'audio/mpeg';
else if (cv.FileExtension == 'm4a') mimeType = 'audio/mp4';

// Build request
Map<String, Object> audioData = new Map<String, Object>{
'mimeType' => mimeType,
'data' => base64Audio
};

Map<String, Object> partAudio = new Map<String, Object>{ 'inlineData' => audioData };
Map<String, Object> partPrompt = new Map<String, Object>{ 'text' => 'Transcribe the audio as-is. Do not translate. Return the full transcript without truncation.' };

Map<String, Object> content = new Map<String, Object>{
'parts' => new List<Object>{ partAudio, partPrompt }
};

Map<String, Object> requestBody = new Map<String, Object>{
'contents' => new List<Object>{ content }
};

HttpRequest req = new HttpRequest();
req.setEndpoint(ENDPOINT);
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setBody(JSON.serialize(requestBody));

Http http = new Http();
HttpResponse res = http.send(req);

if (res.getStatusCode() == 200) {
Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
List<Object> candidates = (List<Object>) responseMap.get('candidates');

if (candidates != null && !candidates.isEmpty()) {
Map<String, Object> firstCandidate = (Map<String, Object>) candidates[0];
Map<String, Object> contentMap = (Map<String, Object>) firstCandidate.get('content');
List<Object> parts = (List<Object>) contentMap.get('parts');
Map<String, Object> textPart = (Map<String, Object>) parts[0];

return (String) textPart.get('text');
}
}
throw new CalloutException('Gemini transcription failed: ' + res.getBody());
}

// Step 4: Get transcription result using transcript ID
public static String getTranscriptionResult(String rawText) {
return rawText;
}

}*/
/* Error :-
This schedulable class has jobs pending or in progress - 
CronTrigger IDs (08egL0000092bmK,08egL00000924IT,08egL0000092RDT,08egL000009289B,08egL0000092bmL,...)
*/
/*
List<CronTrigger> jobs = [
SELECT Id, CronJobDetail.Name, CronJobDetail.JobType, State
FROM CronTrigger
WHERE CronJobDetail.Name LIKE 'TranscriptScheduler%' 
];

for (CronTrigger job : jobs) {
System.debug('Aborting: ' + job.Id + ' → ' + job.CronJobDetail.Name + ' (' + job.State + ')');
System.abortJob(job.Id);
}
*/
/*
String cronExp = '0 0 * * * ?'; // Example: every hour
System.schedule('TranscriptScheduler', cronExp, new TranscriptUpdateScheduler());
*/
//**********************************************************  Updated Code 2 ( with gemini with large files ) ******************************************************
/*public with sharing class AssemblyAIFromSalesforce_UP_1 {
    
    private static final String ENDPOINT = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=AIzaSyAIsml4zQwvz0pvMOovajYMEMUM-m_C13o';
    public static final Id ContactID = '003gL000006BSbqQAG';
    
    public static void handleFileUpload(Set<Id> contentDocumentIds) {
        System.debug('=== handleFileUpload START ===');
        Id currentUserId = UserInfo.getUserId();
        
        // map Document -> LinkedEntity
        Map<Id, Id> docToEntityMap = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocumentIds
        ]) {
            if (cdl.LinkedEntityId != null) {
                docToEntityMap.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
            }
        }
        
        // latest version per document
        Map<Id, ContentVersion> docVersionMap = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, VersionData, Title, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId IN :docToEntityMap.keySet()
            ORDER BY CreatedDate DESC
        ]) {
            if (!docVersionMap.containsKey(cv.ContentDocumentId)) {
                docVersionMap.put(cv.ContentDocumentId, cv);
            }
        }
        
        Set<String> supportedTypes = new Set<String>{'ogg', 'aac', 'mp3', 'wav', 'm4a', 'flac'};
            
            // fetch agent
            Agent__c agent = [SELECT Id FROM Agent__c WHERE User__c = :currentUserId LIMIT 1];
        
        for (Id docId : docToEntityMap.keySet()) {
            ContentVersion cv = docVersionMap.get(docId);
            if (cv == null || !supportedTypes.contains(cv.FileExtension.toLowerCase())) {
                System.debug('Unsupported file type or missing version for: ' + (cv != null ? cv.Title : docId));
                continue;
            }
            // enqueue async processor per document
            System.enqueueJob(new GeminiAudioProcessorQueueable(cv.Id, docToEntityMap.get(docId), agent.Id));
        }
        
        System.debug('=== handleFileUpload END ===');
    }
    
    // queueable that replaces the Gemini part + downstream logic
    public class GeminiAudioProcessorQueueable implements Queueable, Database.AllowsCallouts {
        private Id contentVersionId;
        private Id linkedEntityId; // CallLog Id
        private Id agentId;
        private Integer baseChunkSize = 1000000; // ~1MB base64, can adjust
        
        public GeminiAudioProcessorQueueable(Id cvId, Id linkedEntityId, Id agentId) {
            this.contentVersionId = cvId;
            this.linkedEntityId = linkedEntityId;
            this.agentId = agentId;
        }
        
        public void execute(QueueableContext ctx) {
            try {
                ContentVersion cv = [
                    SELECT Id, VersionData, Title, FileExtension
                    FROM ContentVersion
                    WHERE Id = :contentVersionId
                    LIMIT 1
                ];
                
                Set<String> supportedTypes = new Set<String>{'ogg', 'aac', 'mp3', 'wav', 'm4a', 'flac'};
                    if (cv == null || !supportedTypes.contains(cv.FileExtension.toLowerCase())) return;
                
                // chunked Gemini transcription
                String mimeType = 'audio/wav';
                if (cv.FileExtension == 'mp3') mimeType = 'audio/mpeg';
                else if (cv.FileExtension == 'm4a') mimeType = 'audio/mp4';
                
                String fullBase64 = EncodingUtil.base64Encode(cv.VersionData);
                List<String> chunks = splitBase64(fullBase64, baseChunkSize);
                List<String> partialTranscripts = new List<String>();
                for (Integer i = 0; i < chunks.size(); i++) {
                    String chunk = chunks[i];
                    String transcriptChunk = getTranscriptForChunk(chunk, mimeType, 0);
                    if (transcriptChunk != null) partialTranscripts.add(transcriptChunk.trim());
                    else partialTranscripts.add('[FAILED_CHUNK_' + i + ']');
                }
                String combinedTranscript = String.join(partialTranscripts, ' ');
                System.debug('===== Original Transcript (auto-detected language) =====');
                logInChunks(combinedTranscript);
                
                String finalTranscript = combinedTranscript;
                if (!isLikelyEnglish(combinedTranscript)) {
                    Map<String, Object> translationPrompt = new Map<String, Object>{
                        'parts' => new List<Object>{
                            new Map<String, Object>{ 'text' => 'Translate the following to English:\n' + combinedTranscript }
                        }
                    };
                        Map<String, Object> translationBody = new Map<String, Object>{
                            'contents' => new List<Object>{ translationPrompt }
                        };
                            String englishTranscript = callGemini(translationBody);
                    if (englishTranscript != null) {
                        System.debug('===== 🇬🇧 English Translation =====');
                        logInChunks(englishTranscript);
                        finalTranscript = englishTranscript;
                    }
                }
                
                // parse title for metadata
                List<String> parts = cv.Title.split('_');
                DateTime callStart, callEnd;
                String mobileNumber;
                if (parts.size() >= 5) {
                    String dateStr = parts[1];
                    String startTimeStr = parts[2];
                    String endTimeStr = parts[3];
                    mobileNumber = parts[0];
                    String formattedStart = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                        + ' ' + startTimeStr.substring(0,2) + ':' + startTimeStr.substring(2,4) + ':' + startTimeStr.substring(4,6);
                    String formattedEnd = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                        + ' ' + endTimeStr.substring(0,2) + ':' + endTimeStr.substring(2,4) + ':' + endTimeStr.substring(4,6);
                    callStart = DateTime.valueOf(formattedStart);
                    callEnd = DateTime.valueOf(formattedEnd);
                } else {
                    System.debug('Invalid filename format for: ' + cv.Title);
                    return;
                }
                
                // client lookup/create
                Client__c client;
                List<Client__c> foundClients = [
                    SELECT Id FROM Client__c WHERE Mobile_Number__c = :mobileNumber LIMIT 1
                ];
                if (!foundClients.isEmpty()) {
                    client = foundClients[0];
                } else {
                    Account acct = [SELECT Id FROM Account WHERE Name = 'Dickenson plc' LIMIT 1];
                    client = new Client__c(
                        Name = 'Client_' + mobileNumber,
                        Mobile_Number__c = mobileNumber,
                        Account__c = acct.Id
                    );
                    insert client;
                }
                
                // update CallLog__c
                CallLog__c log = new CallLog__c(
                    Id = linkedEntityId,
                    transcript_Desc__c = finalTranscript,
                    Call_Status__c = 'In-Progress',
                    //AgentID__c = agentId,
                    Client__c = client.Id,
                    Contact__c = ContactID,
                    Name = cv.Title,
                    CallEndTime__c = callEnd,
                    CallStartTime__c = callStart,
                    Mobile_Number__c = mobileNumber
                );
                update log;
                
                // invoke prompt logic
                String jsonData = PromptInvoker_1.FetchRulesDetails(linkedEntityId);
                PromptInvoker_1.StringToJson(jsonData, 'In-Progress');
                System.debug('Prompt invoked successfully');
                
            } catch (Exception e) {
                System.debug('Error in GeminiAudioProcessorQueueable: ' + e.getMessage());
            }
        }
        
        private List<String> splitBase64(String base64, Integer chunkSize) {
            List<String> parts = new List<String>();
            Integer len = base64.length();
            for (Integer i = 0; i < len; i += chunkSize) {
                Integer endPos = Math.min(i + chunkSize, len);
                parts.add(base64.substring(i, endPos));
            }
            return parts;
        }
        
        private String getTranscriptForChunk(String base64Chunk, String mimeType, Integer depth) {
            Map<String, Object> audioData = new Map<String, Object>{
                'mimeType' => mimeType,
                    'data' => base64Chunk
                    };
                        Map<String, Object> partAudio = new Map<String, Object>{ 'inlineData' => audioData };
                            Map<String, Object> partPrompt = new Map<String, Object>{ 'text' => 'Transcribe this audio chunk as-is. Do not translate. Return full transcript without truncation.' };
                                
                                Map<String, Object> content = new Map<String, Object>{
                                    'parts' => new List<Object>{ partAudio, partPrompt }
                                };
                                    Map<String, Object> requestBody = new Map<String, Object>{
                                        'contents' => new List<Object>{ content }
                                    };
                                        
                                        String result = callGemini(requestBody);
            if (result != null) return result;
            
            if (depth < 2 && base64Chunk.length() > 50000) {
                Integer mid = base64Chunk.length() / 2;
                String first = base64Chunk.substring(0, mid);
                String second = base64Chunk.substring(mid);
                String r1 = getTranscriptForChunk(first, mimeType, depth + 1);
                String r2 = getTranscriptForChunk(second, mimeType, depth + 1);
                List<String> combined = new List<String>();
                if (r1 != null) combined.add(r1.trim());
                else combined.add('[FAILED_SUBCHUNK_1]');
                if (r2 != null) combined.add(r2.trim());
                else combined.add('[FAILED_SUBCHUNK_2]');
                return String.join(combined, ' ');
            }
            return null;
        }
        
        private String callGemini(Map<String, Object> body) {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(body));
            req.setTimeout(120000);
            
            Integer attempts = 0;
            while (attempts < 2) {
                try {
                    HttpResponse res = http.send(req);
                    if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                        List<Object> candidates = (List<Object>) responseMap.get('candidates');
                        if (candidates != null && !candidates.isEmpty()) {
                            Map<String, Object> firstCandidate = (Map<String, Object>) candidates[0];
                            Map<String, Object> contentMap = (Map<String, Object>) firstCandidate.get('content');
                            if (contentMap != null) {
                                List<Object> parts = (List<Object>) contentMap.get('parts');
                                if (parts != null && parts.size() > 0) {
                                    Map<String, Object> textPart = (Map<String, Object>) parts[0];
                                    return (String) textPart.get('text');
                                }
                            }
                        }
                    } else {
                        System.debug('Gemini non-2xx: ' + res.getStatusCode() + ' body=' + res.getBody());
                    }
                    break;
                } catch (CalloutException ce) {
                    attempts++;
                    System.debug('CalloutException retry ' + attempts + ': ' + ce.getMessage());
                    if (attempts >= 2) break;
                }
            }
            return null;
        }
        
        private void logInChunks(String input) {
            Integer chunkSize = 100;
            for (Integer i = 0; i < input.length(); i += chunkSize) {
                Integer endIndex = Math.min(i + chunkSize, input.length());
                System.debug(input.substring(i, endIndex));
            }
        }
        
        private Boolean isLikelyEnglish(String text) {
            String sample = text.length() > 100 ? text.substring(0, 100) : text;
            return Pattern.matches('^[A-Za-z0-9\\s.,!?\\\'\"-]+$', sample);
        }
    }
    public static void updateTranscriptDescriptions(Id logId, String transcriptText, String callStatus, String promptStatus) {
        
        // If all values are provided, enqueue a single job
        if (logId != null && transcriptText != null && callStatus != null && promptStatus != null) {
            System.debug('Enqueuing job for specific CallLog');
            System.enqueueJob(new TranscriptProcessorQueueable(logId, transcriptText, callStatus, promptStatus));
        } 
        else {
            // Otherwise, fetch CallLog__c records from DB and enqueue jobs
            List<CallLog__c> pending = [
                SELECT Id, transcript_Desc__c, Call_Status__c, PromptStatus__c
                FROM CallLog__c
                //WHERE transcriptId__c != null
                LIMIT 100
            ];
            
            System.debug('*********************************************************************************************');
            
            for (CallLog__c log : pending) {
                System.enqueueJob(new TranscriptProcessorQueueable(log.Id, log.transcript_Desc__c, log.Call_Status__c, log.PromptStatus__c));
            }
        }
        
    }
}*/
//**********************************************************  Updated Code 3 ( Using Google Storage with Gemini for Handling Small and Large Files ) ******************************************************
/*public with sharing class AssemblyAIFromSalesforce_UP_1 {
    
    private static final String ENDPOINT = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=AIzaSyAIsml4zQwvz0pvMOovajYMEMUM-m_C13o';
    public static final Id ContactID = '003gL000006BSbqQAG';
    
    public class MockContentVersion {
        public String Title;
        public String FileExtension;
        public Blob VersionData;
        
        public MockContentVersion(String title, String ext, Blob data) {
            this.Title = title;
            this.FileExtension = ext;
            this.VersionData = data;
        }
    }
    public class GoogleDriveFileWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String displayUrl;
        public GoogleDriveFileWrapper(String name, String displayUrl) {
            this.name = name;
            this.displayUrl = displayUrl;
        }
    }
    
    @AuraEnabled
    public static void handleGoogleDriveFileUpload() {
        System.debug('=== handleGoogleDriveFileUpload START ===');
        
        Id currentUserId = UserInfo.getUserId();
        //Agent__c agent = [SELECT Id FROM Agent__c WHERE User__c = :currentUserId LIMIT 1];
        List<Agent__c> agents = [SELECT Id FROM Agent__c WHERE User__c = :currentUserId LIMIT 1];
        if (agents.isEmpty()) {
            System.debug('No Agent found for user');
            return;
        }
        Agent__c agent = agents[0];

        
        
        // 1. Get recent drive items
        List<Items_GoogleDriveDataSource__x> items = [
            SELECT Name__c, DisplayUrl
            FROM Items_GoogleDriveDataSource__x
            WHERE IsFolder__c = false
            ORDER BY Name__c
            LIMIT 100
        ];
        
        // 2. Collect their names
        Set<String> itemNames = new Set<String>();
        for (Items_GoogleDriveDataSource__x it : items) {
            if (it.Name__c != null) itemNames.add(it.Name__c.trim());
        }
        
        // 3. Query CallLogs that already exist for those names
        List<CallLog__c> existingLogs = [
            SELECT Name
            FROM CallLog__c
            WHERE Name IN :itemNames
        ];
        Set<String> existingNames = new Set<String>();
        for (CallLog__c cl : existingLogs) {
            if (cl.Name != null) existingNames.add(cl.Name.trim());
        }
        
        // 4. Build results only for files without a CallLog
        List<GoogleDriveFileWrapper> results = new List<GoogleDriveFileWrapper>();
        for (Items_GoogleDriveDataSource__x item : items) {
            String name = item.Name__c != null ? item.Name__c.trim() : '';
            if (existingNames.contains(name)) continue; // skip ones with CallLog
            results.add(new GoogleDriveFileWrapper(item.Name__c, item.DisplayUrl));
        }
        System.debug('results is :-'+ results.size());
        
        for (GoogleDriveFileWrapper file : results){
            if (file.displayUrl == null || !file.displayUrl.startsWith('https')) {
                System.debug('Invalid display URL for file: ' + file.displayUrl);
                continue;
            }
            System.debug('Each file url :-'+ file.displayUrl);
            //System.debug('Valid');
            
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(file.displayUrl);
            req.setMethod('GET');
            req.setTimeout(120000);
            
            try {
                HttpResponse res = http.send(req);
                if (res.getStatusCode() == 200) {
                    Blob fileBlob = res.getBodyAsBlob();
                    String fileExtension = file.name.contains('.') ? file.name.split('\\.')[1].toLowerCase() : '';
                    Set<String> supportedTypes = new Set<String>{'ogg', 'aac', 'mp3', 'wav', 'm4a', 'flac'};
                        if (!supportedTypes.contains(fileExtension)) {
                            System.debug('Unsupported file type: ' + fileExtension);
                            continue;
                        }
                    
                    MockContentVersion mock = new MockContentVersion(file.name, fileExtension, fileBlob);
                    
                    CallLog__c tempLog = new CallLog__c(Name = file.name);
                    insert tempLog;
                    
                    System.enqueueJob(new GeminiAudioProcessorQueueable_Mock(mock, tempLog.Id, agent.Id));
                } else {
                    System.debug('Failed to fetch file from Google Drive: ' + res.getStatusCode());
                }
            } catch (Exception e) {
                System.debug('Callout failed: ' + e.getMessage());
            }
        }
        
        System.debug('=== handleGoogleDriveFileUpload END ===');
    }
    
    public class GeminiAudioProcessorQueueable_Mock implements Queueable, Database.AllowsCallouts {
        private MockContentVersion cv;
        private Id linkedEntityId;
        private Id agentId;
        private Integer baseChunkSize = 1000000;
        
        public GeminiAudioProcessorQueueable_Mock(MockContentVersion cv, Id linkedEntityId, Id agentId) {
            this.cv = cv;
            this.linkedEntityId = linkedEntityId;
            this.agentId = agentId;
        }
        
        public void execute(QueueableContext ctx) {
            try {
                if (cv == null) return;
                
                Set<String> supportedTypes = new Set<String>{'ogg', 'aac', 'mp3', 'wav', 'm4a', 'flac'};
                    if (!supportedTypes.contains(cv.FileExtension.toLowerCase())) return;
                
                String mimeType = 'audio/wav';
                if (cv.FileExtension == 'mp3') mimeType = 'audio/mpeg';
                else if (cv.FileExtension == 'm4a') mimeType = 'audio/mp4';
                
                String fullBase64 = EncodingUtil.base64Encode(cv.VersionData);
                List<String> chunks = splitBase64(fullBase64, baseChunkSize);
                List<String> partialTranscripts = new List<String>();
                for (Integer i = 0; i < chunks.size(); i++) {
                    String chunk = chunks[i];
                    String transcriptChunk = getTranscriptForChunk(chunk, mimeType, 0);
                    if (transcriptChunk != null) partialTranscripts.add(transcriptChunk.trim());
                    else partialTranscripts.add('[FAILED_CHUNK_' + i + ']');
                }
                String combinedTranscript = String.join(partialTranscripts, ' ');
                System.debug('===== Original Transcript (auto-detected language) =====');
                logInChunks(combinedTranscript);
                
                String finalTranscript = combinedTranscript;
                if (!isLikelyEnglish(combinedTranscript)) {
                    Map<String, Object> translationPrompt = new Map<String, Object>{
                        'parts' => new List<Object>{
                            new Map<String, Object>{ 'text' => 'Translate the following to English:\n' + combinedTranscript }
                        }
                    };
                        Map<String, Object> translationBody = new Map<String, Object>{
                            'contents' => new List<Object>{ translationPrompt }
                        };
                            String englishTranscript = callGemini(translationBody);
                    if (englishTranscript != null) {
                        System.debug('===== \uD83C\uDDEC\uD83C\uDDE7 English Translation =====');
                        logInChunks(englishTranscript);
                        finalTranscript = englishTranscript;
                    }
                }
                
                // Title parsing
                List<String> parts = cv.Title.split('_');
                DateTime callStart, callEnd;
                String mobileNumber;
                if (parts.size() >= 5) {
                    String dateStr = parts[1];
                    String startTimeStr = parts[2];
                    String endTimeStr = parts[3];
                    mobileNumber = parts[0];
                    String formattedStart = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                        + ' ' + startTimeStr.substring(0,2) + ':' + startTimeStr.substring(2,4) + ':' + startTimeStr.substring(4,6);
                    String formattedEnd = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                        + ' ' + endTimeStr.substring(0,2) + ':' + endTimeStr.substring(2,4) + ':' + endTimeStr.substring(4,6);
                    callStart = DateTime.valueOf(formattedStart);
                    callEnd = DateTime.valueOf(formattedEnd);
                } else {
                    System.debug('Invalid filename format for: ' + cv.Title);
                    return;
                }
                
                Client__c client;
                List<Client__c> foundClients = [SELECT Id FROM Client__c WHERE Mobile_Number__c = :mobileNumber LIMIT 1];
                if (!foundClients.isEmpty()) {
                    client = foundClients[0];
                } else {
                    Account acct = [SELECT Id FROM Account WHERE Name = 'Dickenson plc' LIMIT 1];
                    client = new Client__c(Name = 'Client_' + mobileNumber, Mobile_Number__c = mobileNumber, Account__c = acct.Id);
                    insert client;
                }
                
                CallLog__c log = new CallLog__c(
                    Id = linkedEntityId,
                    transcript_Desc__c = finalTranscript,
                    Call_Status__c = 'In-Progress',
                    AgentID__c = agentId,
                    Client__c = client.Id,
                    Contact__c = ContactID,
                    Name = cv.Title,
                    CallEndTime__c = callEnd,
                    CallStartTime__c = callStart,
                    Mobile_Number__c = mobileNumber
                );
                update log;
                
                String jsonData = PromptInvoker_1.FetchRulesDetails(linkedEntityId);
                PromptInvoker_1.StringToJson(jsonData, 'In-Progress');
                System.debug('Prompt invoked successfully');
                
            } catch (Exception e) {
                System.debug('Error in GeminiAudioProcessorQueueable_Mock: ' + e.getMessage());
            }
        }
        
        private List<String> splitBase64(String base64, Integer chunkSize) {
            List<String> parts = new List<String>();
            Integer len = base64.length();
            for (Integer i = 0; i < len; i += chunkSize) {
                Integer endPos = Math.min(i + chunkSize, len);
                parts.add(base64.substring(i, endPos));
            }
            return parts;
        }
        
        private String getTranscriptForChunk(String base64Chunk, String mimeType, Integer depth) {
            Map<String, Object> audioData = new Map<String, Object>{ 'mimeType' => mimeType, 'data' => base64Chunk };
                Map<String, Object> partAudio = new Map<String, Object>{ 'inlineData' => audioData };
                    Map<String, Object> partPrompt = new Map<String, Object>{ 'text' => 'Transcribe this audio chunk as-is. Do not translate. Return full transcript without truncation.' };
                        
                        Map<String, Object> content = new Map<String, Object>{ 'parts' => new List<Object>{ partAudio, partPrompt } };
                            Map<String, Object> requestBody = new Map<String, Object>{ 'contents' => new List<Object>{ content } };
                                
                                String result = callGemini(requestBody);
            if (result != null) return result;
            
            if (depth < 2 && base64Chunk.length() > 50000) {
                Integer mid = base64Chunk.length() / 2;
                String first = base64Chunk.substring(0, mid);
                String second = base64Chunk.substring(mid);
                String r1 = getTranscriptForChunk(first, mimeType, depth + 1);
                String r2 = getTranscriptForChunk(second, mimeType, depth + 1);
                List<String> combined = new List<String>();
                if (r1 != null) combined.add(r1.trim());
                else combined.add('[FAILED_SUBCHUNK_1]');
                if (r2 != null) combined.add(r2.trim());
                else combined.add('[FAILED_SUBCHUNK_2]');
                return String.join(combined, ' ');
            }
            return null;
        }
        
        private String callGemini(Map<String, Object> body) {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(body));
            req.setTimeout(120000);
            
            Integer attempts = 0;
            while (attempts < 2) {
                try {
                    HttpResponse res = http.send(req);
                    if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                        List<Object> candidates = (List<Object>) responseMap.get('candidates');
                        if (candidates != null && !candidates.isEmpty()) {
                            Map<String, Object> firstCandidate = (Map<String, Object>) candidates[0];
                            Map<String, Object> contentMap = (Map<String, Object>) firstCandidate.get('content');
                            if (contentMap != null) {
                                List<Object> parts = (List<Object>) contentMap.get('parts');
                                if (parts != null && parts.size() > 0) {
                                    Map<String, Object> textPart = (Map<String, Object>) parts[0];
                                    return (String) textPart.get('text');
                                }
                            }
                        }
                    } else {
                        System.debug('Gemini non-2xx: ' + res.getStatusCode() + ' body=' + res.getBody());
                    }
                    break;
                } catch (CalloutException ce) {
                    attempts++;
                    System.debug('CalloutException retry ' + attempts + ': ' + ce.getMessage());
                    if (attempts >= 2) break;
                }
            }
            return null;
        }
        
        private void logInChunks(String input) {
            Integer chunkSize = 100;
            for (Integer i = 0; i < input.length(); i += chunkSize) {
                Integer endIndex = Math.min(i + chunkSize, input.length());
                System.debug(input.substring(i, endIndex));
            }
        }
        
        private Boolean isLikelyEnglish(String text) {
            String sample = text.length() > 100 ? text.substring(0, 100) : text;
            return Pattern.matches('^[A-Za-z0-9\\s.,!?\\\'\"-]+$', sample);
        }
    }
    
    public static void updateTranscriptDescriptions(Id logId, String transcriptText, String callStatus, String promptStatus) {
        if (logId != null && transcriptText != null && callStatus != null && promptStatus != null) {
            System.debug('Enqueuing job for specific CallLog');
            System.enqueueJob(new TranscriptProcessorQueueable(logId, transcriptText, callStatus, promptStatus));
        } else {
            List<CallLog__c> pending = [
                SELECT Id, transcript_Desc__c, Call_Status__c, PromptStatus__c
                FROM CallLog__c
                LIMIT 100
            ];
            for (CallLog__c log : pending) {
                System.enqueueJob(new TranscriptProcessorQueueable(log.Id, log.transcript_Desc__c, log.Call_Status__c, log.PromptStatus__c));
            }
        }
    }
    
    // =======================
    // ▶ PROCESS FLOW COMMENT
    // =======================
    // 1. Google Drive file uploaded → metadata saved to Items_GoogleDriveDataSource__x
    // 2. GoogleDriveFilesController.getGoogleDriveFiles() fetches metadata
    // 3. Wrapper (name + downloadUrl) passed to handleGoogleDriveFileUpload()
    // 4. Audio file downloaded from Google Drive via downloadUrl
    // 5. MockContentVersion created from file
    // 6. Temp CallLog__c record inserted
    // 7. Queueable GeminiAudioProcessorQueueable_Mock started
    // 8. File is chunked to base64, each chunk is transcribed
    // 9. All chunks joined → full transcript
    // 10. If non-English, auto-translated using Gemini
    // 11. Mobile, datetime extracted from filename (e.g., 9876543210_20250731_113000_114000_abc.mp3)
    // 12. Client__c found/created by mobile
    // 13. CallLog__c updated with transcript, metadata, and Client__c link
    // 14. PromptInvoker_1 called for prompt follow-up
}*/
public with sharing class AssemblyAIFromSalesforce_UP_1 {
    private static final String ENDPOINT = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=AIzaSyAIsml4zQwvz0pvMOovajYMEMUM-m_C13o';
    public static final Id ContactID = '003gL000006BSbqQAG';
    
    // =======================
    // CONFIG / CONSTANTS
    // =======================
    private static final Set<String> SUPPORTED_AUDIO_EXTENSIONS = new Set<String>{'ogg', 'aac', 'mp3', 'wav', 'm4a', 'flac'};
    private static final Integer QUEUEABLE_CAP = 45; // cap to prevent too many enqueued jobs
    public static final Id FALLBACK_ContactID = '003gL000006BSbqQAG'; // fallback if label missing

    // =======================
    // INNER TYPES
    // =======================
    public class MockContentVersion {
        public String Title;
        public String FileExtension;
        public Blob VersionData;
        
        public MockContentVersion(String title, String ext, Blob data) {
            this.Title = title;
            this.FileExtension = ext;
            this.VersionData = data;
        }
    }
    public class GoogleDriveFileWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String displayUrl;
        public GoogleDriveFileWrapper(String name, String displayUrl) {
            this.name = name;
            this.displayUrl = displayUrl;
        }
    }
    
    // =======================
    // ENTRY POINT
    // =======================
    @AuraEnabled
    public static void handleGoogleDriveFileUpload() {
        System.debug('=== handleGoogleDriveFileUpload START ===');
        
        Id currentUserId = UserInfo.getUserId();
        List<Agent__c> agents = [SELECT Id FROM Agent__c WHERE User__c = :currentUserId LIMIT 1];
        if (agents.isEmpty()) {
            System.debug('No Agent__c found for current user. Aborting.');
            return;
        }
        Agent__c agent = agents[0];
        
        List<Items_GoogleDriveDataSource__x> items = [
            SELECT Name__c, DisplayUrl
            FROM Items_GoogleDriveDataSource__x
            WHERE IsFolder__c = false
            ORDER BY Name__c
            LIMIT 100
        ];
        
        Set<String> itemNames = new Set<String>();
        for (Items_GoogleDriveDataSource__x it : items) {
            if (it.Name__c != null) itemNames.add(it.Name__c.trim());
        }
        
        List<CallLog__c> existingLogs = new List<CallLog__c>();
        if (!itemNames.isEmpty()) {
            existingLogs = [
                SELECT Name
                FROM CallLog__c
                WHERE Name IN :itemNames
            ];
        }
        Set<String> existingNames = new Set<String>();
        for (CallLog__c cl : existingLogs) {
            if (cl.Name != null) existingNames.add(cl.Name.trim());
        }
        
        List<GoogleDriveFileWrapper> results = new List<GoogleDriveFileWrapper>();
        for (Items_GoogleDriveDataSource__x item : items) {
            String name = item.Name__c != null ? item.Name__c.trim() : '';
            if (existingNames.contains(name)) continue;
            results.add(new GoogleDriveFileWrapper(item.Name__c, item.DisplayUrl));
        }
        System.debug('results is :-'+ results.size());
        
        Integer enqueuedCount = 0;
        for (GoogleDriveFileWrapper file : results){
            if (enqueuedCount >= QUEUEABLE_CAP) {
                System.debug('Reached queueable cap, skipping remaining files. Total enqueued: ' + enqueuedCount);
                break;
            }
            if (file.displayUrl == null || !file.displayUrl.startsWith('https')) {
                System.debug('Invalid display URL for file: ' + file.displayUrl);
                continue;
            }
            System.debug('Each file url :-'+ file.displayUrl);
            
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            //req.setEndpoint(file.displayUrl);
            String fileId = extractDriveFileId(file.displayUrl);
            if (fileId == null) {
                System.debug('Cannot get fileId from URL: ' + file.displayUrl);
                continue;
            }            
            req.setEndpoint('callout:GoogleDriveToken/drive/v3/files/' + EncodingUtil.urlEncode(fileId, 'UTF-8') + '?alt=media');
            req.setMethod('GET');
            req.setTimeout(120000);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Blob fileBlob = res.getBodyAsBlob();
                // proceed with your existing logic
            } else {
                System.debug('Drive API fetch failed: ' + res.getStatusCode() + ' ' + res.getBody());
                continue;
            }      
        }
        
        System.debug('=== handleGoogleDriveFileUpload END ===');
    }
    
    // =======================
    // QUEUEABLE PROCESSOR
    // =======================
    public class GeminiAudioProcessorQueueable_Mock implements Queueable, Database.AllowsCallouts {
        private MockContentVersion cv;
        private Id linkedEntityId;
        private Id agentId;
        private Integer baseChunkSize = 500000; // smaller base64 chunk
        private Integer recursionCounter = 0;
        private final Integer MAX_RECURSION_CALLS = 10;
        
        public GeminiAudioProcessorQueueable_Mock(MockContentVersion cv, Id linkedEntityId, Id agentId) {
            this.cv = cv;
            this.linkedEntityId = linkedEntityId;
            this.agentId = agentId;
        }
        
        public void execute(QueueableContext ctx) {
            try {
                if (cv == null) return;
                
                if (!SUPPORTED_AUDIO_EXTENSIONS.contains(cv.FileExtension.toLowerCase())) return;
                
                String mimeType = 'audio/wav';
                if (cv.FileExtension == 'mp3') mimeType = 'audio/mpeg';
                else if (cv.FileExtension == 'm4a') mimeType = 'audio/mp4';
                
                List<String> partialTranscripts = new List<String>();
                
                String fullBase64 = EncodingUtil.base64Encode(cv.VersionData);
                List<String> chunks = splitBase64(fullBase64, baseChunkSize);
                for (Integer i = 0; i < chunks.size(); i++) {
                    String chunk = chunks[i];
                    String transcriptChunk = getTranscriptForChunk(chunk, mimeType, 0);
                    if (transcriptChunk != null) partialTranscripts.add(transcriptChunk.trim());
                    else partialTranscripts.add('[FAILED_CHUNK_' + i + ']');
                }
                
                String combinedTranscript = String.join(partialTranscripts, ' ');
                System.debug('===== Original Transcript (auto-detected language) =====');
                logInChunks(combinedTranscript);
                
                String finalTranscript = combinedTranscript;
                if (!isLikelyEnglish(combinedTranscript)) {
                    Map<String, Object> translationPrompt = new Map<String, Object>{
                        'parts' => new List<Object>{
                            new Map<String, Object>{ 'text' => 'Translate the following to English:\n' + combinedTranscript }
                        }
                    };
                    Map<String, Object> translationBody = new Map<String, Object>{
                        'contents' => new List<Object>{ translationPrompt }
                    };
                    String englishTranscript = callGemini(translationBody);
                    if (englishTranscript != null) {
                        System.debug('===== 🇬🇧 English Translation =====');
                        logInChunks(englishTranscript);
                        finalTranscript = englishTranscript;
                    }
                }
                
                List<String> parts = cv.Title != null ? cv.Title.split('_') : new List<String>();
                DateTime callStart, callEnd;
                String mobileNumber;
                if (parts.size() >= 5) {
                    String dateStr = parts[1];
                    String startTimeStr = parts[2];
                    String endTimeStr = parts[3];
                    mobileNumber = parts[0];
                    String formattedStart = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                        + ' ' + startTimeStr.substring(0,2) + ':' + startTimeStr.substring(2,4) + ':' + startTimeStr.substring(4,6);
                    String formattedEnd = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                        + ' ' + endTimeStr.substring(0,2) + ':' + endTimeStr.substring(2,4) + ':' + endTimeStr.substring(4,6);
                    callStart = DateTime.valueOf(formattedStart);
                    callEnd = DateTime.valueOf(formattedEnd);
                } else {
                    System.debug('Invalid filename format for: ' + cv.Title);
                    return;
                }
                
                Client__c client;
                List<Client__c> foundClients = [
                    SELECT Id 
                    FROM Client__c 
                    WHERE Mobile_Number__c = :mobileNumber 
                    LIMIT 1
                ];
                if (!foundClients.isEmpty()) {
                    client = foundClients[0];
                } else {
                    List<Account> acctList = [SELECT Id FROM Account WHERE Name = 'Dickenson plc' LIMIT 1];
                    if (acctList.isEmpty()) {
                        System.debug('Account Dickenson plc not found. Aborting client creation.');
                        return;
                    }
                    Account acct = acctList[0];
                    client = new Client__c(Name = 'Client_' + mobileNumber, Mobile_Number__c = mobileNumber, Account__c = acct.Id);
                    Database.SaveResult clientSr = Database.insert(client, false);
                    if (!clientSr.isSuccess()) {
                        System.debug('Failed to insert Client__c: ' + (clientSr.getErrors().isEmpty() ? 'Unknown error' : clientSr.getErrors()[0].getMessage()));
                        return;
                    }
                }
                
                CallLog__c log = new CallLog__c(
                    Id = linkedEntityId,
                    transcript_Desc__c = finalTranscript,
                    Call_Status__c = 'In-Progress',
                    AgentID__c = agentId,
                    Client__c = client.Id,
                    Contact__c = FALLBACK_ContactID,
                    Name = cv.Title,
                    CallEndTime__c = callEnd,
                    CallStartTime__c = callStart,
                    Mobile_Number__c = mobileNumber
                );
                update log;
                
                try {
                    String jsonData = PromptInvoker_1.FetchRulesDetails(linkedEntityId);
                    if (jsonData != null) {
                        PromptInvoker_1.StringToJson(jsonData, 'In-Progress');
                    }
                    System.debug('Prompt invoked successfully');
                } catch (Exception piEx) {
                    System.debug('PromptInvoker failed: ' + piEx.getMessage());
                }
                
            } catch (Exception e) {
                System.debug('Error in GeminiAudioProcessorQueueable_Mock: ' + e.getMessage());
            }
        }
        
        // =======================
        // HELPERS
        // =======================
        private List<String> splitBase64(String base64, Integer chunkSize) {
            List<String> parts = new List<String>();
            Integer len = base64.length();
            for (Integer i = 0; i < len; i += chunkSize) {
                Integer endPos = Math.min(i + chunkSize, len);
                parts.add(base64.substring(i, endPos));
            }
            return parts;
        }
        
        private String getTranscriptForChunk(String base64Chunk, String mimeType, Integer depth) {
            if (recursionCounter > MAX_RECURSION_CALLS) {
                System.debug('Max recursion reached in getTranscriptForChunk');
                return null;
            }
            recursionCounter++;
            
            Map<String, Object> audioData = new Map<String, Object>{ 'mimeType' => mimeType, 'data' => base64Chunk };
            Map<String, Object> partAudio = new Map<String, Object>{ 'inlineData' => audioData };
            Map<String, Object> partPrompt = new Map<String, Object>{ 'text' => 'Transcribe this audio chunk as-is. Do not translate. Return full transcript without truncation.' };
            Map<String, Object> content = new Map<String, Object>{ 'parts' => new List<Object>{ partAudio, partPrompt } };
            Map<String, Object> requestBody = new Map<String, Object>{ 'contents' => new List<Object>{ content } };
            
            String result = callGemini(requestBody);
            if (result != null) return result;
            
            if (depth < 2 && base64Chunk != null && base64Chunk.length() > 50000) {
                Integer mid = base64Chunk.length() / 2;
                String first = base64Chunk.substring(0, mid);
                String second = base64Chunk.substring(mid);
                String r1 = getTranscriptForChunk(first, mimeType, depth + 1);
                String r2 = getTranscriptForChunk(second, mimeType, depth + 1);
                List<String> combined = new List<String>();
                if (r1 != null) combined.add(r1.trim());
                else combined.add('[FAILED_SUBCHUNK_1]');
                if (r2 != null) combined.add(r2.trim());
                else combined.add('[FAILED_SUBCHUNK_2]');
                return String.join(combined, ' ');
            }
            return null;
        }
        
        private String callGemini(Map<String, Object> body) {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(buildEndpointWithKey());
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(body));
            req.setTimeout(120000);
            
            Integer attempts = 0;
            while (attempts < 2) {
                try {
                    HttpResponse res = http.send(req);
                    if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                        if (responseMap == null) return null;
                        Object candidatesObj = responseMap.get('candidates');
                        if (!(candidatesObj instanceof List<Object>)) return null;
                        List<Object> candidates = (List<Object>) candidatesObj;
                        if (candidates.isEmpty()) return null;
                        Object firstCandObj = candidates[0];
                        if (!(firstCandObj instanceof Map<String, Object>)) return null;
                        Map<String, Object> firstCandidate = (Map<String, Object>) firstCandObj;
                        Object contentObj = firstCandidate.get('content');
                        if (!(contentObj instanceof Map<String, Object>)) return null;
                        Map<String, Object> contentMap = (Map<String, Object>) contentObj;
                        Object partsObj = contentMap.get('parts');
                        if (!(partsObj instanceof List<Object>)) return null;
                        List<Object> parts = (List<Object>) partsObj;
                        if (parts.isEmpty()) return null;
                        Object textPartObj = parts[0];
                        if (!(textPartObj instanceof Map<String, Object>)) return null;
                        Map<String, Object> textPart = (Map<String, Object>) textPartObj;
                        Object textObj = textPart.get('text');
                        if (textObj instanceof String) return (String) textObj;
                    } else {
                        System.debug('Gemini non-2xx: ' + res.getStatusCode() + ' body=' + res.getBody());
                    }
                    break;
                } catch (CalloutException ce) {
                    attempts++;
                    System.debug('CalloutException retry ' + attempts + ': ' + ce.getMessage());
                    if (attempts >= 2) break;
                }
            }
            return null;
        }
        
        private void logInChunks(String input) {
            if (input == null) return;
            Integer chunkSize = 100;
            for (Integer i = 0; i < input.length(); i += chunkSize) {
                Integer endIndex = Math.min(i + chunkSize, input.length());
                System.debug(input.substring(i, endIndex));
            }
        }
        
        private Boolean isLikelyEnglish(String text) {
            if (text == null) return false;
            String sample = text.length() > 100 ? text.substring(0, 100) : text;
            if (sample.length() == 0) return false;
            Integer count = 0;
            for (Integer i = 0; i < sample.length(); i++) {
                String ch = String.valueOf(sample.charAt(i));
                if (Pattern.matches('[A-Za-z0-9\\s\\p{Punct}]', ch)) count++;
            }
            return ((Double)count / sample.length()) > 0.8;
        }
    }
    
    // =======================
    // SUPPORT METHODS
    // =======================
    public static void updateTranscriptDescriptions(Id logId, String transcriptText, String callStatus, String promptStatus) {
        if (logId != null && transcriptText != null && callStatus != null && promptStatus != null) {
            System.debug('Enqueuing job for specific CallLog');
            System.enqueueJob(new TranscriptProcessorQueueable(logId, transcriptText, callStatus, promptStatus));
        } else {
            List<CallLog__c> pending = [
                SELECT Id, transcript_Desc__c, Call_Status__c, PromptStatus__c
                FROM CallLog__c
                LIMIT 100
            ];
            for (CallLog__c log : pending) {
                System.enqueueJob(new TranscriptProcessorQueueable(log.Id, log.transcript_Desc__c, log.Call_Status__c, log.PromptStatus__c));
            }
        }
    }
    
    // =======================
    // CONFIG FETCHERS (using custom labels as fallback)
    // =======================
    
    private static String buildEndpointWithKey() {
        String apiKey = ENDPOINT;
        // fallback: empty key (original hardcoded key removed for security)
        return 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=' + EncodingUtil.urlEncode(apiKey, 'UTF-8');
    }
    public static String extractDriveFileId(String displayUrl) {
        if (String.isBlank(displayUrl)) return null;
        // pattern like /d/{fileId}/
        Matcher m = Pattern.compile('/d/([^/]+)').matcher(displayUrl);
        if (m.find()) return m.group(1);
        // fallback: ?id=... style
        m = Pattern.compile('[?&]id=([^&]+)').matcher(displayUrl);
        if (m.find()) return m.group(1);
        return null;
    }

   
    
    // =======================
    // ▶ PROCESS FLOW COMMENT
    // =======================
    // 1. Google Drive file uploaded → metadata saved to Items_GoogleDriveDataSource__x
    // 2. GoogleDriveFilesController.getGoogleDriveFiles() fetches metadata
    // 3. Wrapper (name + downloadUrl) passed to handleGoogleDriveFileUpload()
    // 4. Audio file downloaded from Google Drive via downloadUrl
    // 5. MockContentVersion created from file
    // 6. Temp CallLog__c record inserted
    // 7. Queueable GeminiAudioProcessorQueueable_Mock started
    // 8. File is chunked to base64, each chunk is transcribed
    // 9. All chunks joined → full transcript
    // 10. If non-English, auto-translated using Gemini
    // 11. Mobile, datetime extracted from filename (e.g., 9876543210_20250731_113000_114000_abc.mp3)
    // 12. Client__c found/created by mobile
    // 13. CallLog__c updated with transcript, metadata, and Client__c link
    // 14. PromptInvoker_1 called for prompt follow-up
}