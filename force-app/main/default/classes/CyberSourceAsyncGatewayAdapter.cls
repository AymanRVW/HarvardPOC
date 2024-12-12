//**
//* @description CyberSource payment gateway adapter
//**

global class CyberSourceAsyncGatewayAdapter extends AbstractAsyncPaymentGatewayAdapter {
    private Autobahn_SOM_Setting__mdt general_settings;
    private CyberSource_Payment_Configuration__mdt gateway_settings;

    private final String DEFAULT_CAPTURE_COUNT = '99';

    global static void sale() {
        //first call buildAuthoarizeRequest

        //make a call to cybersource to make the authorization
        //HttpResponse response = http.send(request);

        //pull payment ID from authoization response

        //build capture request
        //buildCaptureRequest()

        //make a call to cybersource to make the capture
        //HttpResponse response = http.send(request);

        //call buildcaptureresponse()

    }

    global override HttpRequest buildAuthorizeRequest() {
        Commercepayments.CardPaymentMethodRequest cardPaymentMethod = this.payment_authorize_request.paymentMethod.cardPaymentMethod;
        
        String soapEnvelope = '<?xml version="1.0" encoding="UTF-8"?>';
        soapEnvelope += '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">';
        soapEnvelope += '  <soapenv:Header>';
        soapEnvelope += '    <wsse:Security soapenv:mustUnderstand="1" xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">';
        soapEnvelope += '      <wsse:UsernameToken>';
        soapEnvelope += '        <wsse:Username>' + this.gateway_settings.Merchant_Id__c + '</wsse:Username>';
        soapEnvelope += '        <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">' + 'jTWLSRfTi1P4ecJXotnbriIWNB3DpaYA+q9JxeMBiIMKh5i29fyQGL+k/vgggKMeNnpPKJPW7lVYhDDLtJWvjRqnAnflgzcdMKW70o+3QoIIt5r9NPJWOWISKPaN9c1WIiOknEk+JpJWPgzdim7Dd0ic1KENvCwNma8+pRSvwk+1dfb6vWdpCTUeTIx0vcXeNVQzzwdYwDhzUVeMO6k9Nm+3AvDSv9XJ7cIyY65bCpGU7b7bJS8oxt1buMPmc3Om01uy+AjtKW4Rsqf0T9sQpnciMa/dPsGEt/J4tPKd6OgnBtOqosDTuhW7kZ7/Qd4NX/kFUmcsKq7xh8RK+2Iupg==' + '</wsse:Password>';
        soapEnvelope += '      </wsse:UsernameToken>';
        soapEnvelope += '    </wsse:Security>';
        soapEnvelope += '  </soapenv:Header>';
        soapEnvelope += '  <soapenv:Body>';
        
        soapEnvelope += '		<requestMessage xmlns="urn:schemas-cybersource-com:transaction-data-1.170">';
        soapEnvelope += '			<merchantID>' + this.gateway_settings.Merchant_Id__c + '</merchantID>';
                                    //todo pull order# from ordersummary
        soapEnvelope += '			<merchantReferenceCode>' + 'ORDER-12345' + '</merchantReferenceCode>';  
        soapEnvelope += '			<billTo>';
        soapEnvelope += '				<firstName>' + cardPaymentMethod.cardHolderFirstName + '</firstName>';
        soapEnvelope += '				<lastName>' + cardPaymentMethod.cardHolderLastName + '</lastName>';
       	soapEnvelope += '				<street1>123 Test St</street1>';
        soapEnvelope += '				<city>San Francisco</city>';
        soapEnvelope += '				<state>CA</state>';
        soapEnvelope += '				<postalCode>94105</postalCode>';
        soapEnvelope += '				<country>US</country>';
        soapEnvelope += '				<email>' + cardPaymentMethod.email + '</email>';
        soapEnvelope += '			</billTo>';
         
        soapEnvelope += '			<purchaseTotals>';
        soapEnvelope += '				<currency>' + this.payment_authorize_request.currencyIsoCode + '</currency>';
        soapEnvelope += '				<grandTotalAmount>' + this.payment_authorize_request.amount + '</grandTotalAmount>';
        soapEnvelope += '			</purchaseTotals>';
        soapEnvelope += '			<card>';
        soapEnvelope += '				<accountNumber>' + cardPaymentMethod.cardNumber + '</accountNumber>';
        soapEnvelope += '				<expirationMonth>' + cardPaymentMethod.expiryMonth + '</expirationMonth>';
        soapEnvelope += '				<expirationYear>' + cardPaymentMethod.expiryYear + '</expirationYear>';
      	soapEnvelope += '			</card>';
        soapEnvelope += '			<ccAuthService run="true"/>';
      	soapEnvelope += '		</requestMessage>';
        
        soapEnvelope += '  </soapenv:Body>';
        soapEnvelope += '</soapenv:Envelope>';

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/soap');
        req.setEndpoint('/commerce/1.x/transactionProcessor');
        req.setBody(soapEnvelope);
        
        System.debug('Soap Envelope :: ' + soapEnvelope);

        return req;
    }
    
    global override CommercePayments.GatewayResponse buildAuthorizeResponse(HttpResponse response) {    
        Integer status_code = response.getStatusCode();
        System.debug('CyberSource Response: ' + response.getBody());
        if (status_code != 200 && status_code != 201)
            throw new AbstractAsyncPaymentGatewayAdapter.GatewayValidationException(String.valueOf(status_code), response.getBody());

        String responseBody = response.getBody();

        if (responseBody.contains('errorInformation') == true){
            throw new AbstractAsyncPaymentGatewayAdapter.GatewayValidationException(String.valueOf(status_code), response.getBody());
        }
        
        try {
            DOM.Document document = new DOM.Document();
            document.load(responseBody);
            DOM.XmlNode root = document.getRootElement();

            DOM.XmlNode soapBody = root.getChildElement('Body', root.getNamespace());
            System.debug(soapBody);

            List<Dom.XmlNode> bodyChildren = soapBody.getChildElements();
            System.debug(bodyChildren);

            DOM.XmlNode replyMessage = null;
            for(Dom.XmlNode node : bodyChildren){
                if(node.getName() == 'replyMessage'){
                    replyMessage = node;
                    break;
                }
            }
            DOM.XmlNode gateway_ref_num = replyMessage.getChildElement('requestID', replyMessage.getNamespace());
            System.debug(gateway_ref_num);
            System.debug('gateway_ref_num: ' + gateway_ref_num.getText());
            
            DOM.XmlNode auth_reply = replyMessage.getChildElement('ccAuthReply', replyMessage.getNamespace());
            DOM.XmlNode amount = auth_reply.getChildElement('amount', auth_reply.getNamespace());
            System.debug('Amount :: ' + amount.getText());

            CommercePayments.AuthorizationResponse gateway_response = new CommercePayments.AuthorizationResponse();
            gateway_response.setAmount(Double.valueOf(amount.getText()));
            gateway_response.setGatewayDate(System.now());
            gateway_response.setGatewayReferenceNumber(gateway_ref_num.getText());
            gateway_response.setGatewayResultCode(String.valueOf(status_code));
            gateway_response.setGatewayResultCodeDescription(response.getStatus());
            gateway_response.setSalesforceResultCodeInfo(new CommercePayments.SalesforceResultCodeInfo(CommercePayments.SalesforceResultCode.Success));
            System.debug('gateway_response: ' + gateway_response);
            return gateway_response;
        } catch(Exception ex) {
            //response.statusCode = 500;
            System.debug('Exception!' + ex.getMessage());
            throw new AbstractAsyncPaymentGatewayAdapter.GatewayValidationException('500', ex.getMessage() + '\n\n' + ex.getStackTraceString());
        }
    }
    
    //**
    //* @description Defines the PaymentAuthorization fields to query. Query has to be dynamic since CurrencyIsoCode is only available in multi-currency orgs.
    //*              Method can be overridden to provide a custom set of fields to query
    //* @return  List<String> - list of PaymentAuthorization fields
    //**
    global override List<String> getPaymentAuthorizationFields() {
        List<String> fields = new List<String>{
            'Amount',
            'OrderPaymentSummaryId',
            'OrderPaymentSummary.OrderSummaryId',
            'OrderPaymentSummary.OrderSummary.OrderNumber',
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
    global override List<String> getPaymentFields() {
        List<String> fields = new List<String>{
            'Amount',
            'GatewayRefNumber',
            'OrderPaymentSummaryId',
            'OrderPaymentSummary.OrderSummaryId',
            'OrderPaymentSummary.OrderSummary.OrderNumber',
            'OrderPaymentSummary.OrderSummary.SalesChannelId',
            'OrderPaymentSummary.OrderSummary.SalesChannel.SalesChannelName'
        };
        if (UserInfo.isMultiCurrencyOrganization())
            fields.add('CurrencyIsoCode');
        return fields;
    }

    //**
    //* @description Initializes gateway data
    //**
    global override void initialize() {
        String sales_channel_name;
        if (this.payment_authorization != null)
            sales_channel_name = this.payment_authorization.OrderPaymentSummary.OrderSummary.SalesChannel.SalesChannelName;
        else if(this.m_payment != null)
            sales_channel_name = this.m_payment.OrderPaymentSummary.OrderSummary.SalesChannel.SalesChannelName;
        else
            sales_channel_name = 'HMS';

        this.gateway_settings = this.getPaymentConfigurationForSalesChannel(sales_channel_name);
        this.general_settings = MetadataSettingsService.GetDefaultSettings();

        if (this.gateway_settings == null)
            throw new AbstractAsyncPaymentGatewayAdapter.GatewayValidationException(
                '412',
                'CyberSource_Payment_Configuration__mdt not configured for sales channel ' +
                sales_channel_name +
                ' and no default config has been set.'
            );
    }

    //**
    //* @description Retrieves payment gateway metadata for the provided sales channel
    //* @param  {String} sales_channel_name: sales channel linked to the order; processor accounts are linked to sales channels
    //* @return {CyberSource_Payment_Configuration__mdt}: metadata storing the api access keys related to the provided sales channel
    //**
    private CyberSource_Payment_Configuration__mdt getPaymentConfigurationForSalesChannel(String sales_channel_name) {
        if (Test.isRunningTest())
            return this.getTestPaymentConfig();

        Set<String> sales_channels = new Set<String>();
        sales_channels.add('Default');
        if (String.isNotBlank(sales_channel_name))
            sales_channels.add(sales_channel_name);

        List<CyberSource_Payment_Configuration__mdt> payment_config = [
            SELECT API_Key__c, Merchant_Id__c, Shared_Secret_Key__c
            FROM CyberSource_Payment_Configuration__mdt
            WHERE MasterLabel IN :sales_channels
        ];
        if (payment_config.size() == 1)
            return payment_config[0];

        CyberSource_Payment_Configuration__mdt config_to_use = null;
        for (CyberSource_Payment_Configuration__mdt config : payment_config) {
            if (config.MasterLabel == sales_channel_name) {
                config_to_use = config;
                break;
            }
        }
        return config_to_use;
    }

    //**
    //* @description Creates test custom metadata for running unit tests
    //* @return {CyberSource_payment_Configuration__mdt}: mock metadata
    //**
    private CyberSource_Payment_Configuration__mdt getTestPaymentConfig() {
        CyberSource_Payment_Configuration__mdt config = new CyberSource_Payment_Configuration__mdt();
        config.API_Key__c = 'ABCDEFG';
        config.Merchant_Id__c = 'testmerchant1';
        config.Shared_Secret_Key__c = EncodingUtil.base64Encode(Blob.valueOf('ABCD1234'));
        return config;
    }

    //**
    //* @description Builds CyberSource capture http request
    //* @return {HttpRequest}: includes all relevant fields to make the Http call, including endpoint, method, and headers
    //**
    global override HttpRequest buildCaptureRequest() {
        return this.buildCyberSourceRequest(
            this.payment_authorization,
            this.payment_capture_request.Amount,
            '/pts/v2/payments/' +
            this.payment_authorization.GatewayRefNumber +
            '/captures'
        );
    }

    //**
    //* @description Builds CyberSource refund http request
    //* @return {HttpRequest}: includes all relevant fields to make the Http call, including endpoint, method, and headers
    //**
    global override HttpRequest buildRefundRequest() {
        String endpoint = '/pts/v2/captures/' + this.m_payment.GatewayRefNumber + '/refunds';
        if (this.general_settings.CyberSource_AutoCapture_Enabled__c) {
            endpoint = '/pts/v2/payments/' + this.m_payment.GatewayRefNumber + '/refunds';
        }
        return this.buildCyberSourceRequest(this.m_payment, this.payment_refund_request.Amount, endpoint);
    }

    //**
    //* @description Handles the response from the CyberSource API for a capture request
    //* @param  {HttpResponse} response: HttpResponse returned from CyberSource API
    //* @return {GatewayResponse}: stores all payment information including gateway reference information
    //**
    global override CommercePayments.GatewayResponse buildCaptureResponse(HttpResponse response) {
        return this.buildCyberSourceResponse(response, this.payment_capture_request.Amount, new CommercePayments.CaptureResponse());
    }

    //**
    //* @description Handles the response from the CyberSource API for a refund request
    //* @param  {HttpResponse} response: HttpResponse returned from CyberSource API
    //* @return (GatewayResponse): stores all payment information including gateway reference information
    //**
    global override CommercePayments.GatewayResponse buildRefundResponse(HttpResponse response) {
        return this.buildCyberSourceResponse(response, this.payment_refund_request.Amount, new CommercePayments.ReferencedRefundResponse());
    }

    //**
    //* @description Builds Http request for both captures and refunds
    //* @param  {sObject} payment_obj: record that holds payment information; PaymentAuthorization for captures, Payment for refunds
    //* @param  {Double} amount: amount to capture/refund
    //* @param  {String} url: resource path for the capture/refund
    //* @return {HttpRequest}: includes all relevant data to make the Http call, including endpoint, method, and headers
    //**
    private HttpRequest buildCyberSourceRequest(sObject payment_obj, Double amount_to_capture, String url) {
        CSHeaders headers = new CSHeaders();
        headers.setMerchantId(this.gateway_settings.Merchant_Id__c);
        headers.setDate(Datetime.now());
        headers.setHost(this.general_settings.CyberSource_Host__c);

        ClientRefInfo ref_info = new ClientRefInfo();
        sObject ops = payment_obj.getSObject('OrderPaymentSummary');
        if (ops != null) {
            sObject oSummary = ops.getSObject('OrderSummary');
            if (oSummary != null && oSummary.get('OrderNumber') != null) {
                ref_info.code = String.valueOf(oSummary.get('OrderNumber'));
            }
        }

        String currency_code = (UserInfo.isMultiCurrencyOrganization()) ? String.valueOf(payment_obj.get('CurrencyIsoCode')) : DEFAULT_CURRENCY_CODE;

        OrderInfo o_info = new OrderInfo();
        o_info.amountDetails.put('totalAmount', String.valueOf(amount_to_capture));
        o_info.amountDetails.put('currency', currency_code);

        CSRequestBody request_body = new CSRequestBody();
        request_body.clientReferenceInformation = ref_info;
        request_body.orderInformation = o_info;

        if (this.request_type == CommercePayments.RequestType.Capture) {
            CSProcessingInformation processing_info = new CSProcessingInformation();
            processing_info.captureOptions = this.getCaptureOptions(this.payment_authorization.OrderPaymentSummaryId, amount_to_capture);
            request_body.processingInformation = processing_info;
        }

        CSRequestBodyAlt alt_request_body = null;
        if (
            request_body.processingInformation != null &&
            request_body.processingInformation.captureOptions.captureSequenceNumber == '1' &&
            request_body.processingInformation.captureOptions.totalCaptureCount == '1'
        ) {
            alt_request_body = new CSRequestBodyAlt();
            alt_request_body.clientReferenceInformation = request_body.clientReferenceInformation;
            alt_request_body.orderInformation = request_body.orderInformation;
        }

        Object req_body = (alt_request_body != null) ? (Object) alt_request_body : (Object) request_body;

        CyberSourceRequest cs_request = new CyberSourceRequest(
            headers,
            req_body,
            url,
            'POST',
            this.gateway_settings.API_Key__c,
            this.gateway_settings.Shared_Secret_Key__c
        );
        return cs_request.generateHttpRequest();
    }

    //**
    //* @description Handles the response from the CyberSource api for both captures and refunds
    //* @param  {HttpResponse} response: response from CyberSource
    //* @return {GatewayResponse}: response populated with transaction details
    //**
    private CommercePayments.GatewayResponse buildCyberSourceResponse(
        HttpResponse response,
        Double transaction_amount,
        CommercePayments.AbstractTransactionResponse gateway_response
    ) {
        Integer status_code = response.getStatusCode();
        if (status_code != 201)
            throw new AbstractAsyncPaymentGatewayAdapter.GatewayValidationException(String.valueOf(status_code), response.getBody());

        Map<String, Object> response_body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

        String gateway_ref_num = String.valueOf(response_body.get('id'));

        gateway_response.setAmount(transaction_amount);
        gateway_response.setGatewayDate(System.now());
        gateway_response.setGatewayReferenceNumber(gateway_ref_num);
        gateway_response.setGatewayResultCode(String.valueOf(status_code));
        gateway_response.setGatewayResultCodeDescription(response.getStatus());
        gateway_response.setSalesforceResultCodeInfo(new CommercePayments.SalesforceResultCodeInfo(CommercePayments.SalesforceResultCode.Success));
        return gateway_response;
    }

    //**
    //* @description Builds the captureOptions portion of the capture request to allow sucessful partial captures
    //* @param  {String} order_payment_summary_id: Id of the parent OrderPaymentSummary
    //* @param  {Double} amount_to_capture: amount to be captured by the current request
    //* @return {CSCaptureOptions}: holds the current capture # (# Payments + 1) and the total capture count (same as current capture # if final capture, 99 otherwise)
    //**
    private CSCaptureOptions getCaptureOptions(String order_payment_summary_id, Double amount_to_capture) {
        OrderPaymentSummary payment_summary = [
            SELECT CapturedAmount, OrderSummary.GrandTotalAmount
            FROM OrderPaymentSummary
            WHERE Id = :order_payment_summary_id
            LIMIT 1
        ];
        AggregateResult payment_count_info = [SELECT COUNT(Id) numPayments FROM Payment WHERE OrderPaymentSummaryId = :order_payment_summary_id];
        CSCaptureOptions capture_options = new CSCaptureOptions();
        capture_options.captureSequenceNumber = String.valueOf((Integer) payment_count_info.get('numPayments') + 1);

        Double total_captured = (payment_summary.CapturedAmount != null) ? payment_summary.CapturedAmount : 0;

        if (amount_to_capture + total_captured == payment_summary.OrderSummary.GrandTotalAmount)
            capture_options.totalCaptureCount = capture_options.captureSequenceNumber;
        else
            capture_options.totalCaptureCount = DEFAULT_CAPTURE_COUNT;

        return capture_options;
    }

    //**
    //* @description Wraps the CyberSource API request. Generates the auth signature and HttpRequest object
    //**
    public class CyberSourceRequest {
        private CSHeaders headers;
        private Object body;
        private String resource_path;
        private String http_method;
        private String merchant_key;
        private String secret_key;

        //**
        //* @description Automatically generates the digest and signature upon initialization
        public CyberSourceRequest(CSHeaders headers, Object body, String resource_path, String http_method, String merchant_key, String secret_key) {
            this.headers = headers;
            this.body = body;
            this.resource_path = resource_path;
            this.http_method = http_method;
            this.merchant_key = merchant_key;
            this.secret_key = secret_key;

            this.generateDigest();
            this.generateSignature();
        }

        public CSHeaders getHeaders() {
            return this.headers;
        }

        //**
        //* @description Builds an http request object from the stored request values
        //* @return {HttpRequest} - object for the CyberSource capture/refund request
        //**
        public HttpRequest generateHttpRequest() {
            HttpRequest request = new HttpRequest();
            request.setEndpoint(this.resource_path);
            request.setMethod(this.http_method);
            request.setBody(JSON.serialize(this.body));
            //System.debug('Body :: ' + JSON.serialize(this.body));
            
            Map<String, String> header_map = this.headers.toMap();
            for (String header : header_map.keySet()) {
                request.setHeader(header, header_map.get(header));
                system.debug('Header: ' + header + ' - ' + header_map.get(header));
            }
            
            request.setHeader('Content-Type', 'application/json');
            System.debug('Body :: ' + JSON.serialize(this.body));
            return request;
        }

        //**
        //* @description Generates a request digest by hashing a JSON payload with SHA256 and base64 encoding the hash
        //**
        private void generateDigest() {
            if (this.body == null)
                return;

            Blob hashed_digest = Crypto.generateDigest('SHA-256', Blob.valueOf(JSON.serialize(this.body)));
            String digest = 'SHA-256=' + EncodingUtil.base64Encode(hashed_digest);
            this.headers.setDigest(digest);
        }

        //**
        //* @description Generates the CyberSource signature header
        //**
        private void generateSignature() {
            List<String> signature_parameters = new List<String>();
            signature_parameters.add('keyid="' + this.merchant_key + '"');
            signature_parameters.add('algorithm="HmacSHA256"');
            signature_parameters.add('headers="host date (request-target) digest v-c-merchant-id"');
            signature_parameters.add('signature="' + this.generateSignatureHash() + '"');
            this.headers.setSignature(String.join(signature_parameters, ', '));
        }

        //**
        //* @description Generates a signature hash by concatenating the request headers and hashing using SHA-256
        //* @return {String} - signature hash
        //**
        private String generateSignatureHash() {
            Map<String, String> header_map = this.headers.toMap();
            List<String> sig_hash_header_lines = new List<String>();
            sig_hash_header_lines.add('host: ' + header_map.get('Host'));
            sig_hash_header_lines.add('date: ' + header_map.get('Date'));
            sig_hash_header_lines.add('(request-target): ' + this.http_method.toLowerCase() + ' ' + this.resource_path);
            sig_hash_header_lines.add('digest: ' + header_map.get('Digest'));
            sig_hash_header_lines.add('v-c-merchant-id: ' + header_map.get('v-c-merchant-id'));

            String sig_header = String.join(sig_hash_header_lines, '\n');
            Blob decoded_secret_key = EncodingUtil.base64Decode(this.secret_key);
            Blob sig_data = Crypto.generateMac('HmacSHA256', Blob.valueOf(sig_header), decoded_secret_key);
            return EncodingUtil.base64Encode(sig_data);
        }
    }

    //**
    //* @description Wraps the request headers
    //**
    public class CSHeaders {
        private Map<String, String> headers;

        public CSHeaders() {
            this.headers = new Map<String, String>();
        }

        public void setMerchantId(String merchant_id) {
            this.headers.put('v-c-merchant-id', merchant_id);
        }

        public void setDate(Datetime request_date) {
            if (request_date == null)
                request_date = Datetime.now();

            this.headers.put('Date', 'Thu, 17 Oct 2024 22:04:14 GMT');//request_date.formatGmt('EEE, dd MMM yyyy HH:mm:ss z'));
        }

        public void setHost(String host) {
            this.headers.put('Host', host);
        }

        public void setDigest(String digest) {
            this.headers.put('Digest', digest);
        }

        public void setSignature(String signature) {
            this.headers.put('Signature', signature);
        }

        public Map<String, String> toMap() {
            return this.headers;
        }
    }

    public class CSRequestBody {
        public ClientRefInfo clientReferenceInformation;
        public CSProcessingInformation processingInformation;
        public OrderInfo orderInformation;
    }

    public class CSRequestBodyAlt {
        public ClientRefInfo clientReferenceInformation;
        public OrderInfo orderInformation;
    }

    public class CSResponseBody {
        public String m_links;
        public ClientRefInfo clientReferenceInformation;
        public Map<String, Object> creditAmountDetails;
        public String id;
        public OrderInfo orderInformation;
        public ProcessorInfo processorInformation;
        public String reconciliationId;
        public Map<String, Object> refundAmountDetails;
        public String status;
        public String submitTimeUtc;
    }

    public class ClientRefInfo {
        public String code;
    }

    public class OrderInfo {
        public Map<String, String> amountDetails;

        public OrderInfo() {
            this.amountDetails = new Map<String, String>();
        }
    }

    public class CSProcessingInformation {
        public CSCaptureOptions captureOptions;
    }

    public class CSCaptureOptions {
        public String captureSequenceNumber;
        public String totalCaptureCount;
    }

    public class ProcessorInfo {
        public String approvalCode;
        public String responseCode;
    }
}