public class UserTriggerHandler {
    public static void handleAfterInsert(List<User> newUsers) {
        Set<Id> communityUserIds = new Set<Id>();
        
        try {
            // Get the Customer Community User profile Id
            Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];
            
            // Filter community users
            for (User newUser : newUsers) {
                if (newUser.ProfileId == communityProfile.Id) {
                    communityUserIds.add(newUser.Id);
                }
            }
            
            // Process only if there are community users
            if (!communityUserIds.isEmpty()) {
                // Query full user records for community users
                List<User> communityUsers = [SELECT Id, FirstName, LastName, Email, Title, Phone 
                                           FROM User 
                                           WHERE Id IN :communityUserIds];
                
                List<Attendee__c> attendeesToInsert = new List<Attendee__c>();
                
                // Create Attendee records
                for (User u : communityUsers) {
                    Attendee__c attendee = new Attendee__c();
                    attendee.Name = u.FirstName + ' ' + u.LastName;
                    attendee.Email__c = u.Email;
                    attendee.Phone__c = u.Phone;
                    attendee.Title__c = u.Title;
                    attendee.User__c = u.Id;
                    
                    attendeesToInsert.add(attendee);
                }
                
                // Insert Attendee records
                if (!attendeesToInsert.isEmpty()) {
                    insert attendeesToInsert;
                }
            }
        } catch (Exception e) {
            System.debug('Error in UserTriggerHandler.handleAfterInsert: ' + e.getMessage());
            throw new UserTriggerHandlerException('Failed to process community users: ' + e.getMessage());
        }
    }
    
    public class UserTriggerHandlerException extends Exception {}
}