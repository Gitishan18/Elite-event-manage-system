public without sharing class EventRegistrationService {
    @AuraEnabled
    public static String registerForEvent(String eventId) {
        try {
            // Check if eventId is valid
            List<Event__c> events = [SELECT Id, Remaining_Seats__c 
                                    FROM Event__c 
                                    WHERE Id = :eventId];
                                    
            if (events.isEmpty()) {
                throw new AuraHandledException('Event not found or you do not have access to this event.');
            }
            
            Event__c event = events[0];
            
            // Get current user
            User currentUser = [SELECT Id, FirstName, LastName, Email, Title, Phone 
                              FROM User 
                              WHERE Id = :UserInfo.getUserId()];

            // Check if user is already registered
            List<Event_Attendee__c> existingRegistrations = [
                SELECT Id 
                FROM Event_Attendee__c 
                WHERE Event__c = :eventId
                    AND Attendee__c IN (
                        SELECT Id 
                        FROM Attendee__c 
                        WHERE User__c = :currentUser.Id
                    )
            ];

            if (!existingRegistrations.isEmpty()) {
                // User is already registered, unregister them
                delete existingRegistrations;
                return 'unregistered';
            } else {
                // Check if event is full
                if (event.Remaining_Seats__c <= 0) {
                    throw new AuraHandledException('Sorry, this event is full.');
                }

                // Get or create attendee record
                List<Attendee__c> existingAttendees = [
                    SELECT Id 
                    FROM Attendee__c 
                    WHERE User__c = :currentUser.Id 
                    LIMIT 1
                ];
                
                Attendee__c attendee;
                if (!existingAttendees.isEmpty()) {
                    attendee = existingAttendees[0];
                } else {
                    attendee = new Attendee__c();
                    attendee.Name = currentUser.FirstName + ' ' + currentUser.LastName;
                    attendee.Email__c = currentUser.Email;
                    attendee.Phone__c = currentUser.Phone;
                    attendee.Title__c = currentUser.Title;
                    attendee.User__c = currentUser.Id;
                    insert attendee;
                }

                // Create Event_Attendee__c record
                Event_Attendee__c eventAttendee = new Event_Attendee__c();
                eventAttendee.Event__c = eventId;
                eventAttendee.Attendee__c = attendee.Id;
                insert eventAttendee;

                return 'registered';
            }
        } catch (Exception e) {
            System.debug('Error in registerForEvent: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean isUserRegistered(String eventId) {
        try {
            // Check if user is logged in
            if (UserInfo.getUserId() == null) {
                return false;
            }
            
            // Check if user is registered for this event
            List<Event_Attendee__c> registrations = [
                SELECT Id 
                FROM Event_Attendee__c 
                WHERE Event__c = :eventId
                    AND Attendee__c IN (
                        SELECT Id 
                        FROM Attendee__c 
                        WHERE User__c = :UserInfo.getUserId()
                    )
                LIMIT 1
            ];
            
            return !registrations.isEmpty();
        } catch (Exception e) {
            System.debug('Error in isUserRegistered: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
}