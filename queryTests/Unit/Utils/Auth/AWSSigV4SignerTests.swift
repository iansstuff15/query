import Foundation
import Testing
@testable import query

@Suite("AWSSigV4Signer")
struct AWSSigV4SignerTests {
    /// AWS's published IAM ListUsers GET example (keys and expected signature from the SigV4 docs).
    @Test func matchesAWSDocumentationExample() throws {
        let signer = AWSSigV4Signer(
            accessKeyID: "AKIDEXAMPLE", secretAccessKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY", region: "us-east-1", service: "iam"
        )
        var request = URLRequest(url: try #require(URL(string: "https://iam.amazonaws.com/?Action=ListUsers&Version=2010-05-08")))
        request.httpMethod = "GET"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        signer.sign(&request, body: Data(), date: Date(timeIntervalSince1970: 1_440_938_160)) // 2015-08-30T12:36:00Z
        let authorization = try #require(request.value(forHTTPHeaderField: "Authorization"))
        #expect(authorization == "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/iam/aws4_request, SignedHeaders=content-type;host;x-amz-date, Signature=5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7")
    }
}
