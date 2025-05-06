trigger EventReminderTrigger on Event__c (after insert, after update) {
    // Schedule event reminders for new or updated events
    EventReminderHandler.scheduleEventReminders(Trigger.new, Trigger.oldMap);
    
    // Handle cancelled events
    if (Trigger.isUpdate) {
        EventCancellationHandler.handleCancelledEvents(Trigger.new, Trigger.oldMap);
    }
}