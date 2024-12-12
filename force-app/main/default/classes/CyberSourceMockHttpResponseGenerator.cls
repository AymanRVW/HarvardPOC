@IsTest
public class CyberSourceMockHttpResponseGenerator implements HttpCalloutMock {
    private Boolean is_failure;

    public CyberSourceMockHttpResponseGenerator() {
        this.is_failure = false;
    }

    public CyberSourceMockHttpResponseGenerator(Boolean is_failure) {
        this.is_failure = is_failure;
    }

    public HttpResponse respond(HttpRequest request) {
        CyberSourceAsyncGatewayAdapter.CSRequestBody request_body = (CyberSourceAsyncGatewayAdapter.CSRequestBody) JSON.deserialize(
            request.getBody(),
            CyberSourceAsyncGatewayAdapter.CSRequestBody.class
        );
        CyberSourceAsyncGatewayAdapter.CSResponseBody response_body = new CyberSourceAsyncGatewayAdapter.CSResponseBody();
        response_body.clientReferenceInformation = new CyberSourceAsyncGatewayAdapter.ClientRefInfo();
        response_body.clientReferenceInformation.code = request_body.clientReferenceInformation.code;

        Integer status_code = (this.is_failure) ? 400 : 201;

        HttpResponse response = new HttpResponse();
        response.setStatusCode(status_code);
        response.setHeader('Content-Type', 'application/json');
        response.setBody(JSON.serialize(request_body));
        return response;
    }
}