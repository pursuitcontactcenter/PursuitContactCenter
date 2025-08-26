//********************************************************** Previous Code ******************************************************
/*public with sharing class PromptInvoker_1 {
    public static String FetchRulesDetails(Id callLogId) {
        System.debug('===== Fetch Prompt START =====');
        try {
            // Step 1: Query CallLog__c record
            CallLog__c callLog = [
                SELECT Id FROM CallLog__c
                WHERE Id = :callLogId
                LIMIT 1
            ];

            // Step 2: Query latest Prompt_Summary_Setting__c record
            Prompt_Summary_Setting__c setting = [
                SELECT Id, Name, Summary_Text__c
                FROM Prompt_Summary_Setting__c
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            // Step 3: Build input parameters
            Map<String, String> recordMap = new Map<String, String>();
            recordMap.put('id', callLogId);

            ConnectApi.WrappedValue callLogInstance = new ConnectApi.WrappedValue();
            callLogInstance.value = recordMap;

            Map<String, String> recordMap1 = new Map<String, String>();
            recordMap1.put('id', setting.Id);

            ConnectApi.WrappedValue callLogInstance1 = new ConnectApi.WrappedValue();
            callLogInstance1.value = recordMap1;

            Map<String, ConnectApi.WrappedValue> inputParamsMap = new Map<String, ConnectApi.WrappedValue>();
            inputParamsMap.put('Input:CallLog', callLogInstance);
            inputParamsMap.put('Input:Prompt_Summary_Setting', callLogInstance1);

            // Step 4: Prepare template request
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.inputParams = inputParamsMap;
            promptInput.isPreview = false;

            // Step 5: Additional Config
            promptInput.additionalConfig = new ConnectApi.EinsteinLLmAdditionalConfigInput();

            // Step 6: Generate the response
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Call_Transcript_Prompt_2', promptInput);

            // Step 7: Extract response
            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
            
            return response.text;

        } catch (Exception e) {
            System.debug('⚠️ Error: ' + e.getMessage());
            return 'Prompt error: ' + e.getMessage();
        }
    }

    public static void StringToJson(String jsonDetails , String callStatus) {
    System.debug('===== StringToJson START =====');
        
    // Step 1: Clean the input BEFORE deserializing
      // Clean up common markdown wrappers or hidden characters
jsonDetails = jsonDetails
    .replaceAll('```json', '')
    .replaceAll('```', '')
    .replaceAll('`', '') // remove stray backticks
    .replaceAll('\u00A0', ' ')
    .trim();
  

    CallLogResponse parsed;

    try {
        // Step 2: Try deserializing the cleaned JSON
        parsed = (CallLogResponse) JSON.deserialize(jsonDetails, CallLogResponse.class);
    } catch (Exception parseEx) {
        System.debug('⚠️ Failed to parse JSON: ' + parseEx.getMessage());
        return; // Exit early, nothing more to do
    }

    try {

        List<FilePathDetail__c> pathDetailsToInsert = new List<FilePathDetail__c>();
        //System.debug('⚠ L1 or L2 prompt details: ' + parsed.L1_L2_Details);

        //if(callStatus != 'Closed' ){
        if (parsed.L1_L2_Details != null && !parsed.L1_L2_Details.isEmpty()) {
            for (String l1Id : parsed.L1_L2_Details.keySet()) {
                String l2Id = parsed.L1_L2_Details.get(l1Id);

                L1_Prompt__c l1Prompt = [SELECT Id FROM L1_Prompt__c WHERE Name = :l1Id LIMIT 1];
                L2_Prompt__c l2Prompt = [SELECT Id FROM L2_Prompt__c WHERE Name = :l2Id LIMIT 1];

                String promptAnswer = '';
                if (parsed.L2_Table?.Yes?.containsKey(l2Id) == true) {
                    promptAnswer = parsed.L2_Table.Yes.get(l2Id);
                }
                CallLog__c cl = [SELECT OwnerId FROM CallLog__c WHERE Id = :parsed.call_id LIMIT 1];
                Id ownerIdFromCallLog = cl.OwnerId;
                
                if (l1Prompt != null && l2Prompt != null) {
                    FilePathDetail__c detail = new FilePathDetail__c(
                        CallLog__c = parsed.call_id,
                        L1_Prompt__c = l1Prompt.Id,
                        L2_Prompt__c = l2Prompt.Id,
                        Agent__c = parsed.agent_id,
                        Client__c = parsed.client_id,
                        Prompt_Answer__c = promptAnswer,
                        OwnerId = ownerIdFromCallLog
                    );
                    pathDetailsToInsert.add(detail);
                }
            }
        }

        // Step 4: DML Operations
        if (!pathDetailsToInsert.isEmpty()) {
            insert pathDetailsToInsert;
        }
    //}
    //
    System.debug('===== Fire Calllog with filepathway =====');
        update new CallLog__c(
            Id = parsed.call_id,
            Mobile_Number__c = parsed.phone_number,
            //Agent_Improvement_Insights__c = parsed.Agent_Improvement_Insights,
            //Process_Improvement_Insights__c = parsed.Process_Improvement_Insights,
            Agent_Improvement_Insights__c = JSON.serialize(parsed.Agent_Improvement_Insights),
            Process_Improvement_Insights__c = JSON.serialize(parsed.Process_Improvement_Insights),
            Engagement_Date__c = parsed.call_date,
            PromptStatus__c = 'Success',
            Category__c = parsed.Category,
            CallType__c = parsed.CallType,
            Quality_of_Call__c = parsed.Quality_of_Call
        );

    } catch (Exception logicEx) {
        System.debug('⚠️ Processing/DML Error: ' + logicEx.getMessage());

        // Fallback: update the prompt status to 'Failed'
        try {
            update new CallLog__c(
                Id = parsed.call_id,
                PromptStatus__c = 'Failed'
            );
        } catch (Exception updateEx) {
            System.debug('⚠️ Failed to update CallLog status to Failed: ' + updateEx.getMessage());
        }
    }
}


    public class CallLogResponse {
    public String client_id;
    public String agent_id;
    public String call_id;
    public Map<String, String> L1_L2_Details;
    public L1Table L1_Table;
    public L2Table L2_Table;
    public Decimal Quality_of_Call;
    public String phone_number;
    public Insights Agent_Improvement_Insights;
    public Insights Process_Improvement_Insights;
    public Date call_date;
    public String CallType;
    public String Category;

}

public class L1Table {
    public Map<String, String> Yes;
    public Map<String, String> No;
}

public class L2Table {
    public Map<String, String> Yes;
    public Map<String, String> No;
}
    
    public class Insights {
    public String Opportunity;
    public String Recommendation;
    public Map<String, String> Guidance;
}

}*/
//**********************************************************  Updated Code  ******************************************************
public with sharing class PromptInvoker_1 {
    public static String FetchRulesDetails(Id callLogId , String Feature_CC) {
        System.debug('===== Fetch Prompt START =====');
        try {
            // Step 1: Query CallLog__c record
            CallLog__c callLog = [
                SELECT Id FROM CallLog__c
                WHERE Id = :callLogId
                LIMIT 1
            ];

            // Step 2: Query latest Prompt_Summary_Setting__c record
            Prompt_Summary_Setting__c setting = [
                SELECT Id, Name, Summary_Text__c
                FROM Prompt_Summary_Setting__c
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            // Step 3: Build input parameters
            Map<String, String> recordMap = new Map<String, String>();
            recordMap.put('id', callLogId);

            ConnectApi.WrappedValue callLogInstance = new ConnectApi.WrappedValue();
            callLogInstance.value = recordMap;

            Map<String, String> recordMap1 = new Map<String, String>();
            recordMap1.put('id', setting.Id);

            ConnectApi.WrappedValue callLogInstance1 = new ConnectApi.WrappedValue();
            callLogInstance1.value = recordMap1;

            Map<String, ConnectApi.WrappedValue> inputParamsMap = new Map<String, ConnectApi.WrappedValue>();
            inputParamsMap.put('Input:CallLog', callLogInstance);
            inputParamsMap.put('Input:Prompt_Summary_Setting', callLogInstance1);

            // Step 4: Prepare template request
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.inputParams = inputParamsMap;
            promptInput.isPreview = false;

            // Step 5: Additional Config
            promptInput.additionalConfig = new ConnectApi.EinsteinLLmAdditionalConfigInput();
            
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput;
            // Step 6: Generate the response
            if ( Feature_CC == 'Real Estate CC'){
                generationsOutput = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Call_Transcript_Prompt_2', promptInput);
            }
            if ( Feature_CC == 'Hospital CC'){
                generationsOutput = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Call_transcript_prompt_hospital', promptInput);
            }

            // Step 7: Extract response
            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
            
            return response.text;

        } catch (Exception e) {
            System.debug('⚠️ Error: ' + e.getMessage());
            return 'Prompt error: ' + e.getMessage();
        }
    }

    public static void StringToJson(String jsonDetails , String callStatus , String Feature_CC) {
        
       System.debug('===== StringToJson START =====');
    
    // Clean common markdown or extra characters
    jsonDetails = jsonDetails
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .replaceAll('`', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\\u2028', '')
        .replaceAll('\\u2029', '')
        .trim();
    
    //Parsed the json
    CallLogResponse parsed;
    try {
        parsed = (CallLogResponse) JSON.deserialize(jsonDetails, CallLogResponse.class);
    } catch (Exception parseEx) {
        System.debug('️ Failed to parse JSON: ' + parseEx.getMessage());
        return; 
    }

    try {
        if ( Feature_CC == 'Real Estate CC'){
            // Update calllog start
            update new CallLog__c(
                Id = parsed.call_id,
                Mobile_Number__c = parsed.phone_number,
                Agent_Improvement_Insights__c = JSON.serialize(parsed.Agent_Improvement_Insights),
                Process_Improvement_Insights__c = JSON.serialize(parsed.Process_Improvement_Insights),
                Engagement_Date__c = parsed.call_date,
                PromptStatus__c = 'Success',
                Category__c = parsed.Category,
                CallType__c = parsed.CallType,
                Quality_of_Call__c = parsed.Quality_of_Call,
                Client_Preferred_Price_Range__c = parsed.Client_Preferred_Price_Range,
                Client_Preferred_Unit_Type__c = parsed.Client_Preferred_Unit_Type,
                Client_Preferred_Location__c = parsed.Client_Preferred_Location,
                Call_Put_On_Hold__c = parsed.Call_Put_On_Hold,
                Call_Satisfied__c = parsed.Call_Satisfied,
                Need_Escalation__c = parsed.Need_Escalation
            );
        }
        if ( Feature_CC == 'Hospital CC'){
            // Update calllog start
            update new CallLog__c(
                Id = parsed.call_id,
                Mobile_Number__c = parsed.phone_number,
                Agent_Improvement_Insights__c = JSON.serialize(parsed.Agent_Improvement_Insights),
                Process_Improvement_Insights__c = JSON.serialize(parsed.Process_Improvement_Insights),
                Engagement_Date__c = parsed.call_date,
                PromptStatus__c = 'Success',
                Category__c = parsed.Category,
                CallType__c = parsed.CallType,
                Quality_of_Call__c = parsed.Quality_of_Call,
                Call_Put_On_Hold__c = parsed.Call_Put_On_Hold,
                Call_Satisfied__c = parsed.Call_Satisfied,
                Need_Escalation__c = parsed.Need_Escalation,
                Patient_Age_H__c = parsed.Patient_Age_H,
                Sector_Type_H__c = parsed.Sector_Type_H,
                Test_Report_H__c = parsed.Test_Report_H
            );
        }
        // Update calllog end
        
        // Filepathway create start
        List<FilePathDetail__c> pathDetailsToInsert = new List<FilePathDetail__c>();
        if (parsed.L1_L2_Details != null && !parsed.L1_L2_Details.isEmpty() && parsed.call_id!= null ) {
            for (String l1Id : parsed.L1_L2_Details.keySet()) {
                String l2Id = parsed.L1_L2_Details.get(l1Id);

                L1_Prompt__c l1Prompt = [SELECT Id FROM L1_Prompt__c WHERE Name = :l1Id LIMIT 1];
                L2_Prompt__c l2Prompt = [SELECT Id FROM L2_Prompt__c WHERE Name = :l2Id LIMIT 1];

                String promptAnswer = '';
                if (parsed.L2_Table?.Yes?.containsKey(l2Id) == true) {
                    promptAnswer = parsed.L2_Table.Yes.get(l2Id);
                }
                CallLog__c cl = [SELECT OwnerId FROM CallLog__c WHERE Id = :parsed.call_id LIMIT 1];
                Id ownerIdFromCallLog = cl.OwnerId;
                
                if (l1Prompt != null && l2Prompt != null) {
                    FilePathDetail__c detail = new FilePathDetail__c(
                        CallLog__c = parsed.call_id,
                        L1_Prompt__c = l1Prompt.Id,
                        L2_Prompt__c = l2Prompt.Id,
                        Agent__c = parsed.agent_id,
                        Client__c = parsed.client_id,
                        Prompt_Answer__c = promptAnswer,
                        OwnerId = ownerIdFromCallLog
                    );
                    pathDetailsToInsert.add(detail);
                }
            }
        }
        if (!pathDetailsToInsert.isEmpty()) {
            insert pathDetailsToInsert;
        }
        System.debug('===== Fire Calllog with filepathway =====');
        // Filepathway create end

    } catch (Exception logicEx) {
        System.debug('⚠️ Processing/DML Error: ' + logicEx.getMessage());
        try {
            update new CallLog__c(
                Id = parsed.call_id,
                PromptStatus__c = 'Failed'
            );
        } catch (Exception updateEx) {
            System.debug('⚠️ Failed to update CallLog status to Failed: ' + updateEx.getMessage());
        }
    }
}


    public class CallLogResponse {
        public String client_id;
        public String agent_id;
        public String call_id;
        public Map<String, String> L1_L2_Details;
        public L1Table L1_Table;
        public L2Table L2_Table;
        public Decimal Quality_of_Call;
        public String phone_number;
        public Insights Agent_Improvement_Insights;
        public Insights Process_Improvement_Insights;
        public Date call_date;
        public String CallType;
        public String Category;
        public String Client_Preferred_Location;
        public String Client_Preferred_Unit_Type;
        public String Client_Preferred_Price_Range;
        public String Call_Put_On_Hold;
        public String Call_Satisfied;
        public String Need_Escalation;
        public String Patient_Age_H;
        public String Sector_Type_H;
        public String Test_Report_H;
    }
    
    public class L1Table {
        public Map<String, String> Yes;
        public Map<String, String> No;
}
    
    public class L2Table {
        public Map<String, String> Yes;
        public Map<String, String> No;
    }
    
    public class Insights {
    public String Opportunity;
    public String Recommendation;
    public Map<String, String> Guidance;
}

}