/**
 * @description       : Service class for Event Detail LWC component (RSVP functionality removed)
 * @author            : Amit Singh (Updated)
 * @last modified on  : 04-30-2025
**/
public with sharing class EventDetailLwcService {
    
    @AuraEnabled(cacheable=true)
    public static Event__c fetchEventDetails(String recordId){
        Event__c eventRecord = new Event__c();
        try {
            // Query event details using without sharing to ensure guest users can access
            // We're still using security checks but enabling record visibility
            String query = 'SELECT Id, Name, CreatedDate, '
                        + 'Location__c, Event_Completed__c, Event_Organizer__c, Event_Organizer__r.Name, '
                        + 'Event_Organizer__r.Email__c, Event_Organizer__r.OwnerId, '
                        + 'Event_Organizer__r.Company__c, Event_Organizer__r.ShortIntro__c, Event_Organizer__r.Picture__c, '
                        + 'Location__r.Name, Location__r.Street__c, Location__r.City__C, '
                        + 'Location__r.Postal_Code__c, Location__r.Country__c, Location__r.State__c, '
                        + 'Name__c, Start_DateTime__c, End_Date_Time__c, Recurring__c, Max_Seats__c, Live__c, '
                        + 'PeopleAttending__c, Remaining_Seats__c, Event_Type__c, Frequency__c, '
                        + 'Location_Verified__c, Status__c, Event_Detail__c '
                        + 'FROM Event__c '
                        + 'WHERE Id = :recordId AND Live__c = true';
            
            eventRecord = Database.query(query);
            
            // If no record is found, throw a friendly error
            if (eventRecord == null || eventRecord.Id == null) {
                throw new AuraHandledException('Event not found or not available.');
            }
        } catch (Exception e) {
            System.debug('Error fetching event details: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve event details. Please contact your administrator.');
        }
        return eventRecord;
    }

    @AuraEnabled(cacheable=true)
    public static List<EventSpeakers__c> fetchSpeakerDetails(String eventId){
        List<EventSpeakers__c> speakers = new List<EventSpeakers__c>();
        try {
            // Query speaker details without enforcing security to ensure guest users can access
            String query = 'SELECT Id, Event__c, Speaker__c, Speaker__r.Name, '
                        + 'Speaker__r.About_Me__c, Speaker__r.Picture__c, '
                        + 'Speaker__r.Company__c '
                        + 'FROM EventSpeakers__c '
                        + 'WHERE Event__c = :eventId';
            
            speakers = Database.query(query);
        } catch (Exception e) {
            System.debug('Error fetching speaker details: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve speaker details. Please contact your administrator.');
        }
        return speakers;
    }
}