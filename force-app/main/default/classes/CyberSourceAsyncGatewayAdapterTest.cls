@IsTest
public class CyberSourceAsyncGatewayAdapterTest {
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

        Test.setMock(HttpCalloutMock.class, new CyberSourceMockHttpResponseGenerator());
        Test.startTest();
        CyberSourceAsyncGatewayAdapter adapter = new CyberSourceAsyncGatewayAdapter();
        CommercePayments.GatewayResponse response = adapter.processRequest(context);
        Test.stopTest();

        system.assert(response instanceof CommercePayments.CaptureResponse);
    }

    @IsTest(SeeAllData=true)
    private static void testCaptureRequest_FailedCapture() {
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

        Test.setMock(HttpCalloutMock.class, new CyberSourceMockHttpResponseGenerator(true));
        Test.startTest();
        CyberSourceAsyncGatewayAdapter adapter = new CyberSourceAsyncGatewayAdapter();
        CommercePayments.GatewayResponse response = adapter.processRequest(context);
        Test.stopTest();

        system.assert(response instanceof CommercePayments.GatewayErrorResponse);
    }

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

        Test.setMock(HttpCalloutMock.class, new CyberSourceMockHttpResponseGenerator());
        Test.startTest();
        CyberSourceAsyncGatewayAdapter adapter = new CyberSourceAsyncGatewayAdapter();
        CommercePayments.GatewayResponse response = adapter.processRequest(refund_context);
        Test.stopTest();

        system.assert(response instanceof CommercePayments.ReferencedRefundResponse);
    }

    @IsTest(SeeAllData=true)
    private static void testRefundRequest_FailedRefund() {
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

        Test.setMock(HttpCalloutMock.class, new CyberSourceMockHttpResponseGenerator(true));
        Test.startTest();
        CyberSourceAsyncGatewayAdapter adapter = new CyberSourceAsyncGatewayAdapter();
        CommercePayments.GatewayResponse response = adapter.processRequest(refund_context);
        Test.stopTest();

        system.assert(response instanceof CommercePayments.GatewayErrorResponse);
    }
}