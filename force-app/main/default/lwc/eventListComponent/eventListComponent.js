import fetchPastEvents from '@salesforce/apex/EventListLWCService.fetchPastEvents';
import fetchUpComingEvents from '@salesforce/apex/EventListLWCService.fetchUpComingEvents';
import EventTitle from '@salesforce/resourceUrl/EventTitle';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LightningElement, track, wire } from 'lwc';

export default class EventListComponent extends NavigationMixin(LightningElement) {
    
    @track upcomingEvnets;
    @track pastEvents;
    @track upcomingError;
    @track pastError;
    @track isSpinner = true;
    @track noUpcomingEvents = false;
    @track noPastEvents = false;

    images = {
        event: EventTitle
    }

    connectedCallback() {
        // Add perspective to the body for 3D effects
        document.body.style.perspective = '1000px';
        
        // Optional: Detect if we should use reduced animations based on user preference
        const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        if (prefersReducedMotion) {
            this.applyReducedMotions();
        }
    }

    // Apply reduced animations for accessibility
    applyReducedMotions() {
        const style = document.createElement('style');
        style.innerText = `
            .floating-section { animation: none !important; }
            .event-card:hover { transform: translateY(-5px) !important; }
            .event-item { animation-duration: 0.2s !important; }
        `;
        document.head.appendChild(style);
    }

    @wire(fetchUpComingEvents)
    wiredUpcomingEventsData({ error, data }) {
        this.isSpinner = true;
        if (data) {
            console.log('Upcoming events received:', data.length);
            this.upcomingEvnets = this.processEventData(data);
            this.noUpcomingEvents = data.length === 0;
            this.upcomingError = undefined;
        } else if (error) {
            console.error('Error fetching upcoming events:', error);
            this.upcomingEvnets = undefined;
            this.upcomingError = this.reduceErrors(error);
            this.noUpcomingEvents = true;
            this.showToast('Error', 'Failed to load upcoming events', 'error');
        }
        this.isSpinner = false;
    }

    @wire(fetchPastEvents)
    wiredPastEventsData({ error, data }) {
        this.isSpinner = true;
        if (data) {
            console.log('Past events received:', data.length);
            this.pastEvents = this.processEventData(data);
            this.noPastEvents = data.length === 0;
            this.pastError = undefined;
        } else if (error) {
            console.error('Past Event Error:', error);
            this.pastError = this.reduceErrors(error);
            this.pastEvents = undefined;
            this.noPastEvents = true;
            this.showToast('Error', 'Failed to load past events', 'error');
        }
        this.isSpinner = false;
    }

    // Process event data to add custom properties for enhanced UI
    processEventData(events) {
        return events.map((event, index) => {
            return {
                ...event,
                animationDelay: `${0.1 * (index % 6)}s`, // Add staggered animation delay
                colorClass: this.getRandomColorClass() // Add random color accent
            };
        });
    }

    // Generate random color classes for variety
    getRandomColorClass() {
        const colors = [
            'primary-accent',
            'success-accent',
            'info-accent',
            'warning-accent'
        ];
        return colors[Math.floor(Math.random() * colors.length)];
    }

    // Helper method to extract error messages
    reduceErrors(error) {
        if (!error) {
            return 'Unknown error';
        }
        
        // UI API read errors
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        
        // Custom apex errors
        else if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        
        // Single string error
        else if (typeof error.body === 'string') {
            return error.body;
        }
        
        // Unknown error shape
        return JSON.stringify(error);
    }

    // Show toast notification
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    handleEventClick = event => {
        try {
            event.preventDefault();
            let selectedEventId = event.detail.eventId;
            
            console.log('Navigating to event detail page for event ID:', selectedEventId);

            // Add visual feedback for click
            const elements = this.template.querySelectorAll('.event-card');
            elements.forEach(elem => {
                if (elem.contains(event.target)) {
                    elem.style.transform = 'scale(0.98)';
                    setTimeout(() => {
                        elem.style.transform = '';
                    }, 150);
                }
            });

            let navigationTarget = {
                type: 'comm__namedPage',
                attributes: {
                    name: "Event_Details__c"
                },
                state: {
                    eventId: selectedEventId,
                    source: 'eventListPage'
                }
            }
            
            this[NavigationMixin.Navigate](navigationTarget);
        } catch (error) {
            console.error('Navigation error:', error);
            this.showToast('Error', 'Failed to navigate to event details', 'error');
        }
    }
}