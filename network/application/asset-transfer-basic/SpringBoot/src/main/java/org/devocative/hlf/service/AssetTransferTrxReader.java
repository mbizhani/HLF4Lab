package org.devocative.hlf.service;

import lombok.extern.slf4j.Slf4j;
import org.devocative.thallo.hlf.iservice.IHlfTransactionReader;
import org.devocative.thallo.hlf.service.HlfTransactionReaderHandler;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class AssetTransferTrxReader implements IHlfTransactionReader {

	@Override
	public void handleTransaction(HlfTransactionReaderHandler handler) {
		handler.readBlockFrom(0, info -> log.info("OldBlock: {}", info));

		handler.registerBlockListener(info -> log.info("NewBlock: {}", info));
	}

}
