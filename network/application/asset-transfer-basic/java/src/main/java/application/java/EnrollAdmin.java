package application.java;

import org.hyperledger.fabric.gateway.Identities;
import org.hyperledger.fabric.gateway.Identity;
import org.hyperledger.fabric.gateway.Wallet;
import org.hyperledger.fabric.gateway.Wallets;
import org.hyperledger.fabric.sdk.Enrollment;
import org.hyperledger.fabric.sdk.security.CryptoSuiteFactory;
import org.hyperledger.fabric_ca.sdk.EnrollmentRequest;
import org.hyperledger.fabric_ca.sdk.HFCAClient;

import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

public class EnrollAdmin {
	private static final Map<String, Integer> CA_ORGS_PORT = new HashMap<>();
	private static final Map<String, String> CA_ORGS_MSP = new HashMap<>();

	static {
		CA_ORGS_PORT.put("org1", 30101);
		CA_ORGS_PORT.put("org2", 30102);

		CA_ORGS_MSP.put("org1", "Org1MSP");
		CA_ORGS_MSP.put("org2", "Org2MSP");
	}

	public static HFCAClient createClient(String orgId) throws Exception {
		final Properties props = new Properties();
		props.put("pemFile", String.format("OUT/ca/ca.%s.example.com-cert.pem", orgId));
		props.put("allowAllHostNames", "true");

		final HFCAClient caClient = HFCAClient.createNewInstance(
			String.format("https://ca.%s.example.com:%s", orgId, CA_ORGS_PORT.get(orgId)),
			props);
		caClient.setCryptoSuite(CryptoSuiteFactory.getDefault().getCryptoSuite());

		return caClient;
	}

	public static Wallet enroll(String orgId, String walletPath, String username, String password) throws Exception {
		// Create a CA client for interacting with the CA.
		final HFCAClient caClient = createClient(orgId);

		// Create a wallet for managing identities
		final Wallet wallet = Wallets.newFileSystemWallet(Paths.get(walletPath + "-" + orgId));

		// Check to see if we've already enrolled the admin user.
		if (wallet.get(username) != null) {
			System.out.printf("An identity for the user '%s' already exists in the wallet\n", username);
			return wallet;
		}

		// Enroll the admin user, and import the new identity into the wallet.
		final EnrollmentRequest enrollmentRequestTLS = new EnrollmentRequest();
		enrollmentRequestTLS.addHost("localhost");
		enrollmentRequestTLS.setProfile("tls");
		Enrollment enrollment = caClient.enroll(username, password, enrollmentRequestTLS);
		Identity user = Identities.newX509Identity(CA_ORGS_MSP.get(orgId), enrollment);
		wallet.put(username, user);
		System.out.printf("Successfully enrolled user '%s' and imported it into the wallet\n", username);
		return wallet;
	}
}
