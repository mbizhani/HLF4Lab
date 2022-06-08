package org.devocative.hlf.chaincode;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.devocative.hlf.chaincode.model.Asset;
import org.hyperledger.fabric.contract.ClientIdentity;
import org.hyperledger.fabric.contract.Context;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.annotation.Contract;
import org.hyperledger.fabric.contract.annotation.Default;
import org.hyperledger.fabric.contract.annotation.Transaction;
import org.hyperledger.fabric.shim.ChaincodeException;
import org.hyperledger.fabric.shim.ChaincodeStub;
import org.hyperledger.fabric.shim.ledger.KeyValue;
import org.hyperledger.fabric.shim.ledger.QueryResultsIterator;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Slf4j
@Default
@Contract(name = "basic")
@Component
public class AssetTransferContract implements ContractInterface {
	private final ObjectMapper mapper = new ObjectMapper();

	private enum AssetTransferErrors {
		ASSET_NOT_FOUND,
		ASSET_ALREADY_EXISTS
	}

	public AssetTransferContract() {
		log.info("--- AssetTransferContract Constructor ---");
	}

	@Override
	public void beforeTransaction(Context ctx) {
		final ChaincodeStub stub = ctx.getStub();
		final ClientIdentity clientIdentity = ctx.getClientIdentity();

		log.info("--- B4: func=[{}], params={}, mspId=[{}], clientCert.subject=[{}], clientCert.issuer=[{}]",
			stub.getFunction(),
			stub.getParameters(),
			//stub.getMspId(), TIP: RuntimeException: CORE_PEER_LOCALMSPID is unset in chaincode process
			//new String(stub.getCreator()), TIP: not useful, value= mspId + cert
			clientIdentity.getMSPID(),
			clientIdentity.getX509Certificate().getSubjectX500Principal(),
			clientIdentity.getX509Certificate().getIssuerX500Principal()
		);

		if (stub.getFunction().equals("createAsset") && stub.getParameters().get(0).equals("asset13")) {
			throw new RuntimeException("Invalid Asset");
		}
	}

	@Transaction(intent = Transaction.TYPE.SUBMIT)
	public void initLedger(final Context ctx) {
		createAsset(ctx, "asset1", "blue", 5, "Tomoko", 300);
		createAsset(ctx, "asset2", "red", 5, "Brad", 400);
		createAsset(ctx, "asset3", "green", 10, "Jin Soo", 500);
		createAsset(ctx, "asset4", "yellow", 10, "Max", 600);
		createAsset(ctx, "asset5", "black", 15, "Adrian", 700);
		createAsset(ctx, "asset6", "white", 15, "Michel", 700);
	}

	@Transaction(intent = Transaction.TYPE.SUBMIT)
	public void createAssetTransientOwner(final Context ctx, final String assetID, final String color, final int size,
	                                      final int appraisedValue) {
		final ChaincodeStub stub = ctx.getStub();
		final Map<String, byte[]> transientMap = stub.getTransient();
		if (!transientMap.containsKey("owner")) {
			String errorMessage = "Transient Not Found: key = 'owner'";
			log.error(errorMessage);
			throw new ChaincodeException(errorMessage, AssetTransferErrors.ASSET_ALREADY_EXISTS.toString());
		}
		final String owner = new String(transientMap.get("owner"));

		createAsset(ctx, assetID, color, size, owner, appraisedValue);
	}

	@Transaction(intent = Transaction.TYPE.SUBMIT)
	public void createAsset(final Context ctx, final String assetID, final String color, final int size,
	                        final String owner, final int appraisedValue) {
		final ChaincodeStub stub = ctx.getStub();

		if (assetExists(ctx, assetID)) {
			String errorMessage = String.format("Asset %s already exists", assetID);
			log.error(errorMessage);
			throw new ChaincodeException(errorMessage, AssetTransferErrors.ASSET_ALREADY_EXISTS.toString());
		}

		final Asset asset = new Asset(assetID, color, size, owner, appraisedValue);
		final String assetJSON = serialize(asset);
		stub.putStringState(assetID, assetJSON);
	}

	@Transaction(intent = Transaction.TYPE.EVALUATE)
	public Asset readAsset(final Context ctx, final String assetID) {
		final ChaincodeStub stub = ctx.getStub();
		final String assetJSON = stub.getStringState(assetID);

		if (assetJSON == null || assetJSON.isEmpty()) {
			String errorMessage = String.format("Asset %s does not exist", assetID);
			log.error(errorMessage);
			throw new ChaincodeException(errorMessage, AssetTransferErrors.ASSET_NOT_FOUND.toString());
		}

		return deserialize(assetJSON, Asset.class);
	}

	@Transaction(intent = Transaction.TYPE.SUBMIT)
	public void updateAsset(final Context ctx, final String assetID, final String color, final int size,
	                        final String owner, final int appraisedValue) {
		final ChaincodeStub stub = ctx.getStub();

		if (!assetExists(ctx, assetID)) {
			String errorMessage = String.format("Asset %s does not exist", assetID);
			log.error(errorMessage);
			throw new ChaincodeException(errorMessage, AssetTransferErrors.ASSET_NOT_FOUND.toString());
		}

		Asset newAsset = new Asset(assetID, color, size, owner, appraisedValue);
		String newAssetJSON = serialize(newAsset);
		stub.putStringState(assetID, newAssetJSON);
	}

	@Transaction(intent = Transaction.TYPE.SUBMIT)
	public void deleteAsset(final Context ctx, final String assetID) {
		ChaincodeStub stub = ctx.getStub();

		if (!assetExists(ctx, assetID)) {
			String errorMessage = String.format("Asset %s does not exist", assetID);
			System.out.println(errorMessage);
			throw new ChaincodeException(errorMessage, AssetTransferErrors.ASSET_NOT_FOUND.toString());
		}

		stub.delState(assetID);
	}

	@Transaction(intent = Transaction.TYPE.EVALUATE)
	public boolean assetExists(final Context ctx, final String assetID) {
		ChaincodeStub stub = ctx.getStub();
		String assetJSON = stub.getStringState(assetID);

		return (assetJSON != null && !assetJSON.isEmpty());
	}

	@Transaction(intent = Transaction.TYPE.SUBMIT)
	public Asset transferAsset(final Context ctx, final String assetID, final String newOwner) {
		ChaincodeStub stub = ctx.getStub();
		String assetJSON = stub.getStringState(assetID);

		if (assetJSON == null || assetJSON.isEmpty()) {
			String errorMessage = String.format("Asset %s does not exist", assetID);
			System.out.println(errorMessage);
			throw new ChaincodeException(errorMessage, AssetTransferErrors.ASSET_NOT_FOUND.toString());
		}

		Asset asset = deserialize(assetJSON, Asset.class);

		Asset newAsset = new Asset(asset.getAssetID(), asset.getColor(), asset.getSize(), newOwner, asset.getAppraisedValue());
		String newAssetJSON = serialize(newAsset);
		stub.putStringState(assetID, newAssetJSON);

		return newAsset;
	}

	@Transaction(intent = Transaction.TYPE.EVALUATE)
	public String getAllAssets(final Context ctx) {
		ChaincodeStub stub = ctx.getStub();

		List<Asset> queryResults = new ArrayList<>();

		// To retrieve all assets from the ledger use getStateByRange with empty startKey & endKey.
		// Giving empty startKey & endKey is interpreted as all the keys from beginning to end.
		// As another example, if you use startKey = 'asset0', endKey = 'asset9' ,
		// then getStateByRange will retrieve asset with keys between asset0 (inclusive) and asset9 (exclusive) in lexical order.
		QueryResultsIterator<KeyValue> results = stub.getStateByRange("", "");

		for (KeyValue result : results) {
			Asset asset = deserialize(result.getStringValue(), Asset.class);
			queryResults.add(asset);
			System.out.println(asset.toString());
		}

		return serialize(queryResults);
	}

	// ------------------------------

	private String serialize(Object obj) {
		try {
			return mapper.writeValueAsString(obj);
		} catch (JsonProcessingException e) {
			throw new RuntimeException(e);
		}
	}

	private <T> T deserialize(String json, Class<T> cls) {
		try {
			return mapper.readValue(json, cls);
		} catch (JsonProcessingException e) {
			throw new RuntimeException(e);
		}
	}
}
