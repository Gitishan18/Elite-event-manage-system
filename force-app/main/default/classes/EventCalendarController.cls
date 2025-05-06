public with sharing class EventCalendarController {
    @AuraEnabled(cacheable=true)
    public static List<Event__c> getEvents() {
        // Get events for the next 6 months to support month navigation
        Date startDate = Date.today();
        Date endDate = startDate.addMonths(6);
        
        return [SELECT Id, Name__c, Start_DateTime__c, End_Date_Time__c, Event_Detail__c, Location__c
                FROM Event__c
                WHERE Start_DateTime__c >= :startDate AND Start_DateTime__c <= :endDate
                ORDER BY Start_DateTime__c ASC
                LIMIT 1000];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Event__c> getEventsForRange(Date startDate, Date endDate) {
        // More flexible method that allows fetching events for specific date ranges
        return [SELECT Id, Name__c, Start_DateTime__c, End_Date_Time__c, Event_Detail__c, Location__c
                FROM Event__c
                WHERE Start_DateTime__c >= :startDate AND Start_DateTime__c <= :endDate
                ORDER BY Start_DateTime__c ASC
                LIMIT 1000];
    }
}