package org.devocative.hlf.iservice;

import org.devocative.hlf.dto.AssetDTO;
import org.devocative.thallo.fabric.gateway.FabricClient;
import org.devocative.thallo.fabric.gateway.Submit;

import java.util.List;

@FabricClient
public interface IAssetTransferClient {
	AssetDTO readAsset(String id);

	boolean assetExists(String id);

	List<AssetDTO.ListItem> getAllAssets();

	@Submit
	void createAsset(String id, String color, Integer size, String owner, Integer appraisedValue);

	@Submit
	void updateAsset(String id, String color, Integer size, String owner, Integer appraisedValue);

	@Submit
	void transferAsset(String id, String newOwner);

	@Submit
	void deleteAsset(String id);
}
