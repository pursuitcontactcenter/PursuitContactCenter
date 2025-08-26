trigger L2PromptTrigger on L2_Prompt__c (after insert, after update) {
    Boolean shouldRegenerate = false;

    for (L2_Prompt__c newRec : Trigger.new) {
        L2_Prompt__c oldRec = Trigger.isInsert ? null : Trigger.oldMap.get(newRec.Id);

        if (newRec.Name != null &&
            newRec.L1_Prompt__c != null) 
            /* && (Trigger.isInsert ||oldRec.Name != newRec.Name ||oldRec.L1_Prompt__c != newRec.L1_Prompt__c))*/ {
            shouldRegenerate = true;
            break;
        }
    }

    if (shouldRegenerate) {
        System.debug('===> Starting prompt summary generation...');
        PromptSummaryGenerator.persistSummaryIfNeeded();
        System.debug('END ==> ');
    } else {
        System.debug('===> No changes detected to regenerate summary.');
    }
}