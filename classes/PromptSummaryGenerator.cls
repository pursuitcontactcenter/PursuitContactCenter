public class PromptSummaryGenerator {
    public static String generateSummary() {
       //System.debug('===> Querying L2_Prompt__c records for summary...');
        List<L2_Prompt__c> l2Prompts = [
            SELECT Name, L2_Prompt_Name__c, L1_Prompt__r.Name, 
            L1_Prompt__r.L1_Prompt_Name__c FROM L2_Prompt__c 
            WHERE Name != null AND L1_Prompt__r.Name != null ORDER BY L1_Prompt__r.Name, Name ];

        Map<String, Boolean> seenL1s = new Map<String, Boolean>();
        String summary = '';

        //System.debug('===> Generating summary from ' + l2Prompts.size() + ' records');
        for (L2_Prompt__c l2 : l2Prompts) {
            String l1Id = l2.L1_Prompt__r.Name;
            String l1Name = l2.L1_Prompt__r.L1_Prompt_Name__c;
            String l1Header = 'L1_ID - ' + l1Id + ' - ' + l1Name;

            if (!seenL1s.containsKey(l1Header)) {
                summary += '\n' + l1Header + '\n';
                seenL1s.put(l1Header, true);
               // System.debug('===> Added new L1 group: ' + l1Header);
            }

            summary += 'L2_ID - ' + l2.Name + ' - ' + l2.L2_Prompt_Name__c + '\n';
            //System.debug('===> Appended L2: ' + l2.Name + ' -> ' + l2.L2_Prompt_Name__c);
        }
        return summary.trim();
    }
    
    public static void persistSummaryIfNeeded() {
        System.debug('===> Persisting generated summary...');
        String summaryText = generateSummary();

        Prompt_Summary_Setting__c setting = new Prompt_Summary_Setting__c(
            Name = 'L1L2Summary',
            Summary_Text__c = summaryText
        );

        upsert setting Name;
        System.debug('===> Summary stored successfully in Summary_Setting__c');
    }
}