import getEvents from '@salesforce/apex/EventCalendarController.getEvents';
import { NavigationMixin } from 'lightning/navigation';
import { LightningElement, track, wire } from 'lwc';

export default class EventCalendarComponent extends NavigationMixin(LightningElement) {
    @track selectedDate;
    @track selectedDateEvents = [];
    @track allEvents = [];
    @track formattedSelectedDate;
    @track error;
    @track calendarDays = [];
    @track currentMonth;
    @track currentYear;
    @track currentMonthName;

    monthNames = [
        'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
        'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];

    @wire(getEvents)
    wiredEvents({ error, data }) {
        if (data) {
            this.allEvents = data;
            this.error = undefined;
            this.generateCalendar();
            if (this.selectedDate) {
                this.updateSelectedDateEvents();
            }
        } else if (error) {
            this.error = error;
            this.allEvents = [];
            console.error('Error fetching events:', error);
        }
    }

    connectedCallback() {
        const today = new Date();
        this.currentMonth = today.getMonth();
        this.currentYear = today.getFullYear();
        this.updateCurrentMonthName();
        this.selectedDate = this.formatDate(today);
        
        const options = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
        this.formattedSelectedDate = today.toLocaleDateString(undefined, options);
        
        this.generateCalendar();
    }

    updateCurrentMonthName() {
        this.currentMonthName = this.monthNames[this.currentMonth];
    }

    handlePreviousMonth() {
        this.currentMonth--;
        if (this.currentMonth < 0) {
            this.currentMonth = 11;
            this.currentYear--;
        }
        this.updateCurrentMonthName();
        this.generateCalendar();
    }

    handleNextMonth() {
        this.currentMonth++;
        if (this.currentMonth > 11) {
            this.currentMonth = 0;
            this.currentYear++;
        }
        this.updateCurrentMonthName();
        this.generateCalendar();
    }

    handleCurrentMonth() {
        const today = new Date();
        this.currentMonth = today.getMonth();
        this.currentYear = today.getFullYear();
        this.updateCurrentMonthName();
        this.selectedDate = this.formatDate(today);
        
        const options = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
        this.formattedSelectedDate = today.toLocaleDateString(undefined, options);
        
        this.generateCalendar();
        this.updateSelectedDateEvents();
    }

    updateSelectedDateEvents() {
        if (!this.selectedDate || !this.allEvents.length) {
            this.selectedDateEvents = [];
            return;
        }

        // Use start of day and end of day for comparison
        const selectedDateObj = new Date(this.selectedDate);
        const startOfDay = new Date(selectedDateObj.getFullYear(), selectedDateObj.getMonth(), selectedDateObj.getDate(), 0, 0, 0);
        const endOfDay = new Date(selectedDateObj.getFullYear(), selectedDateObj.getMonth(), selectedDateObj.getDate(), 23, 59, 59);
        
        this.selectedDateEvents = this.allEvents.filter(event => {
            const eventStartDate = new Date(event.Start_DateTime__c);
            return eventStartDate >= startOfDay && eventStartDate <= endOfDay;
        });
    }

    handleDayClick(event) {
        const dateStr = event.currentTarget.dataset.date;
        if (!dateStr) return; // Skip empty cells
        
        const clickedDate = new Date(dateStr);
        
        // Ensure the date is valid
        if (isNaN(clickedDate.getTime())) {
            console.error('Invalid date clicked:', dateStr);
            return;
        }
        
        // Format the date for selection and display
        this.selectedDate = this.formatDate(clickedDate);
        
        // Format date for display
        const options = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
        this.formattedSelectedDate = clickedDate.toLocaleDateString(undefined, options);
        
        // Update events and calendar
        this.updateSelectedDateEvents();
        this.generateCalendar();
    }

    formatDate(date) {
        const d = new Date(date);
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    generateCalendar() {
        const days = [];
        const month = this.currentMonth;
        const year = this.currentYear;
        const firstDay = new Date(year, month, 1);
        const lastDay = new Date(year, month + 1, 0);
        
        // Adjust to have Monday as the first day of the week (1-based, not 0-based)
        // Sunday is 0, we need to convert it to 6 to put it at the end
        let startDay = firstDay.getDay() - 1;
        if (startDay === -1) startDay = 6; // If it's Sunday (0), convert to 6
        
        const totalDays = lastDay.getDate();
        const today = new Date();
        const todayFormatted = this.formatDate(today);
        
        // Fill blanks for days before the 1st
        for (let i = 0; i < startDay; i++) {
            days.push({ 
                dayNumber: '', 
                date: '', 
                isToday: false, 
                isSelected: false, 
                hasEvent: false, 
                eventNames: [],
                isWeekend: false
            });
        }
        
        for (let d = 1; d <= totalDays; d++) {
            const dateObj = new Date(year, month, d);
            const dateStr = this.formatDate(dateObj);
            const isToday = todayFormatted === dateStr;
            const isSelected = this.selectedDate === dateStr;
            // With Monday as the first day, weekend is now 5 (Sat) and 6 (Sun)
            const dayOfWeek = dateObj.getDay();
            const isWeekend = dayOfWeek === 0 || dayOfWeek === 6; // 0 is Sunday, 6 is Saturday
            
            // Check events for this day
            const startOfDay = new Date(year, month, d, 0, 0, 0);
            const endOfDay = new Date(year, month, d, 23, 59, 59);
            
            const eventsForDay = this.allEvents.filter(ev => {
                const eventStartDate = new Date(ev.Start_DateTime__c);
                return eventStartDate >= startOfDay && eventStartDate <= endOfDay;
            });
            
            // Prepare event information
            const eventCount = eventsForDay.length;
            const displayLimit = 1; // Show max 1 event per day (to avoid cell expansion)
            const eventsToShow = eventsForDay.slice(0, displayLimit);
            const hasMoreEvents = eventCount > displayLimit;
            const moreEventsCount = eventCount - displayLimit;
            
            days.push({
                dayNumber: d,
                date: dateStr,
                isToday,
                isSelected,
                isWeekend,
                hasEvent: eventCount > 0,
                eventNames: eventsToShow.map(ev => ev.Name__c),
                hasMoreEvents,
                moreEventsCount
            });
        }
        
        this.calendarDays = days;
    }

    handleEventClick(event) {
        const selectedEventId = event.currentTarget.dataset.eventId;
        
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: "Event_Details__c"
            },
            state: {
                eventId: selectedEventId,
                source: 'eventListPage'
            }
        });
    }
}