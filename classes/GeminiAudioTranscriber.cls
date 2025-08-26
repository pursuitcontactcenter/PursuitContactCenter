/*public class GeminiAudioTranscriber {

    // Gemini API endpoint (replace with your actual API key if needed)
    private static final String ENDPOINT = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=AIzaSyAIsml4zQwvz0pvMOovajYMEMUM-m_C13o';

    public static void transcribeLatestAudio() {
        try {
            // STEP 1: Get the most recently uploaded audio file
            ContentVersion cv = [
                SELECT Id, VersionData, Title, FileExtension
                FROM ContentVersion
                WHERE FileExtension IN ('wav', 'mp3', 'm4a')
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            // STEP 2: Convert the audio to Base64 format
            Blob audioBlob = cv.VersionData;
            String base64Audio = EncodingUtil.base64Encode(audioBlob);

            // STEP 3: Determine MIME type based on file extension
            String mimeType = 'audio/wav'; // default
            if (cv.FileExtension == 'mp3') mimeType = 'audio/mpeg';
            else if (cv.FileExtension == 'm4a') mimeType = 'audio/mp4';

            // STEP 4: Prepare transcription request body
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

            // STEP 5: Send transcription request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestBody));

            Http http = new Http();
            HttpResponse res = http.send(req);

            // STEP 6: Parse transcription response
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> candidates = (List<Object>) responseMap.get('candidates');

            if (candidates == null || candidates.isEmpty()) {
                System.debug('⚠ No transcription result found.');
                return;
            }

            Map<String, Object> firstCandidate = (Map<String, Object>) candidates[0];
            Map<String, Object> contentMap = (Map<String, Object>) firstCandidate.get('content');
            List<Object> parts = (List<Object>) contentMap.get('parts');
            Map<String, Object> textPart = (Map<String, Object>) parts[0];

            String originalTranscript = (String) textPart.get('text');

            // STEP 7: Log full original transcript
            System.debug('===== Original Transcript (auto-detected language) =====');
            logInChunks(originalTranscript);

            // STEP 8: Skip translation if the text is already in English
            if (isLikelyEnglish(originalTranscript)) {
                System.debug(' Skipping translation (already English)');
                return;
            }

            // STEP 9: Prepare translation request
            Map<String, Object> translationPrompt = new Map<String, Object>{
                'parts' => new List<Object>{
                    new Map<String, Object>{ 'text' => 'Translate the following to English:\n' + originalTranscript }
                }
            };

            Map<String, Object> translationBody = new Map<String, Object>{
                'contents' => new List<Object>{ translationPrompt }
            };

            // STEP 10: Send translation request
            HttpRequest translateReq = new HttpRequest();
            translateReq.setEndpoint(ENDPOINT);
            translateReq.setMethod('POST');
            translateReq.setHeader('Content-Type', 'application/json');
            translateReq.setBody(JSON.serialize(translationBody));

            HttpResponse translateRes = http.send(translateReq);

            Map<String, Object> transResponse = (Map<String, Object>) JSON.deserializeUntyped(translateRes.getBody());
            List<Object> transCandidates = (List<Object>) transResponse.get('candidates');

            if (transCandidates == null || transCandidates.isEmpty()) {
                System.debug('⚠No translation result found.');
                return;
            }

            Map<String, Object> firstTrans = (Map<String, Object>) transCandidates[0];
            Map<String, Object> transContent = (Map<String, Object>) firstTrans.get('content');
            List<Object> transParts = (List<Object>) transContent.get('parts');
            Map<String, Object> transText = (Map<String, Object>) transParts[0];

            String englishTranscript = (String) transText.get('text');

            // STEP 11: Log full translated English transcript
            System.debug('===== 🇬🇧 English Translation =====');
            logInChunks(englishTranscript);

        } catch (Exception e) {
            System.debug(' ERROR: ' + e.getMessage());
        }
    }

    // Utility method: Log long strings in safe-size chunks
    private static void logInChunks(String input) {
        Integer chunkSize = 0100;
        for (Integer i = 0; i < input.length(); i += chunkSize) {
            Integer endIndex = Math.min(i + chunkSize, input.length());
            System.debug(input.substring(i, endIndex));
        }
    }
    

    // Utility method: Basic English detection
    private static Boolean isLikelyEnglish(String text) {
        String sample = text.length() > 100 ? text.substring(0, 100) : text;
        return Pattern.matches('^[A-Za-z0-9\\s.,!?\'\"-]+$', sample);
    }
}*/
public class GeminiAudioTranscriber {
    // KEEP AS-IS PER YOUR INSTRUCTION
    private static final String ENDPOINT = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=AIzaSyAIsml4zQwvz0pvMOovajYMEMUM-m_C13o';

    public static void transcribeLatestAudio() {
        ContentVersion cv = [
            SELECT Id
            FROM ContentVersion
            WHERE FileExtension IN ('wav', 'mp3', 'm4a')
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.enqueueJob(new GeminiAudioTranscriberQueueable(cv.Id));
    }

    public class GeminiAudioTranscriberQueueable implements Queueable, Database.AllowsCallouts {
        private Id contentVersionId;
        // start with ~1MB base64 chunk (adjustable)
        private Integer chunkSizeBase64 = 1000000;

        public GeminiAudioTranscriberQueueable(Id cvId) {
            this.contentVersionId = cvId;
        }

        public void execute(QueueableContext ctx) {
            try {
                ContentVersion cv = [
                    SELECT Id, VersionData, Title, FileExtension
                    FROM ContentVersion
                    WHERE Id = :contentVersionId
                    LIMIT 1
                ];

                String mimeType = 'audio/wav';
                if (cv.FileExtension == 'mp3') mimeType = 'audio/mpeg';
                else if (cv.FileExtension == 'm4a') mimeType = 'audio/mp4';

                String fullBase64 = EncodingUtil.base64Encode(cv.VersionData);
                List<String> chunks = splitBase64(fullBase64, chunkSizeBase64);

                List<String> partialTranscripts = new List<String>();
                for (Integer i = 0; i < chunks.size(); i++) {
                    String chunk = chunks[i];
                    String transcriptChunk = getTranscriptForChunk(chunk, mimeType, 0);
                    if (transcriptChunk != null) {
                        partialTranscripts.add(transcriptChunk.trim());
                    } else {
                        partialTranscripts.add('[FAILED_CHUNK_' + i + ']');
                    }
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

                // save transcript
                String transcriptTitle = cv.Title + '_transcript.txt';
                ContentVersion transcriptCv = new ContentVersion();
                transcriptCv.Title = transcriptTitle;
                transcriptCv.PathOnClient = transcriptTitle;
                transcriptCv.VersionData = Blob.valueOf(finalTranscript);
                insert transcriptCv;

            } catch (Exception e) {
                System.debug(' ERROR in queueable: ' + e.getMessage());
            }
        }

        // recursive finer splitting on timeout/failure
        private String getTranscriptForChunk(String base64Chunk, String mimeType, Integer depth) {
            // build request for this chunk
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

                System.debug('body part :- '+requestBody);
            String result = callGemini(requestBody);
            
            if (result != null) return result;

            // on failure/timeouts, try splitting further once (max depth 2)
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

        private List<String> splitBase64(String base64, Integer chunkSize) {
            List<String> parts = new List<String>();
            Integer len = base64.length();
            for (Integer i = 0; i < len; i += chunkSize) {
                Integer endPos = Math.min(i + chunkSize, len);
                parts.add(base64.substring(i, endPos));
            }
            return parts;
        }

        private String callGemini(Map<String, Object> body) {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(body));
            req.setTimeout(120000); // max allowed

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
                        System.debug(' Gemini responded non-2xx: ' + res.getStatusCode() + ' body=' + res.getBody());
                    }
                    break;
                } catch (CalloutException ce) {
                    attempts++;
                    System.debug(' CalloutException, retry ' + attempts + ' : ' + ce.getMessage());
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
}