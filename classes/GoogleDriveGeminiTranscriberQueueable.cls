/*public with sharing class GoogleDriveGeminiTranscriberQueueable implements Queueable, Database.AllowsCallouts {

    // Gemini API config (replace securely in custom settings for production)
    private final String geminiApiKey = 'AIzaSyCFvr3jJxae63N7n7kRdjdcxtbuZag4Smk';
    private final String geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=';

    // Adjustable chunk size for splitting large base64-encoded audio
    private final Integer baseChunkSize = 500000;

    public void execute(QueueableContext context) {
        System.debug('🔁 Queueable Execution Started: GoogleDriveGeminiTranscriberQueueable');

        // STEP 1: Fetch all files from Google Drive data source (exclude folders)
        List<Items_GoogleDriveDataSource__x> driveFiles = [
            SELECT Name__c, DisplayUrl
            FROM Items_GoogleDriveDataSource__x
            WHERE IsFolder__c = false
        ];
        System.debug('📦 Total Drive Files Found: ' + driveFiles.size());

        if (driveFiles.isEmpty()) return;

        // STEP 2: Get existing transcripts to avoid re-processing
        Set<String> existingNames = new Set<String>();
        for (CallLog__c log : [SELECT Name FROM CallLog__c WHERE Name LIKE 'Transcript - %']) {
            existingNames.add(log.Name);
        }
        System.debug('📜 Existing Transcript Count: ' + existingNames.size());

        // STEP 3: Process each unmatched file
        for (Items_GoogleDriveDataSource__x file : driveFiles) {
            String transcriptName = 'Transcript - ' + file.Name__c;
            if (existingNames.contains(transcriptName)) {
                System.debug('⏭ Skipping Already Processed File: ' + file.Name__c);
                continue;
            }

            try {
                System.debug('▶️ Processing File: ' + file.Name__c);

                // STEP 4: Convert shared Drive link to downloadable one
                String fileUrl = convertToDirectDownloadUrl(file.DisplayUrl);
                Blob audioBlob = downloadFile(fileUrl);
                System.debug('▶️ Audio blob done : ' + audioBlob);

                // STEP 5: Split base64-encoded blob into chunks for Gemini
                String base64Audio = EncodingUtil.base64Encode(audioBlob);
                List<String> chunks = splitBase64(base64Audio, baseChunkSize);
                System.debug('🧩 Total Chunks: ' + chunks.size());

                // STEP 6: Send each chunk to Gemini API for transcription
                List<String> partials = new List<String>();
                for (Integer i = 0; i < chunks.size(); i++) {
                    String chunk = chunks[i];
                    System.debug('🔎 Transcribing Chunk ' + (i + 1) + '/' + chunks.size());

                    String transcriptChunk = getTranscriptForChunk(chunk, 'audio/mp3'); // MIME can be made dynamic
                    if (transcriptChunk != null) {
                        partials.add(transcriptChunk.trim());
                    } else {
                        partials.add('[FAILED_CHUNK_' + i + ']');
                        System.debug('⚠️ Failed Chunk: ' + i);
                    }
                }

                // STEP 7: Combine all parts into one transcript
                String finalTranscript = String.join(partials, '\n');
                System.debug('✅ Final Transcript Length: ' + finalTranscript.length());

                // STEP 8: Save to CallLog__c
                CallLog__c log = new CallLog__c(
                    Name = transcriptName,
                    File_Link__c = fileUrl,
                    transcript_Desc__c = finalTranscript
                    //Call_Status__c = 'Completed'
                );
                insert log;
                System.debug('📁 Transcript Inserted: ' + transcriptName);

            } catch (Exception e) {
                System.debug('🔥 Error Processing File: ' + file.Name__c + ' => ' + e.getMessage());

                // Record failure into CallLog for tracking
                insert new CallLog__c(
                    Name = transcriptName,
                    File_Link__c = file.DisplayUrl,
                    transcript_Desc__c = 'Error during transcription: ' + e.getMessage()
                );
            }
        }

        System.debug('✅ Queueable Execution Finished.');
    }

    // Convert Google Drive view link to downloadable format
    private static String convertToDirectDownloadUrl(String originalUrl) {
        System.debug('DEBUG: Original Google Drive URL: ' + originalUrl);
        if (String.isBlank(originalUrl)) return originalUrl;

        Integer fileIdStart = originalUrl.indexOf('/d/');
        if (fileIdStart == -1) {
            System.debug('DEBUG: /d/ not found in URL, returning original URL');
            return originalUrl;
        }
        fileIdStart += 3;
        Integer fileIdEndSlash = originalUrl.indexOf('/', fileIdStart);
        Integer fileIdEndQuery = originalUrl.indexOf('?', fileIdStart);
        Integer fileIdEnd;
        if (fileIdEndSlash == -1 && fileIdEndQuery == -1) {
            fileIdEnd = originalUrl.length();
        } else if (fileIdEndSlash == -1) {
            fileIdEnd = fileIdEndQuery;
        } else if (fileIdEndQuery == -1) {
            fileIdEnd = fileIdEndSlash;
        } else {
            fileIdEnd = Math.min(fileIdEndSlash, fileIdEndQuery);
        }
        String fileId = originalUrl.substring(fileIdStart, fileIdEnd);
        String convertedUrl = 'https://drive.google.com/uc?export=download&id=' + fileId;
        System.debug('DEBUG: Converted Google Drive direct download URL: ' + convertedUrl);
        return convertedUrl;
    }

    // HTTP call to download file as blob
    private Blob downloadFile(String audioUrl) {
        // 2. Download audio data as Blob (in memory), following redirects
        Blob audioBlob;
        Http http = new Http();

        HttpRequest dreq = new HttpRequest();
        dreq.setEndpoint(audioUrl);
        dreq.setMethod('GET');

        HttpResponse dres;
        try {
            dres = http.send(dreq);
            System.debug('DEBUG: Audio file download HTTP status = ' + dres.getStatusCode());
            
            if (dres.getStatusCode() == 303 || dres.getStatusCode() == 302 || dres.getStatusCode() == 301) {
                String redirectUrl = dres.getHeader('Location');
                System.debug('DEBUG: Redirect URL found: ' + redirectUrl);

                if (!String.isBlank(redirectUrl)) {
                    HttpRequest redirectReq = new HttpRequest();
                    redirectReq.setEndpoint(redirectUrl);
                    redirectReq.setMethod('GET');
                    HttpResponse redirectRes = http.send(redirectReq);
                    System.debug('DEBUG: Redirected request HTTP status = ' + redirectRes.getStatusCode());

                    if (redirectRes.getStatusCode() != 200) {
                        throw new AuraHandledException('Downloading audio after redirect failed: ' + redirectRes.getBody());
                    }

                    dres = redirectRes;  // Use redirected response below
                } else {
                    throw new AuraHandledException('Redirect location header missing from 303 response.');
                }
            }

            if (dres.getStatusCode() != 200) {
                throw new AuraHandledException('Downloading audio failed: ' + dres.getBody());
            }

            audioBlob = dres.getBodyAsBlob();
            System.debug('DEBUG: Audio file Blob size (bytes): ' + audioBlob.size());
            return audioBlob;
        } catch (Exception e) {
            System.debug('ERROR: Failed to GET audio: ' + e.getMessage());
            throw new AuraHandledException('Could not download file from Google Drive: ' + e.getMessage());
        }
    }

    // Send chunk to Gemini API for transcription
    private String getTranscriptForChunk(String base64Audio, String mimeType) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'contents' => new List<Object>{
                new Map<String, Object>{
                    'parts' => new List<Object>{
                        new Map<String, Object>{ 'text' => 'Transcribe this audio file to text.' },
                        new Map<String, Object>{
                            'inline_data' => new Map<String, Object>{
                                'mime_type' => mimeType,
                                'data' => base64Audio
                            }
                        }
                    }
                }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(geminiEndpoint + geminiApiKey);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(requestBody));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            logInChunks('⚠️ Gemini API error: ' + res.getBody());
            return null;
        }

        try {
            Map<String, Object> responseJson = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> candidates = (List<Object>) responseJson.get('candidates');

            if (!candidates.isEmpty()) {
                Map<String, Object> content = (Map<String, Object>) ((Map<String, Object>) candidates[0]).get('content');
                List<Object> parts = (List<Object>) content.get('parts');
                return (String) ((Map<String, Object>) parts[0]).get('text');
            }
        } catch (Exception e) {
            System.debug('⚠️ Gemini JSON Parse Error: ' + e.getMessage());
        }

        return null;
    }

    // Helper: Split base64 string into manageable chunks
    private List<String> splitBase64(String base64, Integer chunkSize) {
        List<String> parts = new List<String>();
        Integer len = base64.length();
        for (Integer i = 0; i < len; i += chunkSize) {
            Integer endPos = Math.min(i + chunkSize, len);
            parts.add(base64.substring(i, endPos));
        }
        return parts;
    }

    // Debug helper: Log long strings in 100-char chunks
    private void logInChunks(String input) {
        if (input == null) return;
        Integer chunkSize = 100;
        for (Integer i = 0; i < input.length(); i += chunkSize) {
            Integer endIndex = Math.min(i + chunkSize, input.length());
            System.debug(input.substring(i, endIndex));
        }
    }
}*/
/*public with sharing class GoogleDriveGeminiTranscriberQueueable implements Queueable, Database.AllowsCallouts {

    private final String geminiApiKey = 'AIzaSyCFvr3jJxae63N7n7kRdjdcxtbuZag4Smk';
    public static final Id FALLBACK_ContactID = '003gL000006BSbqQAG'; // fallback if label missing
    private final String geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=';

    private final Integer baseChunkSize = 500000;

    public void execute(QueueableContext context) {
        System.debug('Queueable started: GoogleDriveGeminiTranscriberQueueable');

        List<CallLog__c> logsToInsert = new List<CallLog__c>();

        List<Items_GoogleDriveDataSource__x> driveFiles = [
            SELECT Name__c, DisplayUrl
            FROM Items_GoogleDriveDataSource__x
            WHERE IsFolder__c = false
        ];
        System.debug(' Total Drive Files Found: ' + driveFiles.size());

        if (driveFiles.isEmpty()) return;

        Set<String> existingNames = new Set<String>();
        for (CallLog__c log : [SELECT Name FROM CallLog__c WHERE Name LIKE 'Transcript - %']) {
            existingNames.add(log.Name);
        }
        System.debug(' Existing Transcript Count: ' + existingNames.size());

        for (Items_GoogleDriveDataSource__x file : driveFiles) {
            String transcriptName = 'Transcript - ' + file.Name__c;

            if (existingNames.contains(transcriptName)) {
                System.debug('⏭ Skipping Already Processed File: ' + file.Name__c);
                continue;
            }

            CallLog__c newLog;

            try {
                System.debug(' Processing File: ' + file.Name__c);

                String fileUrl = convertToDirectDownloadUrl(file.DisplayUrl);
                Blob audioBlob = downloadFile(fileUrl);
                System.debug(' Audio blob retrieved: size = ' + audioBlob.size());

                String base64Audio = EncodingUtil.base64Encode(audioBlob);
                List<String> chunks = splitBase64(base64Audio, baseChunkSize);
                System.debug(' Total Chunks: ' + chunks.size());

                List<String> partials = new List<String>();
                for (Integer i = 0; i < chunks.size(); i++) {
                    String chunk = chunks[i];
                    System.debug(' Transcribing Chunk ' + (i + 1) + '/' + chunks.size());

                    String transcriptChunk = getTranscriptForChunk(chunk, 'audio/mp3');
                    if (transcriptChunk != null) {
                        partials.add(transcriptChunk.trim());
                    } else {
                        partials.add('[FAILED_CHUNK_' + i + ']');
                        System.debug('️ Failed Chunk: ' + i);
                    }
                }

                String finalTranscript = String.join(partials, '\n');
                System.debug(' Final Transcript Length: ' + finalTranscript.length());
                
                List<String> parts = transcriptName != null ? transcriptName.split('_') : new List<String>();
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
                    System.debug('Invalid filename format for: ' + transcriptName);
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
                List<Agent__c> agents = [SELECT Id FROM Agent__c LIMIT 1];
                Id agentId;
                
                if (!agents.isEmpty()) {
                    agentId = agents[0].Id;
                    System.debug('Agent Id: ' + agentId);
                }
                
                
                newLog = new CallLog__c(
                    Name = transcriptName,
                    File_Link__c = file.DisplayUrl,
                    Download_File_Link__c = fileUrl,
                    transcript_Desc__c = finalTranscript,
                    Call_Status__c = 'In-Progress',
                    AgentID__c = agentId,
                    Client__c = client.Id,
                    Contact__c = FALLBACK_ContactID,
                    CallEndTime__c = callEnd,
                    CallStartTime__c = callStart,
                    Mobile_Number__c = mobileNumber
                );

            } catch (Exception e) {
                System.debug(' Error Processing File: ' + file.Name__c + ' => ' + e.getMessage());

                newLog = new CallLog__c(
                    Name = transcriptName,
                    File_Link__c = file.DisplayUrl,
                    transcript_Desc__c = 'Error during transcription: ' + e.getMessage()
                );
            }

            if (newLog != null) {
                logsToInsert.add(newLog);
            }
        }

            if (!logsToInsert.isEmpty()) {
                insert logsToInsert;
            }
        
        

        System.debug(' Queueable Execution Finished.');
    }

    private static String convertToDirectDownloadUrl(String originalUrl) {
        System.debug('DEBUG: Original Google Drive URL: ' + originalUrl);
        if (String.isBlank(originalUrl)) return originalUrl;

        Integer fileIdStart = originalUrl.indexOf('/d/');
        if (fileIdStart == -1) {
            System.debug('DEBUG: /d/ not found in URL, returning original URL');
            return originalUrl;
        }
        fileIdStart += 3;
        Integer fileIdEndSlash = originalUrl.indexOf('/', fileIdStart);
        Integer fileIdEndQuery = originalUrl.indexOf('?', fileIdStart);
        Integer fileIdEnd;
        if (fileIdEndSlash == -1 && fileIdEndQuery == -1) {
            fileIdEnd = originalUrl.length();
        } else if (fileIdEndSlash == -1) {
            fileIdEnd = fileIdEndQuery;
        } else if (fileIdEndQuery == -1) {
            fileIdEnd = fileIdEndSlash;
        } else {
            fileIdEnd = Math.min(fileIdEndSlash, fileIdEndQuery);
        }
        String fileId = originalUrl.substring(fileIdStart, fileIdEnd);
        String convertedUrl = 'https://drive.google.com/uc?export=download&id=' + fileId;
        System.debug('DEBUG: Converted Google Drive direct download URL: ' + convertedUrl);
        return convertedUrl;
    }

    private Blob downloadFile(String audioUrl) {
        Blob audioBlob;
        Http http = new Http();
        HttpRequest dreq = new HttpRequest();
        dreq.setEndpoint(audioUrl);
        dreq.setMethod('GET');

        HttpResponse dres;
        try {
            dres = http.send(dreq);
            System.debug('DEBUG: Audio file download HTTP status = ' + dres.getStatusCode());

            if (dres.getStatusCode() == 303 || dres.getStatusCode() == 302 || dres.getStatusCode() == 301) {
                String redirectUrl = dres.getHeader('Location');
                System.debug('DEBUG: Redirect URL found: ' + redirectUrl);

                if (!String.isBlank(redirectUrl)) {
                    HttpRequest redirectReq = new HttpRequest();
                    redirectReq.setEndpoint(redirectUrl);
                    redirectReq.setMethod('GET');
                    HttpResponse redirectRes = http.send(redirectReq);
                    System.debug('DEBUG: Redirected request HTTP status = ' + redirectRes.getStatusCode());

                    if (redirectRes.getStatusCode() != 200) {
                        throw new AuraHandledException('Downloading audio after redirect failed: ' + redirectRes.getBody());
                    }

                    dres = redirectRes;
                } else {
                    throw new AuraHandledException('Redirect location header missing from 303 response.');
                }
            }

            if (dres.getStatusCode() != 200) {
                throw new AuraHandledException('Downloading audio failed: ' + dres.getBody());
            }

            audioBlob = dres.getBodyAsBlob();
            System.debug('DEBUG: Audio file Blob size (bytes): ' + audioBlob.size());
            return audioBlob;
        } catch (Exception e) {
            System.debug('ERROR: Failed to GET audio: ' + e.getMessage());
            throw new AuraHandledException('Could not download file from Google Drive: ' + e.getMessage());
        }
    }

    private String getTranscriptForChunk(String base64Audio, String mimeType) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'contents' => new List<Object>{
                new Map<String, Object>{
                    'parts' => new List<Object>{
                        new Map<String, Object>{ 'text' => 'Transcribe this audio file to text.' },
                        new Map<String, Object>{
                            'inline_data' => new Map<String, Object>{
                                'mime_type' => mimeType,
                                'data' => base64Audio
                            }
                        }
                    }
                }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(geminiEndpoint + geminiApiKey);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(requestBody));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            logInChunks(' Gemini API error: ' + res.getBody());
            return null;
        }

        try {
            Map<String, Object> responseJson = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> candidates = (List<Object>) responseJson.get('candidates');

            if (!candidates.isEmpty()) {
                Map<String, Object> content = (Map<String, Object>) ((Map<String, Object>) candidates[0]).get('content');
                List<Object> parts = (List<Object>) content.get('parts');
                return (String) ((Map<String, Object>) parts[0]).get('text');
            }
        } catch (Exception e) {
            System.debug(' Gemini JSON Parse Error: ' + e.getMessage());
        }

        return null;
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

    private void logInChunks(String input) {
        if (input == null) return;
        Integer chunkSize = 100;
        for (Integer i = 0; i < input.length(); i += chunkSize) {
            Integer endIndex = Math.min(i + chunkSize, input.length());
            System.debug(input.substring(i, endIndex));
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
}*/
public with sharing class GoogleDriveGeminiTranscriberQueueable implements Queueable, Database.AllowsCallouts {

    private final String geminiApiKey = 'AIzaSyCFvr3jJxae63N7n7kRdjdcxtbuZag4Smk';
    public static final Id FALLBACK_ContactID = '003gL000006BSbqQAG'; 
    private final String geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=';

    private final Integer baseChunkSize = 500000;

    public void execute(QueueableContext context) {
        System.debug('Queueable started: GoogleDriveGeminiTranscriberQueueable');

        List<CallLog__c> logsToInsert = new List<CallLog__c>();

        List<Items_GoogleDriveDataSource__x> driveFiles = [
            SELECT Name__c, DisplayUrl
            FROM Items_GoogleDriveDataSource__x
            WHERE IsFolder__c = false
        ];
        System.debug('Total Drive Files Found: ' + driveFiles.size());

        if (driveFiles.isEmpty()) return;

        Set<String> existingNames = new Set<String>();
        for (CallLog__c log : [SELECT Name FROM CallLog__c WHERE Name LIKE 'Transcript - %']) {
            existingNames.add(log.Name);
        }
        System.debug('Existing Transcript Count: ' + existingNames.size());

        for (Items_GoogleDriveDataSource__x file : driveFiles) {
            String transcriptName = 'Transcript - ' + file.Name__c;

            if (existingNames.contains(transcriptName)) {
                System.debug('Skipping Already Processed File: ' + file.Name__c);
                continue;
            }

            CallLog__c newLog;

            try {
                System.debug('Processing File: ' + file.Name__c);

                String fileUrl = convertToDirectDownloadUrl(file.DisplayUrl);
                Blob audioBlob = downloadFile(fileUrl);
                System.debug('Audio blob retrieved: size = ' + audioBlob.size());

                String base64Audio = EncodingUtil.base64Encode(audioBlob);
                List<String> chunks = splitBase64(base64Audio, baseChunkSize);
                System.debug('Total Chunks: ' + chunks.size());

                List<String> partials = new List<String>();
                for (Integer i = 0; i < chunks.size(); i++) {
                    String chunk = chunks[i];
                    System.debug('Transcribing Chunk ' + (i + 1) + '/' + chunks.size());

                    String transcriptChunk = getTranscriptForChunk(chunk, 'audio/mp3');
                    if (transcriptChunk != null) {
                        partials.add(transcriptChunk.trim());
                    } else {
                        partials.add('[FAILED_CHUNK_' + i + ']');
                        System.debug('Failed Chunk: ' + i);
                    }
                }

                String finalTranscript = String.join(partials, '\n');
                System.debug(' Final Transcript Length: ' + finalTranscript.length());
                
                // Remove prefix and suffix
                String cleanedName = transcriptName != null 
                    ? transcriptName.replace('Transcript - ', '').replace('.mp3', '') 
                    : '';
                
                List<String> parts = cleanedName.split('_');
                DateTime callStart, callEnd;
                String mobileNumber , isMerged , mergedCall , transcriptAgentId;
                
                if (parts.size() >= 5) {
                    String dateStr = parts[1];
                    String startTimeStr = parts[2];
                    String endTimeStr = parts[3];
                    mobileNumber = parts[0];
                    transcriptAgentId = parts[4];
                    
                    // Handle optional merge info safely
                    if (parts.size() > 5) {
                        isMerged = parts[5];                        
                        
                        // Extract merge ID if present
                        if (cleanedName.contains('(') && cleanedName.contains(')')) {
                            Integer startIndex = cleanedName.indexOf('(') + 1;
                            Integer endIndex = cleanedName.indexOf(')');
                            mergedCall = cleanedName.substring(startIndex, endIndex);
                        }
                        System.debug(' isMerged: ' + isMerged + ', mergedCall: ' + mergedCall);
                    }
                    
                    String formattedStart = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                        + ' ' + startTimeStr.substring(0,2) + ':' + startTimeStr.substring(2,4) + ':' + startTimeStr.substring(4,6);
                    String formattedEnd = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                        + ' ' + endTimeStr.substring(0,2) + ':' + endTimeStr.substring(2,4) + ':' + endTimeStr.substring(4,6);
                    
                    callStart = DateTime.valueOf(formattedStart);
                    callEnd = DateTime.valueOf(formattedEnd);
                    
                    System.debug('Mobile Number: ' + mobileNumber);
                    System.debug('Start: ' + callStart + ', End: ' + callEnd);
                } else {
                    System.debug('Invalid filename format for: ' + transcriptName);
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
                
                List<Agent__c> agents = [SELECT Id , User__c  FROM Agent__c where Name =: transcriptAgentId];
                Id agentId , agentUserId ;
                
                if (!agents.isEmpty()) {
                    agentId = agents[0].Id;
                    agentUserId = agents[0].User__c;
                    System.debug('Agent Id: ' + agentId);
                }
                
                
                newLog = new CallLog__c(
                    Name = transcriptName,
                    File_Link__c = file.DisplayUrl,
                    Download_File_Link__c = fileUrl,
                    transcript_Desc__c = finalTranscript,
                    Call_Status__c = 'In-Progress',
                    AgentID__c = agentId,
                    Client__c = client.Id,
                    Contact__c = FALLBACK_ContactID,
                    CallEndTime__c = callEnd,
                    CallStartTime__c = callStart,
                    Mobile_Number__c = mobileNumber
                    //,
                    //OwnerId = agentUserId
                );

                /*newLog = new CallLog__c(
                    Name = transcriptName,
                    File_Link__c = fileUrl,
                    transcript_Desc__c = finalTranscript
                );*/

            } catch (Exception e) {
                System.debug(' Error Processing File: ' + file.Name__c + ' => ' + e.getMessage());

                newLog = new CallLog__c(
                    Name = transcriptName,
                    File_Link__c = file.DisplayUrl,
                    transcript_Desc__c = 'Error during transcription: ' + e.getMessage()
                );
            }

            if (newLog != null) {
                logsToInsert.add(newLog);
            }
        }

        if (!logsToInsert.isEmpty()) {
            insert logsToInsert;
            System.debug('Inserted Logs Count: ' + logsToInsert.size());
        }

        System.debug(' Queueable Execution Finished.');
    }

    private static String convertToDirectDownloadUrl(String originalUrl) {
        System.debug('DEBUG: Original Google Drive URL: ' + originalUrl);
        if (String.isBlank(originalUrl)) return originalUrl;

        Integer fileIdStart = originalUrl.indexOf('/d/');
        if (fileIdStart == -1) {
            System.debug('DEBUG: /d/ not found in URL, returning original URL');
            return originalUrl;
        }
        fileIdStart += 3;
        Integer fileIdEndSlash = originalUrl.indexOf('/', fileIdStart);
        Integer fileIdEndQuery = originalUrl.indexOf('?', fileIdStart);
        Integer fileIdEnd;
        if (fileIdEndSlash == -1 && fileIdEndQuery == -1) {
            fileIdEnd = originalUrl.length();
        } else if (fileIdEndSlash == -1) {
            fileIdEnd = fileIdEndQuery;
        } else if (fileIdEndQuery == -1) {
            fileIdEnd = fileIdEndSlash;
        } else {
            fileIdEnd = Math.min(fileIdEndSlash, fileIdEndQuery);
        }
        String fileId = originalUrl.substring(fileIdStart, fileIdEnd);
        String convertedUrl = 'https://drive.google.com/uc?export=download&id=' + fileId;
        System.debug('DEBUG: Converted Google Drive direct download URL: ' + convertedUrl);
        return convertedUrl;
    }

    private Blob downloadFile(String audioUrl) {
        Blob audioBlob;
        Http http = new Http();
        HttpRequest dreq = new HttpRequest();
        dreq.setEndpoint(audioUrl);
        dreq.setMethod('GET');

        HttpResponse dres;
        try {
            dres = http.send(dreq);
            System.debug('DEBUG: Audio file download HTTP status = ' + dres.getStatusCode());

            if (dres.getStatusCode() == 303 || dres.getStatusCode() == 302 || dres.getStatusCode() == 301) {
                String redirectUrl = dres.getHeader('Location');
                System.debug('DEBUG: Redirect URL found: ' + redirectUrl);

                if (!String.isBlank(redirectUrl)) {
                    HttpRequest redirectReq = new HttpRequest();
                    redirectReq.setEndpoint(redirectUrl);
                    redirectReq.setMethod('GET');
                    HttpResponse redirectRes = http.send(redirectReq);
                    System.debug('DEBUG: Redirected request HTTP status = ' + redirectRes.getStatusCode());

                    if (redirectRes.getStatusCode() != 200) {
                        throw new AuraHandledException('Downloading audio after redirect failed: ' + redirectRes.getBody());
                    }

                    dres = redirectRes;
                } else {
                    throw new AuraHandledException('Redirect location header missing from 303 response.');
                }
            }

            if (dres.getStatusCode() != 200) {
                throw new AuraHandledException('Downloading audio failed: ' + dres.getBody());
            }

            audioBlob = dres.getBodyAsBlob();
            System.debug('DEBUG: Audio file Blob size (bytes): ' + audioBlob.size());
            return audioBlob;
        } catch (Exception e) {
            System.debug('ERROR: Failed to GET audio: ' + e.getMessage());
            throw new AuraHandledException('Could not download file from Google Drive: ' + e.getMessage());
        }
    }
    
    private String getTranscriptForChunk(String base64Audio, String mimeType) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'contents' => new List<Object>{
                new Map<String, Object>{
                    'parts' => new List<Object>{
                        new Map<String, Object>{ 'text' => 'Transcribe this audio file to text.' },
                        new Map<String, Object>{
                            'inline_data' => new Map<String, Object>{
                                'mime_type' => mimeType,
                                'data' => base64Audio
                            }
                        }
                    }
                }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(geminiEndpoint + geminiApiKey);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(requestBody));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            logInChunks(' Gemini API error: ' + res.getBody());
            return null;
        }

        try {
            Map<String, Object> responseJson = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> candidates = (List<Object>) responseJson.get('candidates');

            if (!candidates.isEmpty()) {
                Map<String, Object> content = (Map<String, Object>) ((Map<String, Object>) candidates[0]).get('content');
                List<Object> parts = (List<Object>) content.get('parts');
                return (String) ((Map<String, Object>) parts[0]).get('text');
            }
        } catch (Exception e) {
            System.debug(' Gemini JSON Parse Error: ' + e.getMessage());
        }

        return null;
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

    private void logInChunks(String input) {
        if (input == null) return;
        Integer chunkSize = 100;
        for (Integer i = 0; i < input.length(); i += chunkSize) {
            Integer endIndex = Math.min(i + chunkSize, input.length());
            System.debug(input.substring(i, endIndex));
        }
    }
    public static void updateTranscriptDescriptions(Id logId, String transcriptText, String callStatus, String promptStatus , String Feature_CC) {
        if (logId != null && transcriptText != null && callStatus != null ) {
            System.debug('Enqueuing job for specific CallLog');
            System.enqueueJob(new TranscriptProcessorQueueable(logId, transcriptText, callStatus, promptStatus , Feature_CC	));
        } else {
            List<CallLog__c> pending = [
                SELECT Id, transcript_Desc__c, Call_Status__c, PromptStatus__c , Feature_CC__c	
                FROM CallLog__c
                LIMIT 100
            ];
            for (CallLog__c log : pending) {
                System.enqueueJob(new TranscriptProcessorQueueable(log.Id, log.transcript_Desc__c, log.Call_Status__c, log.PromptStatus__c , log.Feature_CC__c));
            }
        }
    }
}
//System.enqueueJob(new GoogleDriveGeminiTranscriberQueueable());
//GoogleDriveGeminiTranscriberQueueable.updateTranscriptDescriptions(null,null,null,null);