package org.devocative.hlf.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.devocative.hlf.dto.AssetDTO;
import org.devocative.hlf.iservice.IAssetTransferClient;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import java.util.List;
import java.util.UUID;

@RequiredArgsConstructor
@Slf4j
@Service
public class AssetTransferService {
	private final IAssetTransferClient assetTransferClient;

	@PostConstruct
	public void init() {
		final String id = UUID.randomUUID().toString();

		assetTransferClient.createAsset(id, "BLACK", 22, "FOO", 12);
		log.info("AssetExists (created): {}", assetTransferClient.assetExists(id));

		final List<AssetDTO> assets = assetTransferClient.getAllAssets();
		log.info("GetAllAssets: {}", assets);

		final AssetDTO firstItem = assets.get(0);
		log.info("GetAllAssets - FirstItem: {}", firstItem);

		log.info("ReadAsset (created): {}", assetTransferClient.readAsset(id));

		assetTransferClient.updateAsset(id, "BLUE", 10, "FOO", 8);
		log.info("ReadAsset (updated): {}", assetTransferClient.readAsset(id));

		assetTransferClient.transferAsset(id, "BAR");
		log.info("ReadAsset (transferred): {}", assetTransferClient.readAsset(id));

		assetTransferClient.deleteAsset(id);
		log.info("AssetExists (deleted): {}", assetTransferClient.assetExists(id));
	}
}
