package org.devocative.hlf.chaincode.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.hyperledger.fabric.shim.ChaincodeBase;
import org.hyperledger.fabric.shim.ChaincodeServer;
import org.hyperledger.fabric.shim.ChaincodeServerProperties;
import org.hyperledger.fabric.shim.NettyChaincodeServer;
import org.springframework.boot.context.event.ApplicationStartedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.stereotype.Component;

import javax.annotation.PreDestroy;
import java.net.InetSocketAddress;

@Slf4j
@RequiredArgsConstructor
@EnableAsync
@Component
public class BootstrapChaincodeServer {
	private final ChaincodeBase chaincodeBase;

	private ChaincodeServer chaincodeServer;

	// ------------------------------

	@Async
	@EventListener(ApplicationStartedEvent.class)
	public void init() {
		log.info("--- BootstrapChaincodeServer ---");

		final String serverAddress = System.getenv("CHAINCODE_SERVER_ADDRESS");
		if (serverAddress == null || serverAddress.isEmpty()) {
			throw new RuntimeException("Chaincode Address Not Found: 'CHAINCODE_SERVER_ADDRESS' as env var");
		}
		log.info("--- BootstrapChaincodeServer - serverAddress={}", serverAddress);

		final String[] parts = serverAddress.split(":");
		final ChaincodeServerProperties chaincodeServerProperties = new ChaincodeServerProperties();
		chaincodeServerProperties.setServerAddress(new InetSocketAddress(parts[0], Integer.parseInt(parts[1])));

		try {
			chaincodeServer = new NettyChaincodeServer(chaincodeBase, chaincodeServerProperties);
			chaincodeServer.start();
		} catch (Exception e) {
			throw new RuntimeException(e);
		}
	}

	@PreDestroy
	public void shutdown() {
		if (chaincodeServer != null) {
			log.info("--- BootstrapChaincodeServer - Shutting Down Chaincode Server");
			chaincodeServer.stop();
		}
	}

}
