package org.devocative.hlf.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.devocative.hlf.dto.AssetDTO;
import org.devocative.hlf.iservice.IAssetTransferClient;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import java.util.List;

@RequiredArgsConstructor
@Slf4j
@Service
public class AssetTransferService {
	private final IAssetTransferClient assetTransferClient;

	@PostConstruct
	public void init() {
		final List<AssetDTO.ListItem> assets = assetTransferClient.getAllAssets();
		log.info("GetAllAssets: {}", assets);
		log.info("GetAllAssets: {} - {}", assets.get(0).getKey(), assets.get(0).getRecord().getId());
		log.info("ReadAsset: {}", assetTransferClient.readAsset("asset1"));
	}
}
