package application.java;

import org.hyperledger.fabric.gateway.*;
import org.hyperledger.fabric.sdk.BlockInfo;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static java.nio.charset.StandardCharsets.UTF_8;


public class App {
	public static final String WALLET_PATH = "OUT/wallet";
	public static final String USER = "backend";
	public static final String PASS = "backendPw";

	// helper function for getting connected to the gateway
	static Gateway connect() throws Exception {
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

	static void registerBlockListener(Network network) {
		network.addBlockListener(event -> {
			for (BlockInfo.EnvelopeInfo envelopeInfo : event.getEnvelopeInfos()) {
				if (envelopeInfo.getType() == BlockInfo.EnvelopeType.TRANSACTION_ENVELOPE) {
					final Long blockNumber = event.getBlockNumber();
					final String transactionID = envelopeInfo.getTransactionID();
					final BlockInfo.TransactionEnvelopeInfo transactionEnvelopeInfo = (BlockInfo.TransactionEnvelopeInfo) envelopeInfo;
					for (BlockInfo.TransactionEnvelopeInfo.TransactionActionInfo transactionActionInfo : transactionEnvelopeInfo.getTransactionActionInfos()) {
						final String methodName = new String(transactionActionInfo.getChaincodeInputArgs(0), UTF_8);

						final List<String> args = new ArrayList<>(transactionActionInfo.getChaincodeInputArgsCount() - 1);
						for (int i = 1; i < transactionActionInfo.getChaincodeInputArgsCount(); i++) {
							args.add(new String(transactionActionInfo.getChaincodeInputArgs(i), UTF_8));
						}

						System.out.printf("--- TRX EVENT: no=%s, trxId=%s, method=%s, args=%s\n",
							blockNumber, transactionID, methodName, args);
					}
				}
			}
		});
	}

	static void createAssetTransientOwner(Contract contract, String id, String color, Integer size, String owner, Integer appraisedValue) throws Exception {
		final Map<String, byte[]> trs = new HashMap<>();
		trs.put("owner", owner.getBytes(UTF_8));

		final Transaction transaction = contract.createTransaction("createAssetTransientOwner");
		transaction.setTransient(trs);
		transaction.submit(id, color, String.valueOf(size), String.valueOf(appraisedValue));
	}

	public static void main(String[] args) {
		// Connect to the network and invoke the smart contract
		try (Gateway gateway = connect()) {

			// get the network and contract
			final Network network = gateway.getNetwork("mychannel");
			registerBlockListener(network);

			final Contract contract = network.getContract("basic");

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

			try {
				System.out.println("\n");
				System.out.println("Submit Transaction: CreateAsset asset100");
				// CreateAsset creates an asset with ID asset13, color yellow, owner Tom, size 5 and appraisedValue of 1300
				createAssetTransientOwner(contract, "asset100", "RED", 10, "SecretOwner", 10);
			} catch (ContractException e) {
				System.out.println("ERROR: " + e.getMessage());
			}

			System.out.println("\n");
			System.out.println("Evaluate Transaction: ReadAsset asset100");
			// ReadAsset returns an asset with given assetID
			result = contract.evaluateTransaction("readAsset", "asset100");
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
