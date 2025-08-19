global class PromptDataGenerateScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        System.debug('Running GoogleDriveGeminiTranscriberQueueable.updateTranscriptDescriptions at: ' + System.now());
        try {
            GoogleDriveGeminiTranscriberQueueable.updateTranscriptDescriptions(null, null, null, null);
        } catch (Exception e) {
            System.debug('Error in updateTranscriptDescriptions: ' + e.getMessage());
        }

        // Reschedule after 2 minutes
        try {
            DateTime nextRun = System.now().addMinutes(3);
            String cronExp = buildCronForDateTime(nextRun);
            String jobName = 'PromptDataGenerateScheduler-' + nextRun.getTime();
            System.schedule(jobName, cronExp, new PromptDataGenerateScheduler());
            System.debug('Rescheduled PromptDataGenerateScheduler for: ' + nextRun + ' with cron: ' + cronExp);
        } catch (Exception e) {
            System.debug('Failed to reschedule PromptDataGenerateScheduler: ' + e.getMessage());
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
// schedule first run of PromptDataGenerateScheduler ~10 seconds from now
DateTime firstPrompt = System.now().addSeconds(10);
String cronPrompt = String.format('{0} {1} {2} {3} {4} ?',
    new String[] {
        String.valueOf(firstPrompt.second()),
        String.valueOf(firstPrompt.minute()),
        String.valueOf(firstPrompt.hour()),
        String.valueOf(firstPrompt.day()),
        String.valueOf(firstPrompt.month())
    }
);
System.schedule('PromptDataGenerateSchedulerInit-' + firstPrompt.getTime(), cronPrompt, new PromptDataGenerateScheduler());
*/