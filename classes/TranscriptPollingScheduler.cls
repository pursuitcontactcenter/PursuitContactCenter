public class TranscriptPollingScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        TranscriptRecordHelper.updateTranscriptDescriptions();
    }
}
/*
//--------- store audio transcript id -------------------
AssemblyAIFromSalesforce.transcribeLatestAudioFile();
//TranscriptRecordHelper.updateTranscriptDescriptions();

//--------- update audio into text -------------------
String cron = '0 0 * * * ?'; // Every hour
System.schedule('Transcript Polling Job', cron, new TranscriptPollingScheduler());

*/