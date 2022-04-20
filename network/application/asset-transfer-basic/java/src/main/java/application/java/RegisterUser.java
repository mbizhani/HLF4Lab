package application.java;

import org.hyperledger.fabric.gateway.*;
import org.hyperledger.fabric.sdk.Enrollment;
import org.hyperledger.fabric.sdk.User;
import org.hyperledger.fabric_ca.sdk.HFCAClient;
import org.hyperledger.fabric_ca.sdk.RegistrationRequest;
import org.hyperledger.fabric_ca.sdk.exception.RegistrationException;

import java.nio.file.Paths;
import java.security.PrivateKey;
import java.util.Set;

@Deprecated
public class RegisterUser {
	public static void register(String username, String password, String walletPath) throws Exception {

		// Create a CA client for interacting with the CA.
		final HFCAClient caClient = EnrollAdmin.createClient("org1");

		// Create a wallet for managing identities
		final Wallet wallet = Wallets.newFileSystemWallet(Paths.get(walletPath));

		// Check to see if we've already enrolled the user.
		if (wallet.get("appUser") != null) {
			System.out.println("An identity for the user \"appUser\" already exists in the wallet");
			return;
		}

		final X509Identity adminIdentity = (X509Identity) wallet.get("admin");
		if (adminIdentity == null) {
			System.out.println("\"admin\" needs to be enrolled and added to the wallet first");
			return;
		}
		try {
			final User admin = new User() {

				@Override
				public String getName() {
					return "admin";
				}

				@Override
				public Set<String> getRoles() {
					return null;
				}

				@Override
				public String getAccount() {
					return null;
				}

				@Override
				public String getAffiliation() {
					return "";
				}

				@Override
				public Enrollment getEnrollment() {
					return new Enrollment() {

						@Override
						public PrivateKey getKey() {
							return adminIdentity.getPrivateKey();
						}

						@Override
						public String getCert() {
							return Identities.toPemString(adminIdentity.getCertificate());
						}
					};
				}

				@Override
				public String getMspId() {
					return "Org1MSP";
				}

			};

			// Register the user, enroll the user, and import the new identity into the wallet.
			RegistrationRequest registrationRequest = new RegistrationRequest(username);
			registrationRequest.setAffiliation("");
			registrationRequest.setEnrollmentID(username);
			registrationRequest.setType("client");
			registrationRequest.setSecret(password);

			caClient.register(registrationRequest, admin);
		} catch (RegistrationException e) {
			if (e.getMessage().contains("already registered")) {
				System.out.println("Registration: " + e.getMessage());
			} else {
				throw e;
			}
		}

		final Enrollment enrollment = caClient.enroll(username, password);
		final Identity identity = Identities.newX509Identity("Org1MSP", enrollment);
		wallet.put(username, identity);
		System.out.printf("Successfully enrolled user \"%s\" and imported it into the wallet\n", username);
	}

	public static void main(String[] args) throws Exception {
		register("appUser", "appUserPw", "wallet");
	}
}
