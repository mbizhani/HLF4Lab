/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

// Running TestApp: 
// gradle runApp 

package application.java;

import org.hyperledger.fabric.gateway.*;

import java.nio.file.Path;
import java.nio.file.Paths;


public class App {
	public static final String WALLET_PATH = "OUT/wallet";
	public static final String USER = "backend";
	public static final String PASS = "backendPw";

	// helper function for getting connected to the gateway
	public static Gateway connect() throws Exception {
		// Load an in-memory wallet for managing identities.
		final Wallet wallet = EnrollAdmin.enroll(WALLET_PATH, USER, PASS);

		// Load a CCP
		final Path networkConfigPath = Paths.get("OUT/organizations/peerOrganizations/org1.example.com/connection-org1.yaml");

		final Gateway.Builder builder = Gateway.createBuilder();
		builder
			.identity(wallet, USER)
			.networkConfig(networkConfigPath);
		return builder.connect();
	}

	public static void main(String[] args) {
		// Connect to the network and invoke the smart contract
		try (Gateway gateway = connect()) {

			// get the network and contract
			Network network = gateway.getNetwork("mychannel");
			Contract contract = network.getContract("basic");

			byte[] result;

//			System.out.println("Submit Transaction: InitLedger creates the initial set of assets on the ledger.");
//			contract.submitTransaction("InitLedger");

			System.out.println("\n");
			result = contract.evaluateTransaction("getAllAssets");
			System.out.println("Evaluate Transaction: GetAllAssets, result: " + new String(result));

			try {
				System.out.println("\n");
				System.out.println("Submit Transaction: CreateAsset asset13");
				// CreateAsset creates an asset with ID asset13, color yellow, owner Tom, size 5 and appraisedValue of 1300
				contract.submitTransaction("createAsset", "asset13", "yellow", "5", "Tom", "1300");
			} catch (ContractException e) {
				System.out.println("ERROR: " + e.getMessage());
			}

			System.out.println("\n");
			System.out.println("Evaluate Transaction: ReadAsset asset13");
			// ReadAsset returns an asset with given assetID
			result = contract.evaluateTransaction("readAsset", "asset13");
			System.out.println("Result: " + new String(result));

			System.out.println("\n");
			System.out.println("Evaluate Transaction: AssetExists asset1");
			// AssetExists returns "true" if an asset with given assetID exist
			result = contract.evaluateTransaction("assetExists", "asset1");
			System.out.println("result: " + new String(result));

			System.out.println("\n");
			System.out.println("Submit Transaction: UpdateAsset asset1, new AppraisedValue : 350");
			// UpdateAsset updates an existing asset with new properties. Same args as CreateAsset
			contract.submitTransaction("updateAsset", "asset1", "blue", "5", "Tomoko", "350");

			System.out.println("\n");
			System.out.println("Evaluate Transaction: ReadAsset asset1");
			result = contract.evaluateTransaction("readAsset", "asset1");
			System.out.println("result: " + new String(result));

			try {
				System.out.println("\n");
				System.out.println("Submit Transaction: UpdateAsset asset70");
				//Non existing asset asset70 should throw Error
				contract.submitTransaction("updateAsset", "asset70", "blue", "5", "Tomoko", "300");
			} catch (ContractException e) {
				System.out.println("ERROR: Expected an error on UpdateAsset of non-existing Asset: " + e);
			}

			System.out.println("\n");
			System.out.println("Submit Transaction: TransferAsset asset1 from owner Tomoko > owner Tom");
			// TransferAsset transfers an asset with given ID to new owner Tom
			contract.submitTransaction("transferAsset", "asset1", "Tom");

			System.out.println("\n");
			System.out.println("Evaluate Transaction: ReadAsset asset1");
			result = contract.evaluateTransaction("readAsset", "asset1");
			System.out.println("result: " + new String(result));
		} catch (Exception e) {
			e.printStackTrace();
		}

	}
}
