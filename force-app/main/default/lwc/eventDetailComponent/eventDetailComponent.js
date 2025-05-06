import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { api, LightningElement, track, wire } from 'lwc';

import fetchEventDetails from '@salesforce/apex/EventDetailLwcService.fetchEventDetails';
import fetchSpeakerDetails from '@salesforce/apex/EventDetailLwcService.fetchSpeakerDetails';
import isUserRegistered from '@salesforce/apex/EventRegistrationService.isUserRegistered';
import registerForEvent from '@salesforce/apex/EventRegistrationService.registerForEvent';
import Id from '@salesforce/user/Id';

import SPEAKER_IMAGE from '@salesforce/resourceUrl/Speaker';
import ORGANIZER_IMAGE from '@salesforce/resourceUrl/organizer';

export default class EventDetailComponent extends NavigationMixin(LightningElement) {

    /* store the default speaker image */
    images = {
        speaker : SPEAKER_IMAGE,
        organizer : ORGANIZER_IMAGE
    }

    /* variable to get the url parameters */
    @api eventId;
    @api source;
    __currentPageReference;

    /* variable to show the spinner */
    isSpinner = false;

    /* variable to store the event details */
    __speakers;
    __eventDetails;
    __errors;
    __errorMessage;
    __showError = false;

    /* variable to display the location map */
    @track __mapMarkers = [];

    /* variable to show contact modal */ 
    __showContactModal = false;
    userId = Id;
    isRegistered = false;
    
    connectedCallback() {
        // Always fetch event details for all users
        if (this.eventId) {
            this.fetchEventDetailsJS();
            this.fetchSpeakerDetailsJS();
            if (this.userId) {
                this.checkRegistrationStatus();
            }
        }
    }

    @wire(CurrentPageReference)
    getCurrentPageReference(pageReference) {
        this.__currentPageReference = pageReference;
        
        if (pageReference) {
            const eventIdFromParam = this.__currentPageReference.state.eventId;
            const sourceFromParam = this.__currentPageReference.state.source;
            
            // Only update if values are present in params
            if (eventIdFromParam) {
                this.eventId = eventIdFromParam;
            }
            
            if (sourceFromParam) {
                this.source = sourceFromParam;
            }
            
            // Fetch event details when page reference is available
            if (this.eventId) {
                this.fetchEventDetailsJS();
                this.fetchSpeakerDetailsJS();
                if (this.userId) {
                    this.checkRegistrationStatus();
                }
            }
        }
    }

    checkRegistrationStatus() {
        isUserRegistered({ eventId: this.eventId })
            .then(result => {
                this.isRegistered = result;
            })
            .catch(error => {
                console.error('Error checking registration status:', error);
            });
    }

    handleRegistration() {
        if (!this.userId) {
            // Redirect to login page
            const loginUrl = '/login';
            this[NavigationMixin.Navigate]({ 
                type: 'standard__webPage',
                attributes: {
                    url: loginUrl
                }
            });
            return;
        }

        this.isSpinner = true;
        registerForEvent({ eventId: this.eventId })
            .then(result => {
                this.isRegistered = result === 'registered';
                // Refresh event details to update remaining seats
                this.fetchEventDetailsJS();
            })
            .catch(error => {
                this.__showError = true;
                this.__errorMessage = error.body.message;
            })
            .finally(() => {
                this.isSpinner = false;
            });
    }

    get registerButtonLabel() {
        return this.isRegistered ? 'Unregister' : 'Register';
    }

    fetchEventDetailsJS() {
        if (!this.eventId) return;
        
        this.isSpinner = true;
        this.__showError = false;
        
        fetchEventDetails({ 
            recordId: this.eventId 
        })
        .then(result => {
            if (result) {
                this.__eventDetails = result;

                if (this.__eventDetails && this.__eventDetails.Location__c) {
                    this.__mapMarkers = [{
                        location: {
                            City: this.__eventDetails.Location__r.City__c,
                            Country: this.__eventDetails.Location__r.Country__c,
                            PostalCode: this.__eventDetails.Location__r.Postal_Code__c,
                            State: this.__eventDetails.Location__r.State__c,
                            Street: this.__eventDetails.Location__r.Street__c
                        },
                        title: this.__eventDetails.Name__c,
                        description: 'This is the landmark for the location'
                    }];
                }
            } else {
                this.__showError = true;
                this.__errorMessage = 'Event details not available.';
            }
        })
        .catch(error => {
            console.error('Error fetching event details:', error);
            this.__showError = true;
            this.__errorMessage = error.body ? error.body.message : 'Unable to load event details. Please try again later.';
        })
        .finally(() => {
            this.isSpinner = false;
        });
    }

    fetchSpeakerDetailsJS() {
        if (!this.eventId) return;
        
        this.isSpinner = true;
        fetchSpeakerDetails({ 
            eventId: this.eventId 
        })
        .then(result => {
            this.__speakers = result;
        })
        .catch(error => {
            console.error('Error fetching speaker details:', error);
            // We don't show an error for speakers as it's not critical
        })
        .finally(() => {
            this.isSpinner = false;
        });
    }

    /* Contact us functionality */
    handleContactCancel() {
        this.__showContactModal = false;
    }

    handleContactUsSuccess(event) {
        event.preventDefault();
        this.__showContactModal = false;
    }

    handleContactUs() {
        this.__showContactModal = true;
    }

    get totalHoursText() {
        if (!this.__eventDetails || !this.__eventDetails.Start_DateTime__c || !this.__eventDetails.End_Date_Time__c) {
            return '';
        }
        const start = new Date(this.__eventDetails.Start_DateTime__c);
        const end = new Date(this.__eventDetails.End_Date_Time__c);
        if (
            start.getFullYear() === end.getFullYear() &&
            start.getMonth() === end.getMonth() &&
            start.getDate() === end.getDate()
        ) {
            const diffMs = end - start;
            if (diffMs > 0) {
                const diffMins = diffMs / (1000 * 60); // convert to minutes
                if (diffMins >= 60) {
                    const diffHrs = diffMins / 60;
                    return `Total Duration: ${diffHrs.toFixed(2)} hr`;
                } else {
                    return `Total Duration: ${Math.round(diffMins)} min`;
                }
            }
        }
        return '';
    }
}