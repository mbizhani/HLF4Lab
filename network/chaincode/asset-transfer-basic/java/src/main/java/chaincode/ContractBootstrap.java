package chaincode;

import lombok.extern.slf4j.Slf4j;
import org.hyperledger.fabric.contract.ContractRouter;
import org.hyperledger.fabric.shim.ChaincodeServer;
import org.hyperledger.fabric.shim.ChaincodeServerProperties;
import org.hyperledger.fabric.shim.NettyChaincodeServer;

import java.io.IOException;
import java.net.InetSocketAddress;

@Slf4j
public class ContractBootstrap {

	public ContractBootstrap() {
		log.info("--- ContractBootstrap . Constructor ---");
	}

	public static void main(String[] args) throws IOException, InterruptedException {
		log.info("--- Contract Bootstrap . Main ---");

		final String serverAddress = System.getenv("CHAINCODE_SERVER_ADDRESS");
		if (serverAddress == null || serverAddress.isEmpty()) {
			throw new IOException("Chaincode Address Not Found: 'CHAINCODE_SERVER_ADDRESS' as env var");
		}
		log.info("--- Contract Bootstrap: serverAddress={}", serverAddress);

		final String chaincodeId = System.getenv("CHAINCODE_ID");
		if (chaincodeId == null || chaincodeId.isEmpty()) {
			throw new IOException("Chaincode ID Not Found: 'CHAINCODE_ID' as env var");
		}
		log.info("--- Contract Bootstrap: chaincodeId={}", chaincodeId);

		final String[] parts = serverAddress.split(":");
		final ChaincodeServerProperties chaincodeServerProperties = new ChaincodeServerProperties();
		chaincodeServerProperties.setServerAddress(new InetSocketAddress(parts[0], Integer.parseInt(parts[1])));

		final ContractRouter contractRouter = new ContractRouter(new String[]{"-i", chaincodeId});
		final ChaincodeServer chaincodeServer = new NettyChaincodeServer(contractRouter, chaincodeServerProperties);
		contractRouter.startRouterWithChaincodeServer(chaincodeServer);
	}
}
