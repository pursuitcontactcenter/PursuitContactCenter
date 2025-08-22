public with sharing class CallLogProcessor {

    public static void processDriveFiles() {
        List<Items_GoogleDriveDataSource__x> driveFiles = [
            SELECT Name__c, DisplayUrl
            FROM Items_GoogleDriveDataSource__x
            WHERE IsFolder__c = false
        ];
        System.debug('Total Drive Files Found: ' + driveFiles.size());

        if (driveFiles.isEmpty()) {
            System.debug('No drive files found. Exiting.');
            return;
        }

        // Collect existing transcripts
        Set<String> existingNames = new Set<String>();
        for (CallLog__c log : [SELECT Name FROM CallLog__c WHERE Name LIKE 'Transcript - %']) {
            existingNames.add(log.Name);
        }
        System.debug('Existing Transcript Count: ' + existingNames.size());

        // Loop through drive files and enqueue for processing
        for (Items_GoogleDriveDataSource__x file : driveFiles) {
            String transcriptName = 'Transcript - ' + file.Name__c;

            if (existingNames.contains(transcriptName)) {
                System.debug('Skipping Already Processed File: ' + file.Name__c);
                continue;
            }

            // Enqueue the job
            System.enqueueJob(new GeminiTranscriptionCalloutQueueable(file.Id));
            System.debug('Enqueued job for file: ' + file.Name__c);
        }
    }
}