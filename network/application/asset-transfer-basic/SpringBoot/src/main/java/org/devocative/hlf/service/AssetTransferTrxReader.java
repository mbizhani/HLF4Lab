package org.devocative.hlf.service;

import lombok.extern.slf4j.Slf4j;
import org.devocative.thallo.hlf.dto.HlfTransactionInfo;
import org.devocative.thallo.hlf.iservice.IHlfTransactionReader;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class AssetTransferTrxReader implements IHlfTransactionReader {
	@Override
	public void handleTransaction(HlfTransactionInfo info) {
		log.info("## Asset Info in Ledger: {}", info);
	}
}
