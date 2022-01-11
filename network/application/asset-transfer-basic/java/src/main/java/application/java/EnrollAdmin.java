/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

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
import java.util.Properties;

public class EnrollAdmin {

	public static HFCAClient createClient() throws Exception {
		final Properties props = new Properties();
		props.put("pemFile", "OUT/ca/ca.org1.example.com-cert.pem");
		props.put("allowAllHostNames", "true");

		final HFCAClient caClient = HFCAClient.createNewInstance("https://ca.org1.example.com:30101", props);
		caClient.setCryptoSuite(CryptoSuiteFactory.getDefault().getCryptoSuite());

		return caClient;
	}

	public static Wallet enroll(String walletPath, String username, String password) throws Exception {
		// Create a CA client for interacting with the CA.
		final HFCAClient caClient = createClient();

		// Create a wallet for managing identities
		final Wallet wallet = Wallets.newFileSystemWallet(Paths.get(walletPath));

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
		Identity user = Identities.newX509Identity("Org1MSP", enrollment);
		wallet.put(username, user);
		System.out.printf("Successfully enrolled user '%s' and imported it into the wallet\n", username);
		return wallet;
	}

	public static void main(String[] args) throws Exception {
		enroll("wallet", "admin", "adminpw");
	}
}
