public with sharing class InsertDataWithPromptResult {
    
    public static void StringToJson(String jsonDetails) {

        // Step 1: Remove Markdown backticks
        System.debug('jsonDetails: ' + jsonDetails);
        
        jsonDetails = jsonDetails.replaceAll('```json', '')
                                 .replaceAll('```', '')
                                 .trim();

        // Step 2: Normalize whitespace (replace Unicode 160 with normal space)
        jsonDetails = jsonDetails.replaceAll('\u00A0', ' ');

        // Step 3: Deserialize
        CallLogResponse parsed = (CallLogResponse) JSON.deserialize(jsonDetails, CallLogResponse.class);

        // Step 4: Use parsed data
        System.debug('Client ID: ' + parsed.client_id);
        System.debug('Agent ID: ' + parsed.agent_id);
    }

    public class CallLogResponse {
        public String client_id;
        public String agent_id;
    }
}