trigger UserTrigger on User (after insert) {
    // Process only if there are new users
    if (Trigger.isAfter && Trigger.isInsert) {
        System.debug('UserTrigger - Processing after insert event');
        Set<Id> communityUserIds = new Set<Id>();
        
        // Get the Customer Community User profile Id
        Profile communityProfile = [SELECT Id, Name FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];
        System.debug('UserTrigger - Found Community Profile: ' + communityProfile.Name + ' with Id: ' + communityProfile.Id);
        
        // Filter community users
        for (User newUser : Trigger.new) {
            System.debug('UserTrigger - Checking user: ' + newUser.Id + ' with ProfileId: ' + newUser.ProfileId);
            if (newUser.ProfileId == communityProfile.Id) {
                communityUserIds.add(newUser.Id);
                System.debug('UserTrigger - Added community user: ' + newUser.Id);
            }
        }
        
        // Process only if there are community users
        if (!communityUserIds.isEmpty()) {
            // Query full user records for community users
            List<User> communityUsers = [SELECT Id, FirstName, LastName, Email, Title, Phone 
                                       FROM User 
                                       WHERE Id IN :communityUserIds];
            
            List<Attendee__c> attendeesToInsert = new List<Attendee__c>();
            
            System.debug('UserTrigger - Processing ' + communityUsers.size() + ' community users');
            // Create Attendee records
            for (User u : communityUsers) {
                System.debug('UserTrigger - Creating Attendee record for user: ' + u.Id + ' with name: ' + u.FirstName + ' ' + u.LastName);
                Attendee__c attendee = new Attendee__c();
                attendee.Name = u.FirstName + ' ' + u.LastName;
                attendee.Email__c = u.Email;
                attendee.Phone__c = u.Phone;
                attendee.Title__c = u.Title;
                attendee.User__c = u.Id;
                System.debug('UserTrigger - Attendee record created: ' + attendee);
                
                attendeesToInsert.add(attendee);
            }
            
            // Insert Attendee records with error handling
            if (!attendeesToInsert.isEmpty()) {
                try {
                    insert attendeesToInsert;
                } catch (Exception e) {
                    System.debug('Error creating Attendee records: ' + e.getMessage());
                    // You might want to send an email notification or create a custom error log
                    for (User u : communityUsers) {
                        u.addError('Failed to create Attendee record. Please contact system administrator.');
                    }
                }
            }
        }
    }
}