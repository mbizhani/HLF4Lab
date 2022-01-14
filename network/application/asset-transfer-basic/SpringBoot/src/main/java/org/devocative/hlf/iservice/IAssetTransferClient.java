package org.devocative.hlf.iservice;

import org.devocative.hlf.dto.AssetDTO;
import org.devocative.thallo.hlf.HlfClient;

import java.util.List;

@HlfClient
public interface IAssetTransferClient {
	AssetDTO readAsset(String id);

	List<AssetDTO.ListItem> getAllAssets();
}
