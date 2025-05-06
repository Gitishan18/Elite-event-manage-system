public class EventReminderHandler implements Schedulable {
    
    private static final Integer REMINDER_MINUTES = 30;
    private Id eventId;
    
    // Constructor for schedulable implementation
    public EventReminderHandler(Id eventId) {
        this.eventId = eventId;
    }
    
    // Default constructor for direct class calls
    public EventReminderHandler() {
        this.eventId = null;
    }
    
    // Main method called from trigger to schedule reminders
    public static void scheduleEventReminders(List<Event__c> newEvents, Map<Id, Event__c> oldEventsMap) {
        List<Event__c> eventsToProcess = new List<Event__c>();
        
        for (Event__c evt : newEvents) {
            // Check if this is a new event or if start date has changed
            if (oldEventsMap == null || 
                (evt.Start_DateTime__c != oldEventsMap.get(evt.Id).Start_DateTime__c)) {
                
                // Only schedule for future events
                if (evt.Start_DateTime__c > System.now()) {
                    eventsToProcess.add(evt);
                }
            }
        }
        
        if (!eventsToProcess.isEmpty()) {
            // Schedule reminders for each event
            for (Event__c evt : eventsToProcess) {
                // Calculate reminder time (30 minutes before event)
                Datetime reminderTime = evt.Start_DateTime__c.addMinutes(-REMINDER_MINUTES);
                
                // Only schedule if the reminder time is in the future
                if (reminderTime > System.now()) {
                    String jobName = 'EventReminder_' + evt.Id + '_' + System.now().getTime();
                    String cronExp = generateCronExpression(reminderTime);
                    
                    try {
                        System.schedule(jobName, cronExp, new EventReminderHandler(evt.Id));
                        System.debug('Scheduled reminder for event: ' + evt.Id + ' at ' + reminderTime);
                    } catch (Exception e) {
                        System.debug('Error scheduling reminder: ' + e.getMessage());
                        // Log error with transaction handler if available
                        try {
                            TransactionLogHandler.doHandleException(e, 'EventReminderHandler');
                        } catch (Exception ex) {
                            // If transaction logger is not available, just debug the error
                            System.debug('Error logging exception: ' + ex.getMessage());
                        }
                    }
                }
            }
        }
    }
    
    // Generate CRON expression for scheduled time
    private static String generateCronExpression(Datetime dt) {
        return dt.second() + ' ' + dt.minute() + ' ' + dt.hour() + ' ' + 
               dt.day() + ' ' + dt.month() + ' ? ' + dt.year();
    }
    
    // Execute method for the Schedulable interface
    public void execute(SchedulableContext sc) {
        try {
            // Send reminder emails
            sendReminderEmails();
        } catch (Exception e) {
            System.debug('Error in execute method: ' + e.getMessage());
            // Log error with transaction handler if available
            try {
                TransactionLogHandler.doHandleException(e, 'EventReminderHandler');
            } catch (Exception ex) {
                // If transaction logger is not available, just debug the error
                System.debug('Error logging exception: ' + ex.getMessage());
            }
        } finally {
            // Clean up - delete the scheduled job
            System.abortJob(sc.getTriggerId());
        }
    }
    
    // Send reminder emails to all attendees of an event
    private void sendReminderEmails() {
        if (eventId == null) return;
        
        // Query for event details
        Event__c evt = [SELECT Id, Name__c, Start_DateTime__c, Event_Organizer__c, Event_Organizer__r.Name,
                        Location__c, Location__r.Name, Location__r.City__c, Location__r.State__c, 
                        Location__r.Country__c, Location__r.Postal_Code__c, Location__r.Street__c
                        FROM Event__c WHERE Id = :eventId LIMIT 1];
        
        // Query for all attendees of this event
        List<Attendee__c> attendees = new List<Attendee__c>();
        
        // First get all Event_Attendee junction records for this event
        List<Event_Attendee__c> eventAttendees = [SELECT Id, Attendee__c 
                                                FROM Event_Attendee__c 
                                                WHERE Event__c = :eventId];
        
        // Create a set of attendee IDs
        Set<Id> attendeeIds = new Set<Id>();
        for (Event_Attendee__c ea : eventAttendees) {
            attendeeIds.add(ea.Attendee__c);
        }
        
        // Query for attendee details
        Map<Id, Attendee__c> attendeeMap = new Map<Id, Attendee__c>(
            [SELECT Id, Name, Email__c FROM Attendee__c WHERE Id IN :attendeeIds]
        );
        
        // Create email messages for each attendee
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        
        for (Event_Attendee__c ea : eventAttendees) {
            Attendee__c att = attendeeMap.get(ea.Attendee__c);
            
            // Skip if no attendee found or no email address
            if (att == null || String.isBlank(att.Email__c)) continue;
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            
            mail.setSubject('Reminder: ' + evt.Name__c + ' starts in 30 minutes');
            
            List<String> toAddress = new List<String>();
            toAddress.add(att.Email__c);
            mail.setToAddresses(toAddress);
            
            if (evt.Event_Organizer__c != null && evt.Event_Organizer__r.Name != null) {
                mail.setSenderDisplayName(evt.Event_Organizer__r.Name);
            }
            
            // Create Google Maps link for the location
            String location = 'https://www.google.com/maps/place/' + 
                encodeUrl(evt.Location__r.Street__c + ' ' + 
                          evt.Location__r.City__c + ' ' + 
                          evt.Location__r.State__c + ' ' + 
                          evt.Location__r.Country__c + ' ' + 
                          evt.Location__r.Postal_Code__c);
            
            String hrefForLocation = '<a href="' + location + '"' + 'target="_blank">Here</a>';
            
            // Format the event time
            String formattedDateTime = evt.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a');
            
            // Build email body
            String emailBody = 'Dear ' + att.Name + ',<br/><br/>' +
                'This is a reminder that the event "' + evt.Name__c + '" starts in 30 minutes at ' + 
                formattedDateTime + '.<br/><br/>' +
                'The event will be held at ' + evt.Location__r.Name + '.<br/>' +
                'Find the Google Map Location for the Event ' + hrefForLocation + '.<br/><br/>' +
                'We look forward to seeing you there!<br/><br/>' +
                'Thanks,<br/>' + evt.Event_Organizer__r.Name;
            
            mail.setHtmlBody(emailBody);
            emailList.add(mail);
        }
        
        // Send emails if any were created
        if (!emailList.isEmpty()) {
            try {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailList, false);
                
                for (Messaging.SendEmailResult result : results) {
                    if (!result.isSuccess()) {
                        List<Messaging.SendEmailError> errors = result.getErrors();
                        // Log errors
                        try {
                            TransactionLogHandler.doHandleExceptionWithError(JSON.serialize(errors), 'EventReminderHandler');
                        } catch (Exception e) {
                            System.debug('Error logging email failure: ' + e.getMessage());
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('Error sending emails: ' + e.getMessage());
                // Log error with transaction handler if available
                try {
                    TransactionLogHandler.doHandleException(e, 'EventReminderHandler');
                } catch (Exception ex) {
                    System.debug('Error logging exception: ' + ex.getMessage());
                }
            }
        }
    }
    
    // Helper method to URL encode a string
    private static String encodeUrl(String url) {
        if (url == null) return '';
        
        return EncodingUtil.urlEncode(url, 'UTF-8')
            .replace('+', '%20')
            .replace('%28', '(')
            .replace('%29', ')')
            .replace('%2C', ',')
            .replace('%21', '!')
            .replace('%27', '\'')
            .replace('%3A', ':')
            .replace('%2F', '/');
    }
}