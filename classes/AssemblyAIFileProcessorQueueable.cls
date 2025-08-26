public class AssemblyAIFileProcessorQueueable implements Queueable, Database.AllowsCallouts {
    private Set<Id> contentDocumentIds;

    public AssemblyAIFileProcessorQueueable(Set<Id> contentDocumentIds) {
        this.contentDocumentIds = contentDocumentIds;
    }

    public void execute(QueueableContext context) {
        AssemblyAIFromSalesforce_UP_1.handleFileUpload(contentDocumentIds);
    }
}