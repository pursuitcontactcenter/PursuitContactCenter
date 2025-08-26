/**
 * @description
 * This is a test class for the EinsteinAuthService class. 
 * It uses a mock HTTP callout to simulate an OAuth token response from an external authentication server.
 * Since Custom Metadata Types (CMDT) can't be created in test context, the test assumes that the required 
 * CMDT record already exists in the org or that the production code handles fallback/defaults gracefully.
 * Author - Reetabrata
 */



@isTest
private class EinsteinAuthServiceTest {
/**
     * Mock implementation of HttpCalloutMock to simulate an OAuth token response.
     */
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // Simulated JSON response with access token and other OAuth fields
            res.setBody('{"access_token": "mock_token", "instance_url": "https://mock.salesforce.com", "token_type": "Bearer", "expires_in": 3600}');
            res.setStatusCode(200);
            return res;
        }
    }

    /**
     * Unit test for the getAccessToken method of EinsteinAuthService.
     * It verifies that the correct token is returned when a valid mock response is provided.
     */
    @isTest
    static void testGetAccessToken() {
        // Register the mock callout implementation
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();

        try {
            // Call the method under test
            String token = EinsteinAuthService.getAccessToken();

            // Validate that the returned token matches the mocked value
            System.assertEquals('mock_token', token, 'Access token should match mock value');
        } catch (Exception e) {
            // Fail the test if any unexpected exception occurs
            System.assert(false, 'Unexpected exception: ' + e.getMessage());
        }

        Test.stopTest();
    }
}