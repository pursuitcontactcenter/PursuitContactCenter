/*global class TranscriptUpdateScheduler implements Schedulable {

    // Set the end time (optional: use Custom Metadata/Custom Setting for flexibility)
    public static DateTime END_TIME = System.now().addDays(1); // runs for 1 day

    global void execute(SchedulableContext sc) {
        System.debug('Running scheduled transcript update at: ' + System.now());

        // Call your method
        AssemblyAIFromSalesforce_UP_1.updateTranscriptDescriptions(null, null, null, null);

        // Reschedule only if within 1 day
        if (System.now() < END_TIME) {
            String cronExp = getCronExpression(5); // every 5 mins
            System.schedule('TranscriptScheduler-' + System.now().getTime(), cronExp, new TranscriptUpdateScheduler());
        }
    }

    private String getCronExpression(Integer intervalMinutes) {
        // Run every intervalMinutes from now
        DateTime dt = System.now().addMinutes(intervalMinutes);
        return String.format('{0} {1} {2} {3} {4} ?',
            new String[] {
                String.valueOf(dt.second()),
                String.valueOf(dt.minute()),
                String.valueOf(dt.hour()),
                String.valueOf(dt.day()),
                String.valueOf(dt.month())
            }
        );
    }
}*/
global class CalllogGenerateSchedular implements Schedulable {
    global void execute(SchedulableContext sc) {
        System.debug('Running CallLogProcessor.processDriveFiles at: ' + System.now());
        try {
            CallLogProcessor.processDriveFiles();
        } catch (Exception e) {
            System.debug('Error in processDriveFiles: ' + e.getMessage());
        }

        // Reschedule after 3 minutes
        try {
            DateTime nextRun = System.now().addMinutes(3);
            String cronExp = buildCronForDateTime(nextRun);
            String jobName = 'CalllogGenerateSchedular-' + nextRun.getTime();
            System.schedule(jobName, cronExp, new CalllogGenerateSchedular());
            System.debug('Rescheduled CalllogGenerateSchedular for: ' + nextRun + ' with cron: ' + cronExp);
        } catch (Exception e) {
            System.debug('Failed to reschedule CalllogGenerateSchedular: ' + e.getMessage());
        }
    }

    private String buildCronForDateTime(DateTime dt) {
        // Salesforce cron: seconds minutes hours day-of-month month day-of-week
        return String.format('{0} {1} {2} {3} {4} ?',
            new String[] {
                String.valueOf(dt.second()),
                String.valueOf(dt.minute()),
                String.valueOf(dt.hour()),
                String.valueOf(dt.day()),
                String.valueOf(dt.month())
            }
        );
    }
}
/* 
// schedule first run of CalllogGenerateSchedular ~15 seconds from now
DateTime firstCalllog = System.now().addSeconds(15);
String cronCalllog = String.format('{0} {1} {2} {3} {4} ?',
    new String[] {
        String.valueOf(firstCalllog.second()),
        String.valueOf(firstCalllog.minute()),
        String.valueOf(firstCalllog.hour()),
        String.valueOf(firstCalllog.day()),
        String.valueOf(firstCalllog.month())
    }
);
System.schedule('CalllogGenerateSchedularInit-' + firstCalllog.getTime(), cronCalllog, new CalllogGenerateSchedular());

*/
//CallLogProcessor.processDriveFiles();
//GoogleDriveGeminiTranscriberQueueable.updateTranscriptDescriptions(null,null,null,null);
/*
 List<CronTrigger> jobsToAbort = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'PromptDataGenerateScheduler%' 
       OR CronJobDetail.Name LIKE 'CalllogGenerateSchedular%'
];

for (CronTrigger job : jobsToAbort) {
    System.abortJob(job.Id);
}
*/