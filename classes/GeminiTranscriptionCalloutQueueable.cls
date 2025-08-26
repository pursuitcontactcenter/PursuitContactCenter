// 3. Callout-only queueable: downloads audio, calls Gemini, builds transcript and payload
public with sharing class GeminiTranscriptionCalloutQueueable implements Queueable, Database.AllowsCallouts {
    private Id driveFileId;
    private final Integer baseChunkSize = 500000;
    private final String geminiApiKey = 'AIzaSyCFvr3jJxae63N7n7kRdjdcxtbuZag4Smk';
    private final String geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=';

    public GeminiTranscriptionCalloutQueueable(Id driveFileId) {
        this.driveFileId = driveFileId;
    }

    public void execute(QueueableContext ctx) {
        try {
            Items_GoogleDriveDataSource__x file = [
                SELECT Name__c, DisplayUrl
                FROM Items_GoogleDriveDataSource__x
                WHERE Id = :driveFileId
                LIMIT 1
            ];
            String transcriptName = 'Transcript - ' + file.Name__c;
            //String transcriptName = file.Name__c;
            String fileUrl = convertToDirectDownloadUrl(file.DisplayUrl);
            Blob audioBlob = downloadFile(fileUrl);
            String base64Audio = EncodingUtil.base64Encode(audioBlob);
            List<String> chunks = splitBase64(base64Audio, baseChunkSize);
            
            //------------------------
            String fileNameLower = file.Name__c;
            String mimeType;
            
            // Determine MIME type based on file extension
            if (fileNameLower.endsWith('.aac')) {
                mimeType = 'audio/aac';
            } else if (fileNameLower.endsWith('.wav')) {
                mimeType = 'audio/wav';
            } else {
                mimeType = 'audio/mp3'; // default
            }
            
            // Remove extension dynamically
            String cleanedName = transcriptName.replace('Transcript - ', '');
            Integer dotIndex = cleanedName.lastIndexOf('.');
            if (dotIndex > -1) {
                cleanedName = cleanedName.substring(0, dotIndex);
            }

            List<String> partials = new List<String>();
            for (Integer i = 0; i < chunks.size(); i++) {
                String transcriptChunk = getTranscriptForChunk(chunks[i], 'audio/mp3');
                if (transcriptChunk != null) {
                    partials.add(transcriptChunk.trim());
                } else {
                    partials.add('[FAILED_CHUNK_' + i + ']');
                }
            }
            String finalTranscript = String.join(partials, '\n');

            //String cleanedName = transcriptName.replace('Transcript - ', '').replace('.mp3', '');
            List<String> parts = cleanedName.split('_');
            if (parts.size() < 5) {
                System.debug('Invalid filename format for: ' + transcriptName);
                return;
            }

            String mobileNumber = parts[0];
            String dateStr = parts[1];
            String startTimeStr = parts[2];
            String endTimeStr = parts[3];
            String transcriptAgentId = parts[4];
            String isMerged = '' , mergedCallID = '';
            String Feature_CC = '';
            CallLog__c parentMergedCall;
            List<CallLog__c> parentcall = new List<CallLog__c>();
            
            // Handle optional merge info safely
            if (parts.size() > 5) {
                isMerged = parts[5];                        
                
                // Extract merge ID if present
                if (cleanedName.contains('(') && cleanedName.contains(')')) {
                    Integer startIndex = cleanedName.indexOf('(') + 1;
                    Integer endIndex = cleanedName.indexOf(')');
                    mergedCallID = cleanedName.substring(startIndex, endIndex);
                }
                System.debug(' isMerged: ' + isMerged + ', mergedCall: ' + mergedCallID);
                parentcall = [
                    SELECT Id , AgentID__c , AgentID__r.Name , transcript_Desc__c
                    FROM CallLog__c 
                    WHERE CallLogId__c = :mergedCallID 
                    LIMIT 1
                ];
                if (!parentcall.isEmpty()) {
                    parentMergedCall = parentcall[0];
                }
            }
            
            String formattedStart = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                + ' ' + startTimeStr.substring(0,2) + ':' + startTimeStr.substring(2,4) + ':' + startTimeStr.substring(4,6);
            String formattedEnd = dateStr.substring(0,4) + '-' + dateStr.substring(4,6) + '-' + dateStr.substring(6,8)
                + ' ' + endTimeStr.substring(0,2) + ':' + endTimeStr.substring(2,4) + ':' + endTimeStr.substring(4,6);
            DateTime callStart = DateTime.valueOf(formattedStart);
            DateTime callEnd = DateTime.valueOf(formattedEnd);
            
            TranscriptPayload payload = new TranscriptPayload();
            if (parts.size() > 5) {
                System.debug(' parts[5]--------->: ' + parts[5]);
                Feature_CC = parts[5];                 
                if(Feature_CC != 'H' && parts.size() > 6){
                    Feature_CC = parts[6]; 
                    if(Feature_CC == 'H'){
                        payload.Feature_CC = 'Hospital CC';
                    }else{
                        payload.Feature_CC = 'Real Estate CC';
                    }
                }else if(Feature_CC == 'H'){
                    payload.Feature_CC = 'Hospital CC';
                }else{
                    payload.Feature_CC = 'Real Estate CC';
                }
            }else{
                    payload.Feature_CC = 'Real Estate CC';
                }
            
            if (parentMergedCall != null) {
                payload.parentMergedCall = parentMergedCall;
                payload.parentMergedCallId = parentMergedCall.Id;
                payload.historyTrack = 'Previous agent : ' + parentMergedCall.AgentID__r.Name + ' -> Current agent : ' + transcriptAgentId;
                payload.parentMergedCallLog = parentMergedCall.transcript_Desc__c;
            } 
            else {
                payload.parentMergedCall = null;
                payload.parentMergedCallId = null;
                payload.historyTrack = null;
                payload.parentMergedCallLog = null;
            }

            
            payload.transcriptName = transcriptName;
            payload.fileDisplayUrl = file.DisplayUrl;
            payload.fileUrl = fileUrl;
            payload.finalTranscript = finalTranscript;
            payload.callStart = callStart;
            payload.callEnd = callEnd;
            payload.mobileNumber = mobileNumber;
            payload.transcriptAgentId = transcriptAgentId;
            payload.isMerged = isMerged;
            payload.mergedCallID = mergedCallID;
            //payload.parentMergedCall = parentMergedCall;
            //payload.parentMergedCallId =  parentMergedCall != null ? parentMergedCall.Id : null;
            //payload.historyTrack =  parentMergedCall != null ? ( 'Previous agent : '+parentMergedCall.AgentID__r.Name + ' -> Current agent : ' + transcriptAgentId ): null;
            //payload.parentMergedCallLog = parentMergedCall.transcript_Desc__c;
            

            System.enqueueJob(new GeminiTranscriptionDMLQueueable(payload));
        } catch (Exception e) {
            System.debug('Callout/transcription failed for file id ' + driveFileId + ' => ' + e.getMessage());
        }
    }

    // Helper: convert original Google Drive URL to direct download
    public static String convertToDirectDownloadUrl(String originalUrl) {
        if (String.isBlank(originalUrl)) return originalUrl;
        Integer fileIdStart = originalUrl.indexOf('/d/');
        if (fileIdStart == -1) return originalUrl;
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
        return 'https://drive.google.com/uc?export=download&id=' + fileId;
    }

    /*private Blob downloadFile(String audioUrl) {
        Http http = new Http();
        HttpRequest dreq = new HttpRequest();
        dreq.setEndpoint(audioUrl);
        dreq.setMethod('GET');

        HttpResponse dres;
        try {
            dres = http.send(dreq);
            if (dres.getStatusCode() == 303 || dres.getStatusCode() == 302 || dres.getStatusCode() == 301) {
                String redirectUrl = dres.getHeader('Location');
                if (!String.isBlank(redirectUrl)) {
                    HttpRequest redirectReq = new HttpRequest();
                    redirectReq.setEndpoint(redirectUrl);
                    redirectReq.setMethod('GET');
                    HttpResponse redirectRes = http.send(redirectReq);
                    if (redirectRes.getStatusCode() != 200) {
                        System.debug('Downloading audio after redirect failed: ' + redirectRes.getBody());
                        //throw new System.Exception('Downloading audio after redirect failed: ' + redirectRes.getBody());
                    }
                    dres = redirectRes;
                } else {
                    System.debug('Redirect location header missing from 303 response.');
                    //throw new System.Exception('Redirect location header missing from 303 response.');
                }
            }

            if (dres.getStatusCode() != 200) {
                System.debug('Downloading audio failed: ' + dres.getBody());
                //throw new System.Exception('Downloading audio failed: ' + dres.getBody());
            }

            return dres.getBodyAsBlob();
        } catch (Exception e) {
            System.debug('ERROR: Failed to GET audio: ' + e.getMessage());
            //throw new System.Exception('Could not download file from Google Drive: ' + e.getMessage());
        }
    }*/
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

    private List<String> splitBase64(String base64, Integer chunkSize) {
        List<String> parts = new List<String>();
        Integer len = base64.length();
        for (Integer i = 0; i < len; i += chunkSize) {
            Integer endPos = Math.min(i + chunkSize, len);
            parts.add(base64.substring(i, endPos));
        }
        return parts;
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

    private void logInChunks(String input) {
        if (input == null) return;
        Integer chunkSize = 100;
        for (Integer i = 0; i < input.length(); i += chunkSize) {
            Integer endIndex = Math.min(i + chunkSize, input.length());
            System.debug(input.substring(i, endIndex));
        }
    }
}