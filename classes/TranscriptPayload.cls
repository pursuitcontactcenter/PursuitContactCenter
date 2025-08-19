// 2. Payload to pass between the two queueables
public class TranscriptPayload {
    public String transcriptName;
    public String fileDisplayUrl;
    public String fileUrl;
    public String finalTranscript;
    public DateTime callStart;
    public DateTime callEnd;
    public String mobileNumber;
    public String transcriptAgentId;
    public String isMerged;
    public String mergedCallID;
    public String historyTrack;
    public CallLog__c parentMergedCall;
    public Id parentMergedCallId;
    public String parentMergedCallLog;
}