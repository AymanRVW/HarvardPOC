/**
 * @description       :
 * @author            : ahmed@redvanworkshop.com
 * @group             :
 * @last modified on  : 03-16-2022
 * @last modified by  : nicholas@redvanworkshop.com
 **/
//**
//* @description  Abstract class for payment gateway adapters
//**

global abstract class AbstractAsyncPaymentGatewayAdapter implements CommercePayments.PaymentGatewayAdapter, CommercePayments.PaymentGatewayAsyncAdapter {
    @namespaceAccessible
    protected CommercePayments.RequestType request_type;

    @namespaceAccessible
    protected CommercePayments.CaptureRequest payment_capture_request;

    @namespaceAccessible
    protected CommercePayments.ReferencedRefundRequest payment_refund_request;
    
    @namespaceAccessible
    protected CommercePayments.AuthorizationRequest payment_authorize_request;

    @namespaceAccessible
    protected PaymentAuthorization payment_authorization;

    @namespaceAccessible
    protected Payment m_payment;

    @namespaceAccessible
    public final static String DEFAULT_CURRENCY_CODE = 'USD';

    /************************************************************************/
    /***** Abstract Methods for all child payment adapters to implement *****/
    /************************************************************************/

    //**
    //* @description Defines the capture request. Child classes need to implement this method to handle the request for the payment gateway
    //* @return  HttpRequest - request with endpoint, method, and all necessary headers for the http call
    //**
    global abstract HttpRequest buildCaptureRequest();

    //**
    //* @description Handles the response from the payment gateway
    //* @param  response - HttpResponse returned from http call to payment gateway
    //* @return GatewayResponse - includes payment information and gateway reference number returned from payment gateway
    //**
    global abstract CommercePayments.GatewayResponse buildCaptureResponse(HttpResponse response);

    //**
    //* @description Defines the refund request. Child classes need to implement this method to handle the request for the payment gateway
    //* @return  HttpRequest - request with endpoint, method, and all necessary headers for the http call
    //**
    global abstract HttpRequest buildRefundRequest();

    //**
    //* @description Handles the response from the payment gateway
    //* @param  response - HttpResponse returned from http call to payment gateway
    //* @return GatewayResponse - includes payment information and gateway reference number returned from payment gateway
    //**
    global abstract CommercePayments.GatewayResponse buildRefundResponse(HttpResponse response);
    
    global virtual HttpRequest buildAuthorizeRequest() {return null;}
    global virtual CommercePayments.GatewayResponse buildAuthorizeResponse(HttpResponse response) {return null;}

    /*******************************************************************************************/
    /***** Virtual methods - child adapters can choose to override these, but not required *****/
    /*******************************************************************************************/

    //**
    //* @description Used for any intialization tasks that need to be performed first
    //**
    global virtual void initialize() {
    }

    //**
    //* @description Sets the Authorization header for a request. Allows child adapter to implement custom authentication
    //* @param  request - Http request for either the capture or refund transaction. Authorization header can be added to this request
    //**
    global virtual void setAuthorizationHeader(HttpRequest request) {
    }

    //**
    //* @description Handles async notifications from the payment gateway
    //* @param  gatewayNotificationContext - includes information about the notification
    //* @return GatewayNotificationResponse - gateway response
    global virtual CommercePayments.GatewayNotificationResponse processNotification(
        CommercePayments.PaymentGatewayNotificationContext gatewayNotificationContext
    ) {
        return null;
    }

    //**
    //* @description Defines the PaymentAuthorization fields to query. Query has to be dynamic since CurrencyIsoCode is only available in multi-currency orgs.
    //*              Method can be overridden to provide a custom set of fields to query
    //* @return  List<String> - list of PaymentAuthorization fields
    //**
    global virtual List<String> getPaymentAuthorizationFields() {
        List<String> fields = new List<String>{
            'Amount',
            'OrderPaymentSummaryId',
            'OrderPaymentSummary.OrderSummaryId',
            'GatewayRefNumber',
            'OrderPaymentSummary.OrderSummary.SalesChannelId',
            'OrderPaymentSummary.OrderSummary.SalesChannel.SalesChannelName'
        };
        if (UserInfo.isMultiCurrencyOrganization())
            fields.add('CurrencyIsoCode');
        return fields;
    }

    //**
    //* @description Defines the Payment fields to query. Query has to be dynamic since CurrencyIsoCode is only available in multi-currency orgs.
    //*              Method can be overridden to provide a custom set of fields to query
    //* @return  List<String> - list of Payment fields
    //**
    global virtual List<String> getPaymentFields() {
        List<String> fields = new List<String>{
            'Amount',
            'GatewayRefNumber',
            'OrderPaymentSummaryId',
            'OrderPaymentSummary.OrderSummaryId',
            'OrderPaymentSummary.OrderSummary.SalesChannelId',
            'OrderPaymentSummary.OrderSummary.SalesChannel.SalesChannelName'
        };
        if (UserInfo.isMultiCurrencyOrganization())
            fields.add('CurrencyIsoCode');
        return fields;
    }

    //**
    //* @description Provides a full implementation of the required processRequest method in the CommercePayments.PaymentGatewayAdapter interface
    //*				 Calls the appropriate methods to build the http request and handle the response. Makes callouts to the payment gateways, so
    //*				 child classes shouldn't need to make their own callout except in the case of authentication.
    //* @param  gateway_context - the context the gateway was called in. This adapter handles capture and refund contexts
    //* @return GatewayResponse - payment/gateway reference information that gets stored in the payment object for captures and the refund object for refunds
    global virtual CommercePayments.GatewayResponse processRequest(CommercePayments.PaymentGatewayContext gateway_context) {
        CommercePayments.PaymentsHttp http = new CommercePayments.PaymentsHttp();

        this.request_type = gateway_context.getPaymentRequestType();

        CommercePayments.GatewayResponse gateway_response;

        if (this.request_type == CommercePayments.RequestType.Capture)
            this.payment_capture_request = (CommercePayments.CaptureRequest) gateway_context.getPaymentRequest();
        else if (this.request_type == CommercePayments.RequestType.ReferencedRefund)
            this.payment_refund_request = (CommercePayments.ReferencedRefundRequest) gateway_context.getPaymentRequest();
        else if (this.request_type == CommercePayments.RequestType.Authorize)
            this.payment_authorize_request = (CommercePayments.AuthorizationRequest) gateway_context.getPaymentRequest();

        try {
            this.initPaymentInformation();
            this.initialize();

            HttpRequest request = this.buildRequest(this.request_type);

            if (request == null)
                return new CommercePayments.GatewayErrorResponse('400', 'Request not formatted correctly');
            system.debug('Request :: ' + request);
            HttpResponse response = http.send(request);

            gateway_response = this.buildResponse(request_type, response);
        } catch (GatewayValidationException ex) {
            return new CommercePayments.GatewayErrorResponse(ex.getStatusCode(), ex.getMessage());
        } catch (Exception ex) {
            system.debug('Exception :: ' + ex);
            return new CommercePayments.GatewayErrorResponse('500', ex.getMessage());
        }
        return gateway_response;
    }

    //**
    //* @description Calls the appropriate method to handle building the HttpRequest
    //* @param  request_type - used to determine which method to call
    //* @return HttpRequest - request to make to the payment gateway
    //**
    @TestVisible
    private HttpRequest buildRequest(CommercePayments.RequestType request_type) {
        System.debug(request_type);
        switch on request_type {
            when Capture {
                return this.buildCaptureRequest();
            }
            when ReferencedRefund {
                return this.buildRefundRequest();
            }
            when Authorize {
                return this.buildAuthorizeRequest();
            }
            when else {
                throw new GatewayValidationException('405', 'Unsupported request type: ' + request_type);
            }
        }
    }

    //**
    //* @description Calls the appropriate method to handle the response returned from the payment gateway
    //* @param  request_type - used to determine which method to call. Valid values are 'Capture' and 'ReferencedRefund'
    //* @param  response - HttpResponse returned from payment gateway call
    //* @return GatewayResponse - payment/gateway reference information that gets stored in the payment object for captures and the refund object for refunds
    //**
    @TestVisible
    private CommercePayments.GatewayResponse buildResponse(CommercePayments.RequestType request_type, HttpResponse response) {
        switch on request_type {
            when Capture {
                return this.buildCaptureResponse(response);
            }
            when ReferencedRefund {
                return this.buildRefundResponse(response);
            }
            when Authorize {
                return this.buildAuthorizeResponse(response);
            }
            when else {
                throw new GatewayValidationException('405', 'Unsupported request type: ' + request_type);
            }
        }
    }

    //**
    //* @description Utility method used to build an HttpRequest. Child classes can pass http info to this method and have it build the request
    //* @param  endpoint - url to call
    //* @param  method - http method (GET, POST, etc)
    //* @param  body - data to send in the request body
    //* @param  headers - map of headers
    //* @return HttpRequest
    //**
    @TestVisible
    protected HttpRequest buildHttpRequest(String endpoint, String method, String body, Map<String, String> headers) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod(method);

        if (String.isNotBlank(body))
            request.setBody(body);

        if (headers != null && !headers.isEmpty()) {
            for (String headerName : headers.keySet())
                request.setHeader(headerName, headers.get(headerName));
        }

        this.setAuthorizationHeader(request);

        return request;
    }

    //**
    //* @description Sets PaymentAuthorization and Payment information
    //**
    private void initPaymentInformation() {
        if (this.payment_capture_request != null)
            this.payment_authorization = this.getPaymentAuthorization();

        if (this.payment_refund_request != null)
            this.m_payment = this.getPayment();
    }

    //**
    //* @description Retrieves the PaymentAuthorization record stored in the CaptureRequest object
    //* @return  PaymentAuthorization - includes payment information and the gateway reference id, which is used to identify the order in PayPal
    //**
    global virtual PaymentAuthorization getPaymentAuthorization() {
        List<String> fields = this.getPaymentAuthorizationFields();
        system.debug('Payment Authorization ID :: ' + this.payment_capture_request.paymentAuthorizationId);
        String query =
            'SELECT ' +
            String.join(fields, ',') +
            ' FROM PaymentAuthorization WHERE Id = \'' +
            this.payment_capture_request.paymentAuthorizationId +
            '\' LIMIT 1';
        system.debug('Payment Authorization Query :: ' + query);
        List<PaymentAuthorization> paymentAuthorizations = Database.query(query);
        return (!paymentAuthorizations.isEmpty()) ? paymentAuthorizations[0] : null;
    }

    //**
    //* @description Retrieves the Payment record stored in the ReferencedRefundRequest object
    //* @return  Payment - includes payment information and the gateway reference id, which is used to identify the order in PayPal
    //**
    global virtual Payment getPayment() {
        List<String> fields = this.getPaymentFields();
        system.debug('Payment ID :: ' + this.payment_refund_request.PaymentId);
        String query = 'SELECT ' + String.join(fields, ',') + ' FROM Payment WHERE Id = \'' + this.payment_refund_request.PaymentId + '\' LIMIT 1';
        List<Payment> payments = Database.query(query);
        return (!payments.isEmpty()) ? payments[0] : null;
    }

    //**
    //* @description Replaces placeholders in a string with real values
    //* @param  {String} url: url with placeholders. ex: /{ID}/capture
    //* @param  {Map<String, String>} pathParams: map of placeholders to values
    //* @return {String} url updated with values
    //**
    protected String replacePathParams(String url, Map<String, String> pathParams) {
        if (String.isBlank(url))
            return url;
        if (pathParams == null || pathParams.isEmpty())
            return url;

        for (String paramKey : pathParams.keySet())
            url = url.replace(paramKey, pathParams.get(paramKey));

        return url;
    }

    //**
    //* @description Checks api response to ensure the success status code was returned
    //* @param  {HttpResponse} response: response from api
    //* @param  {Integer} successStatus: expected success status
    //* @throws {GatewayValidationException}
    //**
    protected void validateGatewayResponse(HttpResponse response, Integer successStatus) {
        if (response == null)
            throwValidationException(500, 'Gateway response is null');

        Integer statusCode = response.getStatusCode();
        if (statusCode != successStatus)
            throwValidationException(statusCode, response.getBody());
    }

    //**
    //* @description Throws GatewayValidationException
    //* @param  {Integer} statusCode: exception status code
    //* @param  {String} body: error message
    //* @throws {GatewayValidationException}
    //**
    protected void throwValidationException(Integer statusCode, String body) {
        throw new AbstractAsyncPaymentGatewayAdapter.GatewayValidationException(String.valueOf(statusCode), body);
    }

    //**
    //* @description Retrieves the sales channel from the payment authorization or the payment
    //* @returns {String} sales channel
    //**
    protected String getSalesChannel() {
        if (this.payment_authorization != null)
            return this.payment_authorization.OrderPaymentSummary.OrderSummary.SalesChannel.SalesChannelName;
        return this.m_payment.OrderPaymentSummary.OrderSummary.SalesChannel.SalesChannelName;
    }

    //**
    //* @description Custom validation thrown by child classes in the case of callout errors
    //**
    @namespaceAccessible
    public class GatewayValidationException extends Exception {
        private String status_code;

        @namespaceAccessible
        public GatewayValidationException(String status_code, String message) {
            this(message);
            this.status_code = status_code;
        }

        @namespaceAccessible
        public String getStatusCode() {
            return this.status_code;
        }
    }
}