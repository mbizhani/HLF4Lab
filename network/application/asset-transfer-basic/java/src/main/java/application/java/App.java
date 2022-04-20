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
	static final String WALLET_PATH = "OUT/wallet";
	static final String USER = "backend";
	static final String PASS = "backendPw";

	static int counter = -1;

	static Gateway connect(String orgId) throws Exception {
		final Wallet wallet = EnrollAdmin.enroll(orgId, WALLET_PATH, USER, PASS);

		final Path networkConfigPath = Paths.get(String.format("OUT/organizations/peerOrganizations/%1$s.example.com/connection-%1$s.yaml", orgId));

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

	static void run(String orgId) {
		counter++;
		System.out.println("counter = " + counter);

		try (Gateway gateway = connect(orgId)) {

			// get the network and contract
			final Network network = gateway.getNetwork("mychannel");
			registerBlockListener(network);

			final Contract contract = network.getContract("basic");

			byte[] result;

			System.out.println("\n");
			result = contract.evaluateTransaction("getAllAssets");
			System.out.println("Evaluate Transaction: GetAllAssets, result: " + new String(result));

			try {
				final String assetId = "asset" + (13 + counter);
				System.out.println("\n");
				System.out.println("Submit Transaction: CreateAsset " + assetId);
				contract.submitTransaction("createAsset", assetId, "yellow", "5", "Tom", "1300");
			} catch (ContractException e) {
				System.out.println("ERROR: " + e.getMessage());
			}

			try {
				final String assetId = "asset" + (100 + counter);
				System.out.println("\n");
				System.out.println("Submit Transaction with Transient: CreateAsset " + assetId);
				createAssetTransientOwner(contract, assetId, "RED", 10 + counter, "SecretOwner", 10 + counter);
			} catch (ContractException e) {
				System.out.println("ERROR: " + e.getMessage());
			}

			System.out.println("\n");
			System.out.println("Evaluate Transaction: ReadAsset asset100");
			result = contract.evaluateTransaction("readAsset", "asset" + (100 + counter));
			System.out.println("Result: " + new String(result));

			System.out.println("\n");
			System.out.println("Evaluate Transaction: AssetExists asset1");
			result = contract.evaluateTransaction("assetExists", "asset1");
			System.out.println("result: " + new String(result));

			System.out.println("\n");
			System.out.println("Submit Transaction: UpdateAsset asset1, new AppraisedValue : 350");
			contract.submitTransaction("updateAsset", "asset1", "blue", "5", "Tomoko", "350");

			System.out.println("\n");
			System.out.println("Evaluate Transaction: ReadAsset asset1");
			result = contract.evaluateTransaction("readAsset", "asset1");
			System.out.println("result: " + new String(result));

			try {
				System.out.println("\n");
				System.out.println("Submit Transaction: UpdateAsset asset70");
				contract.submitTransaction("updateAsset", "asset70", "blue", "5", "Tomoko", "300");
			} catch (ContractException e) {
				System.out.println("ERROR: Expected an error on UpdateAsset of non-existing Asset: " + e);
			}

			System.out.println("\n");
			System.out.println("Submit Transaction: TransferAsset asset1 from owner Tomoko > owner Tom");
			contract.submitTransaction("transferAsset", "asset1", "Tom");

			System.out.println("\n");
			System.out.println("Evaluate Transaction: ReadAsset asset1");
			result = contract.evaluateTransaction("readAsset", "asset1");
			System.out.println("result: " + new String(result));
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	public static void main(String[] args) {
		run("org1");
		run("org2");
	}
}
