trigger CallLogFileHandler on ContentDocumentLink (after insert) {
    Set<Id> docIds = new Set<Id>();
    String callLogPrefix = CallLog__c.SObjectType.getDescribe().getKeyPrefix();

    for (ContentDocumentLink cdl : Trigger.new) {
        if (cdl.LinkedEntityId != null && String.valueOf(cdl.LinkedEntityId).startsWith(callLogPrefix)) {
            docIds.add(cdl.ContentDocumentId);
        }
    }

    if (!docIds.isEmpty()) {
        // adding this job (task or process) to a queue for later processing.
        System.enqueueJob(new AssemblyAIFileProcessorQueueable(docIds));
    }
}