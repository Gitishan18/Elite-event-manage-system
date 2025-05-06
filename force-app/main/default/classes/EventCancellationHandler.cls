public class EventCancellationHandler {
    
    // Method to check for cancelled events and send notifications
    public static void handleCancelledEvents(List<Event__c> newEvents, Map<Id, Event__c> oldEventsMap) {
        List<Event__c> cancelledEvents = new List<Event__c>();
        
        // Identify events that have been cancelled
        for (Event__c evt : newEvents) {
            // Check if status changed to 'Cancelled'
            if (oldEventsMap != null && 
                evt.Status__c == 'Cancelled' && 
                oldEventsMap.get(evt.Id).Status__c != 'Cancelled') {
                
                cancelledEvents.add(evt);
            }
        }
        
        // If we have cancelled events, send notifications
        if (!cancelledEvents.isEmpty()) {
            sendCancellationEmails(cancelledEvents);
        }
    }
    
    // Send cancellation emails to all attendees of cancelled events
    private static void sendCancellationEmails(List<Event__c> cancelledEvents) {
        // Get all event IDs
        Set<Id> eventIds = new Set<Id>();
        for (Event__c evt : cancelledEvents) {
            eventIds.add(evt.Id);
        }
        
        // Query for all event details needed for the emails
        Map<Id, Event__c> eventMap = new Map<Id, Event__c>([
            SELECT Id, Name__c, Start_DateTime__c, Event_Organizer__c, Event_Organizer__r.Name,
                   Location__c, Location__r.Name, Location__r.City__c, Location__r.State__c,
                   Location__r.Country__c, Location__r.Postal_Code__c, Location__r.Street__c
            FROM Event__c 
            WHERE Id IN :eventIds
        ]);
        
        // Query for all Event_Attendee junction records for cancelled events
        List<Event_Attendee__c> eventAttendees = [
            SELECT Id, Event__c, Attendee__c 
            FROM Event_Attendee__c 
            WHERE Event__c IN :eventIds
        ];
        
        // Group attendees by event
        Map<Id, List<Id>> eventToAttendeesMap = new Map<Id, List<Id>>();
        Set<Id> attendeeIds = new Set<Id>();
        
        for (Event_Attendee__c ea : eventAttendees) {
            // Add to attendee IDs set
            attendeeIds.add(ea.Attendee__c);
            
            // Group by event
            if (!eventToAttendeesMap.containsKey(ea.Event__c)) {
                eventToAttendeesMap.put(ea.Event__c, new List<Id>());
            }
            eventToAttendeesMap.get(ea.Event__c).add(ea.Attendee__c);
        }
        
        // Query attendee details
        Map<Id, Attendee__c> attendeeMap = new Map<Id, Attendee__c>([
            SELECT Id, Name, Email__c 
            FROM Attendee__c 
            WHERE Id IN :attendeeIds
        ]);
        
        // Create and send emails
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        
        for (Event__c evt : cancelledEvents) {
            // Skip if no attendees for this event
            if (!eventToAttendeesMap.containsKey(evt.Id)) continue;
            
            // Get the full event details
            Event__c fullEventDetails = eventMap.get(evt.Id);
            
            // Get attendee IDs for this event
            List<Id> eventAttendeeIds = eventToAttendeesMap.get(evt.Id);
            
            // Create email for each attendee
            for (Id attendeeId : eventAttendeeIds) {
                Attendee__c att = attendeeMap.get(attendeeId);
                
                // Skip if no attendee found or no email
                if (att == null || String.isBlank(att.Email__c)) continue;
                
                // Create email message
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                
                // Set email details
                mail.setSubject('IMPORTANT: Event Cancellation - ' + fullEventDetails.Name__c);
                
                List<String> toAddress = new List<String>();
                toAddress.add(att.Email__c);
                mail.setToAddresses(toAddress);
                
                // Set sender display name if organizer exists
                if (fullEventDetails.Event_Organizer__c != null && 
                    fullEventDetails.Event_Organizer__r.Name != null) {
                    mail.setSenderDisplayName(fullEventDetails.Event_Organizer__r.Name);
                }
                
                // Format date for display
                String formattedDateTime = fullEventDetails.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a');
                
                // Build email body
                String emailBody = 'Dear ' + att.Name + ',<br/><br/>' +
                    'We regret to inform you that the event <strong>"' + fullEventDetails.Name__c + 
                    '"</strong> scheduled for ' + formattedDateTime + ' has been <strong>cancelled</strong>.<br/><br/>';
                
              
                
                // Add apology and contact info
                emailBody += '<br/>We apologize for any inconvenience this may cause. ';
                
                
                
                // Add contact information
                emailBody += 'If you have any questions or concerns, please don\'t hesitate to contact us.<br/><br/>';
                
                // Add alternative events info if applicable
                emailBody += 'We hope to see you at our future events.<br/><br/>';
                
                // Closing
                emailBody += 'Sincerely,<br/>' + 
                    (fullEventDetails.Event_Organizer__r.Name != null ? 
                     fullEventDetails.Event_Organizer__r.Name : 'The Events Team');
                
                mail.setHtmlBody(emailBody);
                emailList.add(mail);
            }
        }
        
        // Send all emails
        if (!emailList.isEmpty()) {
            try {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailList, false);
                
                // Process results
                for (Messaging.SendEmailResult result : results) {
                    if (!result.isSuccess()) {
                        List<Messaging.SendEmailError> errors = result.getErrors();
                        // Log errors
                        try {
                            TransactionLogHandler.doHandleExceptionWithError(JSON.serialize(errors), 'EventCancellationHandler');
                        } catch (Exception e) {
                            System.debug('Error logging email failure: ' + e.getMessage());
                        }
                    }
                }
            } catch (Exception e) {
                // Log the exception
                System.debug('Error sending cancellation emails: ' + e.getMessage());
                try {
                    TransactionLogHandler.doHandleException(e, 'EventCancellationHandler');
                } catch (Exception ex) {
                    System.debug('Error logging exception: ' + ex.getMessage());
                }
            }
        }
    }
}