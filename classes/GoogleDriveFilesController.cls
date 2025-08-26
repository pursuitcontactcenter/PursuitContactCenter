/*public with sharing class GoogleDriveFilesController {
    @AuraEnabled(cacheable=true)
    public static List<GoogleDriveFileWrapper> getGoogleDriveFiles() {
        List<GoogleDriveFileWrapper> results = new List<GoogleDriveFileWrapper>();
        for (Items_GoogleDriveDataSource__x item : [
            SELECT Name__c, DisplayUrl
            FROM Items_GoogleDriveDataSource__x
            WHERE IsFolder__c = false
            ORDER BY Name__c
            LIMIT 100
        ]) {
            results.add(new GoogleDriveFileWrapper(item.Name__c, item.DisplayUrl));
        }
        System.debug('File upload');
        return results;
    }

    public class GoogleDriveFileWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String downloadUrl;
        public GoogleDriveFileWrapper(String name, String downloadUrl) {
            this.name = name;
            this.downloadUrl = downloadUrl;
        }
    }
    
}*/
public with sharing class GoogleDriveFilesController {
    @AuraEnabled(cacheable=true)
    public static List<GoogleDriveFileWrapper> getGoogleDriveFiles() {
        List<GoogleDriveFileWrapper> results = new List<GoogleDriveFileWrapper>();
        for (Items_GoogleDriveDataSource__x item : [
            SELECT Name__c, DisplayUrl
            FROM Items_GoogleDriveDataSource__x
            WHERE IsFolder__c = false
            ORDER BY Name__c
            LIMIT 100
        ]) {
            results.add(new GoogleDriveFileWrapper(item.Name__c, item.DisplayUrl));
        }
        System.debug('File upload');
        return results;
    }

    public class GoogleDriveFileWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String downloadUrl;
        public GoogleDriveFileWrapper(String name, String downloadUrl) {
            this.name = name;
            this.downloadUrl = downloadUrl;
        }
    }
}