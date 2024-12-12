import { LightningElement, track } from 'lwc';
import processPayment from "@salesforce/apex/PaymentController.processPayment";

export default class PaymentAuthorization extends LightningElement {
    @track isLoading = false;
    @track cardDetails = {
        courseConnectionId: null,
        amount: null,
        cardNumber: null,
        expirationMonth: null,
        expirationYear: null,
        cvv: null,
        email: null,
        firstName: null,
        lastName: null
    };
   
    handleInputChange(event) {
        const { name, value } = event.target;
        this.cardDetails[name] = value;
    }

    async handleClick() {
        this.isLoading = true; // Show spinner
        try {
            console.log('cardData');
            console.log(this.cardDetails.amount + ' Amount');
            console.log(this.cardDetails.expirationMonth + ' Expiration Month');
            console.log(JSON.stringify(this.cardDetails));
            console.log('after logging object');
            const response = await processPayment({ cardData: this.cardDetails });
            console.log('Payment Response:', response);
            alert('Payment Successful!');
        } catch (error) {
            console.error('Error processing payment:', error);
            alert('Payment Failed.');
        } finally {
            this.isLoading = false; 
            this.clearForm(); 
        }
    }

    clearForm() {
        console.log('Cancel clicked');
        // Reset the cardDetails object
        this.cardDetails = {
            courseConnectionId: '',
            amount: '',
            cardNumber: '',
            expirationMonth: '',
            expirationYear: '',
            cvv: '',
            email: '',
            firstName: '',
            lastName: '',
        };
    }

}
