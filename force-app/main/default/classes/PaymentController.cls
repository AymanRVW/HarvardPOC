public without sharing class PaymentController {
    @AuraEnabled
    public static String processPayment(Map<String, String> cardData) {
        try {

            // todo pull ordersummary from course connection

            // String courseConnectionId = 'a0TD1000001HMScMAO';
            String courseConnectionId = cardData.get('courseConnectionId');
            System.debug('courseConnectionId: ' + courseConnectionId);

            List<Course_Enrollment__c> enrollment = [SELECT Id, Contact__r.AccountId, Order_Summary__c 
                                                    FROM Course_Enrollment__c
                                                    WHERE Id = :courseConnectionId
                                                    LIMIT 1];


            // Authorize call
            ConnectApi.AuthorizationRequest authRequest = new ConnectApi.AuthorizationRequest();
            authRequest.accountId = enrollment[0].Contact__r.AccountId;
            authRequest.amount = Double.valueOf(cardData.get('amount'));
            authRequest.currencyIsoCode = 'USD';
            authRequest.effectiveDate = date.today();
            //query the payment gateway via CYBERSOURCE_CREDIT external ref field and get back the id
            authRequest.paymentGatewayId = [SELECT Id from PaymentGateway where ExternalReference = 'CYBERSOURCE_CREDIT' LIMIT 1].Id;
            System.debug('authRequest.paymentGatewayId: ' + authRequest.paymentGatewayId);
            
            ConnectApi.CardPaymentMethodRequest cardPaymentMethod = new ConnectApi.CardPaymentMethodRequest();
            cardPaymentMethod.accountId = authRequest.accountId;
            // hard coding for now
            cardPaymentMethod.cardCategory = ConnectApi.CardCategory.CreditCard;
            cardPaymentMethod.cardHolderFirstName = cardData.get('firstName');
            cardPaymentMethod.cardHolderLastName = cardData.get('lastName');
            cardPaymentMethod.cardHolderName = cardPaymentMethod.cardHolderFirstName + ' ' + cardPaymentMethod.cardHolderLastName;
            cardPaymentMethod.cardNumber = cardData.get('cardNumber');
            // hard coding for now
            cardPaymentMethod.cardType = 'Visa';
            cardPaymentMethod.cvv = cardData.get('cvv');
            cardPaymentMethod.email = cardData.get('email');
            cardPaymentMethod.expiryMonth = Integer.valueOf(cardData.get('expirationMonth'));
            cardPaymentMethod.expiryYear = Integer.valueOf(cardData.get('expirationYear'));

            System.debug('CardPaymentMethod: ' + cardPaymentMethod);

            // PaymentGroupRequest
            ConnectApi.PaymentGroupRequest paymentGroupRequest = new ConnectApi.PaymentGroupRequest();
            paymentGroupRequest.createPaymentGroup = true;
            paymentGroupRequest.sourceObjectId = '801D2000001iQ5EIAU';
            authRequest.paymentGroup = paymentGroupRequest;

            // AuthApiPayment​MethodRequest
            ConnectApi.AuthApiPaymentMethodRequest paymentMethodRequest = new ConnectApi.AuthApiPaymentMethodRequest();
            paymentMethodRequest.cardPaymentMethod = cardPaymentMethod;

            authRequest.paymentMethod = paymentMethodRequest;

            System.debug('authRequest: ' + authRequest);
            ConnectApi.AuthorizationResponse authResponse = ConnectApi.Payments.authorize(authRequest);
            System.debug('authResponse: ' + authResponse);



            //need to pull these from the authresponse 
            //paymentAuthorizationNumber form the response - pull the ID
            String paymentAuthorizationNumber = authResponse.paymentAuthorization.id;
            // String paymentAuthorizationNumber = authResponse.paymentAuthorizationNumber;
            System.debug('paymentAuthorizationNumber: ' + paymentAuthorizationNumber);



            //to link courseConnection to orderSummary
            // PaymentLineInvoice paymentLineInvoice = [SELECT Id, Course_Enrollment__c, Invoice.id
            //                                         FROM PaymentLineInvoice 
            //                                         WHERE Invoice__r.OrderSummary__r.Id = :courseConnectionId LIMIT 1];

            String orderSummaryId = enrollment[0].Order_Summary__c;
            System.debug('orderSummaryId: ' + orderSummaryId);

            //


            // String orderSummaryId = '1OsD20000004KskKAE';
            //make this call ConnectApi.CreateOrderPaymentSummaryInputRepresentation - this links the payment auth to the order summary


            // CreateOrderPaymentSummary call
            ConnectApi.CreateOrderPaymentSummaryInputRepresentation orderPaymentSummaryRequest = new ConnectApi.CreateOrderPaymentSummaryInputRepresentation();
            orderPaymentSummaryRequest.orderSummaryId = orderSummaryId;
            orderPaymentSummaryRequest.paymentAuthorizationId = paymentAuthorizationNumber;
            ConnectApi.CreateOrderPaymentSummaryOutputRepresentation orderPaymentSummaryResponse = ConnectApi.OrderPaymentSummary.createOrderPaymentSummary(orderPaymentSummaryRequest);
            System.debug('orderPaymentSummaryResponse: ' + orderPaymentSummaryResponse);


            //calling future method to capture payment
            process(String.valueOf(authRequest.amount), authResponse.paymentGroup.id, paymentAuthorizationNumber, orderPaymentSummaryResponse.orderPaymentSummaryId);

            

            //future method down below - leave commented out for now
            // //call ConnectApi.CaptureRequest
            // ConnectApi.CaptureRequest captureRequest = new ConnectApi.CaptureRequest();
            // captureRequest.amount = authRequest.amount;
            // System.debug('captureRequest.amount: ' + captureRequest.amount);
            
            // ConnectApi.PaymentGroupRequest paymentGroup = new ConnectApi.PaymentGroupRequest();
            // paymentGroup.id = orderPaymentSummaryResponse.orderPaymentSummaryId;
            // System.debug('paymentGroupID: ' + paymentGroup.id);
            // captureRequest.paymentGroup = paymentGroup;
            // System.debug('captureRequest: ' + captureRequest);
            // ConnectApi.CaptureResponse captureResponse = ConnectApi.Payments.capture(captureRequest, paymentAuthorizationNumber);
            // System.debug('captureResponse: ' + captureResponse);
            // // System.debug('captureResponse.paymentCapture.id: ' + captureResponse.paymentGroup.id);
            

            return 'Success?';
        } catch (Exception e) {
            System.debug('Error in processPayment: ' + e.getMessage());
            throw new AuraHandledException('Payment processing failed: ' + e.getMessage());
        }
    }


    @future
    public static void process(String amount, String id, String paymentAuthorizationNumber, String orderPaymentSummaryId){
        try{
        System.debug('entering process method');
        System.debug('paymentAuthorizationNumber: ' + paymentAuthorizationNumber);

        // Capture call
        ConnectApi.CaptureRequest captureRequest = new ConnectApi.CaptureRequest();
        captureRequest.amount = Double.valueOf(amount);
        
        ConnectApi.PaymentGroupRequest paymentGroup = new ConnectApi.PaymentGroupRequest();
        paymentGroup.id = id;
        System.debug('paymentGroupID: ' + paymentGroup.id);
        captureRequest.paymentGroup = paymentGroup;
        System.debug('captureRequest: ' + captureRequest);
        //query payment authorization and get the id from the paymentAuthorizationNumber

        // String paymentAuthorizationId = [SELECT Id from PaymentAuthorization where PaymentAuthorizationNumber = :paymentAuthorizationNumber LIMIT 1].id;
        // System.debug('paymentAuthorization: ' + paymentAuthorizationId);
        ConnectApi.CaptureResponse captureResponse = ConnectApi.Payments.capture(captureRequest, paymentAuthorizationNumber);
        System.debug('captureResponse: ' + captureResponse);

        update new Payment(id=captureResponse.payment.id, orderPaymentSummaryId=orderPaymentSummaryId);        // System.debug('captureResponse.paymentCapture.id: ' + captureResponse.paymentGroup.id);
        System.debug('YAAAYYYYYY');
        }catch(Exception e){
            System.debug('NOOOOO');
            System.debug('Error in processPayment: ' + e.getMessage());
            throw new AuraHandledException('Payment processing failed: ' + e.getMessage());
        }
 
    }
}
