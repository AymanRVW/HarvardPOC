@IsTest
global class AbstractAsyncPaymentGatewayAdapterTest {
    @IsTest
    private static void testSetAuthorizationHeader() {
        Test.startTest();
        TestAsyncPaymentGatewayAdapter adapter = new TestAsyncPaymentGatewayAdapter();
        adapter.setAuthorizationHeader(new HttpRequest());
        Test.stopTest();
    }

    @IsTest
    private static void testProcessNotification() {
        Map<String, String> mHeaders = new Map<String, String>{ 'Content-Type' => 'application/json' };
        String mockPostResponse = '{"test": "response"}';
        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = new CommercePayments.PaymentGatewayNotificationRequest(
            mHeaders,
            mockPostResponse
        );
        CommercePayments.PaymentGatewayNotificationContext paymentGatewayNotificationContext = new CommercePayments.PaymentGatewayNotificationContext(
            paymentGatewayNotificationRequest
        );

        Test.startTest();
        TestAsyncPaymentGatewayAdapter adapter = new TestAsyncPaymentGatewayAdapter();
        CommercePayments.GatewayNotificationResponse response = adapter.processNotification(paymentGatewayNotificationContext);
        Test.stopTest();

        system.assert(response == null);
    }

    // ConnectApi requires SeeAllData=true
    @IsTest(SeeAllData=true)
    private static void testCaptureRequest() {
        String order_id = OrderTestUtil.createActiveOrderSummary(true);
        String fulfillment_id = OrderTestUtil.createFulfillmentForOrder(order_id);
        String invoice_id = OrderTestUtil.createInvoice(fulfillment_id);

        PaymentAuthorization payment_auth = [
            SELECT Id, Amount
            FROM PaymentAuthorization
            WHERE OrderPaymentSummary.OrderSummary.OriginalOrderId = :order_id
            LIMIT 1
        ];

        CommercePayments.CaptureRequest capture_request = new CommercePayments.CaptureRequest(Double.valueOf(payment_auth.Amount), payment_auth.Id);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(
            capture_request,
            CommercePayments.RequestType.Capture
        );

        Test.setMock(HttpCalloutMock.class, new TestHttpCalloutMock(false));
        Test.startTest();
        TestAsyncPaymentGatewayAdapter adapter = new TestAsyncPaymentGatewayAdapter();
        CommercePayments.GatewayResponse response = adapter.processRequest(context);
        Test.stopTest();

        system.assert(response instanceof CommercePayments.CaptureResponse);
    }

    // ConnectApi requires SeeAllData=true
    @IsTest(SeeAllData=true)
    private static void testCaptureRequest_Failure() {
        String order_id = OrderTestUtil.createActiveOrderSummary(true);
        String fulfillment_id = OrderTestUtil.createFulfillmentForOrder(order_id);
        String invoice_id = OrderTestUtil.createInvoice(fulfillment_id);

        PaymentAuthorization payment_auth = [
            SELECT Id, Amount
            FROM PaymentAuthorization
            WHERE OrderPaymentSummary.OrderSummary.OriginalOrderId = :order_id
            LIMIT 1
        ];

        CommercePayments.CaptureRequest capture_request = new CommercePayments.CaptureRequest(Double.valueOf(payment_auth.Amount), payment_auth.Id);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(
            capture_request,
            CommercePayments.RequestType.Capture
        );

        Test.setMock(HttpCalloutMock.class, new TestHttpCalloutMock(true));
        Test.startTest();
        TestAsyncPaymentGatewayAdapter adapter = new TestAsyncPaymentGatewayAdapter();
        CommercePayments.GatewayResponse response = adapter.processRequest(context);
        Test.stopTest();

        system.assert(response instanceof CommercePayments.GatewayErrorResponse);
    }

    // ConnectApi requires SeeAllData=true
    @IsTest(SeeAllData=true)
    private static void testRefundRequest() {
        String order_id = OrderTestUtil.createActiveOrderSummary(true);
        String fulfillment_id = OrderTestUtil.createFulfillmentForOrder(order_id);
        String invoice_id = OrderTestUtil.createInvoice(fulfillment_id);

        OrderPaymentSummary ops = [SELECT Id FROM OrderPaymentSummary WHERE OrderSummary.OriginalOrderId = :order_id LIMIT 1];

        PaymentAuthorization payment_auth = [
            SELECT Id, Amount, GatewayRefNumber
            FROM PaymentAuthorization
            WHERE OrderPaymentSummaryId = :ops.Id
            LIMIT 1
        ];

        Payment pmt = new Payment();
        pmt.amount = payment_auth.Amount;
        pmt.Status = 'Processed';
        pmt.ProcessingMode = 'External';
        pmt.GatewayRefNumber = payment_auth.GatewayRefNumber;
        pmt.Type = 'Capture';
        pmt.OrderPaymentSummaryId = ops.Id;
        insert pmt;

        CommercePayments.ReferencedRefundRequest refund_request = new CommercePayments.ReferencedRefundRequest(Double.valueOf(pmt.Amount), pmt.Id);
        CommercePayments.PaymentGatewayContext refund_context = new CommercePayments.PaymentGatewayContext(
            refund_request,
            CommercePayments.RequestType.ReferencedRefund
        );

        Test.setMock(HttpCalloutMock.class, new TestHttpCalloutMock(false));
        Test.startTest();
        TestAsyncPaymentGatewayAdapter adapter = new TestAsyncPaymentGatewayAdapter();
        CommercePayments.GatewayResponse refund_response = adapter.processRequest(refund_context);
        Test.stopTest();

        system.assert(refund_response instanceof CommercePayments.ReferencedRefundResponse);
    }

    @IsTest
    private static void testBuildHttpRequest() {
        String endpoint = '/test';
        String method = 'POST';

        Map<String, String> body = new Map<String, String>{ 'test1' => '1234', 'test2' => 'ABCD' };

        Map<String, String> headers = new Map<String, String>{ 'Content-Type' => 'application/json' };

        Test.startTest();
        TestAsyncPaymentGatewayAdapter adapter = new TestAsyncPaymentGatewayAdapter();
        HttpRequest request = adapter.buildHttpRequest(endpoint, method, JSON.serialize(body), headers);
        Test.stopTest();

        system.assert(request != null);
        system.assert(request.getEndpoint() == endpoint);
        system.assert(request.getMethod() == method);
        system.assert(request.getBody() == JSON.serialize(body));

        for (String header : headers.keySet())
            system.assert(request.getHeader(header) == headers.get(header));
    }

    global class TestAsyncPaymentGatewayAdapter extends AbstractAsyncPaymentGatewayAdapter {
        global override HttpRequest buildCaptureRequest() {
            HttpRequest request = new HttpRequest();
            request.setEndpoint('/test');
            request.setMethod('GET');
            return request;
        }

        global override CommercePayments.GatewayResponse buildCaptureResponse(HttpResponse response) {
            Integer status_code = response.getStatusCode();
            if (status_code != 200)
                throw new AbstractAsyncPaymentGatewayAdapter.GatewayValidationException(String.valueOf(status_code), response.getBody());

            CommercePayments.CaptureResponse capture_response = new CommercePayments.CaptureResponse();
            capture_response.setGatewayDate(System.now());
            capture_response.setGatewayResultCode(String.valueOf(response.getStatusCode()));
            return capture_response;
        }

        global override HttpRequest buildRefundRequest() {
            HttpRequest request = new HttpRequest();
            request.setEndpoint('/test');
            request.setMethod('GET');
            return request;
        }

        global override CommercePayments.GatewayResponse buildRefundResponse(HttpResponse response) {
            CommercePayments.ReferencedRefundResponse refund_response = new CommercePayments.ReferencedRefundResponse();
            refund_response.setGatewayDate(System.now());
            refund_response.setGatewayResultCode(String.valueOf(response.getStatusCode()));
            return refund_response;
        }
    }

    public class TestHttpCalloutMock implements HttpCalloutMock {
        private Boolean is_failure;

        public TestHttpCalloutMock(Boolean is_failure) {
            this.is_failure = is_failure;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();

            Integer status_code = (this.is_failure) ? 400 : 200;
            response.setStatusCode(status_code);
            return response;
        }
    }
}