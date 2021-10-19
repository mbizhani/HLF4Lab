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

import java.io.File;
import java.nio.file.Paths;
import java.util.Properties;

public class EnrollAdmin {

	public static HFCAClient createClient() throws Exception {
		final Properties props = new Properties();
		props.put("pemFile", "OUT/ca/ca.org1.example.com-cert.pem");
		props.put("allowAllHostNames", "true");

		final HFCAClient caClient = HFCAClient.createNewInstance("http://ca.org1.example.com", props);
		caClient.setCryptoSuite(CryptoSuiteFactory.getDefault().getCryptoSuite());

		return caClient;
	}


	public static void main(String[] args) throws Exception {
		// Create a CA client for interacting with the CA.
		final HFCAClient caClient = createClient();

		// Create a wallet for managing identities
		Wallet wallet = Wallets.newFileSystemWallet(Paths.get("wallet"));

		// Check to see if we've already enrolled the admin user.
		if (wallet.get("admin") != null) {
			System.out.println("An identity for the admin user \"admin\" already exists in the wallet");
			return;
		}

		// Enroll the admin user, and import the new identity into the wallet.
		final EnrollmentRequest enrollmentRequestTLS = new EnrollmentRequest();
		enrollmentRequestTLS.addHost("localhost");
		enrollmentRequestTLS.setProfile("tls");
		Enrollment enrollment = caClient.enroll("admin", "adminpw", enrollmentRequestTLS);
		Identity user = Identities.newX509Identity("Org1MSP", enrollment);
		wallet.put("admin", user);
		System.out.println("Successfully enrolled user \"admin\" and imported it into the wallet");
	}
}
