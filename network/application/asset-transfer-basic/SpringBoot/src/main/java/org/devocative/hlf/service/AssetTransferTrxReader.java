package org.devocative.hlf.service;

import lombok.extern.slf4j.Slf4j;
import org.devocative.thallo.fabric.gateway.iservice.IFabricTransactionReader;
import org.devocative.thallo.fabric.gateway.service.FabricTransactionReaderHandler;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class AssetTransferTrxReader implements IFabricTransactionReader {

	@Override
	public void handleTransaction(FabricTransactionReaderHandler handler) {
		handler.readBlockFrom(0, info -> log.info("OldBlock: {}", info));

		handler.registerBlockListener(info -> log.info("NewBlock: {}", info));
	}

}
