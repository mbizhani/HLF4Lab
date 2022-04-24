package chaincode.shim;

import chaincode.AssetTransferContract;
import lombok.extern.slf4j.Slf4j;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.ContractRuntimeException;
import org.hyperledger.fabric.contract.annotation.Serializer;
import org.hyperledger.fabric.contract.execution.ExecutionFactory;
import org.hyperledger.fabric.contract.execution.ExecutionService;
import org.hyperledger.fabric.contract.execution.InvocationRequest;
import org.hyperledger.fabric.contract.execution.SerializerInterface;
import org.hyperledger.fabric.contract.routing.ContractDefinition;
import org.hyperledger.fabric.contract.routing.RoutingRegistry;
import org.hyperledger.fabric.contract.routing.TxFunction;
import org.hyperledger.fabric.contract.routing.impl.SerializerRegistryImpl;
import org.hyperledger.fabric.metrics.Metrics;
import org.hyperledger.fabric.shim.ChaincodeBase;
import org.hyperledger.fabric.shim.ChaincodeStub;
import org.hyperledger.fabric.shim.ResponseUtils;
import org.hyperledger.fabric.traces.Traces;

import java.util.Properties;

@Slf4j
public class MyChaincodeBase extends ChaincodeBase {
	private final SerializerRegistryImpl serializers;
	private final RoutingRegistry registry;

	public MyChaincodeBase(String chaincodeId) {
		super.initializeLogging();
		super.processEnvironmentOptions();
		super.processCommandLineOptions(new String[]{"-i", chaincodeId});
		super.validateOptions();

		final Properties props = super.getChaincodeConfig();
		Metrics.initialize(props);
		Traces.initialize(props);

		final Class<? extends ContractInterface> cls = AssetTransferContract.class;

		registry = new MyRoutingRegistry();

		// TIP: find all beans implementing ContractInterface
		registry.addNewContract((Class<ContractInterface>) cls);

		serializers = new SerializerRegistryImpl();

		try {
			serializers.findAndSetContents();
		} catch (InstantiationException | IllegalAccessException e) {
			log.error("MyChaincodeBase", e);
			throw new ContractRuntimeException("Unable to locate Serializers", e);
		}
	}

	@Override
	public Response init(ChaincodeStub stub) {
		return processRequest(stub);
	}

	@Override
	public Response invoke(ChaincodeStub stub) {
		return processRequest(stub);
	}

	// ------------------------------

	private Response processRequest(final ChaincodeStub stub) {
		log.info("Got invoke routing request");
		try {
			if (stub.getStringArgs().size() > 0) {
				log.info("Got the invoke request for:" + stub.getFunction() + " " + stub.getParameters());
				final InvocationRequest request = ExecutionFactory.getInstance().createRequest(stub);
				final TxFunction txFn = getRouting(request);

				final SerializerInterface si = serializers.getSerializer(txFn.getRouting().getSerializerName(),
					Serializer.TARGET.TRANSACTION);
				final ExecutionService executor = ExecutionFactory.getInstance().createExecutionService(si);

				log.info("Got routing:" + txFn.getRouting());
				return executor.executeRequest(txFn, request, stub);
			} else {
				return ResponseUtils.newSuccessResponse();
			}
		} catch (final Throwable throwable) {
			return ResponseUtils.newErrorResponse(throwable);
		}
	}

	TxFunction getRouting(final InvocationRequest request) {
		if (registry.containsRoute(request)) {
			return registry.getTxFn(request);
		} else {
			log.info("Namespace is " + request);
			final ContractDefinition contract = registry.getContract(request.getNamespace());
			return contract.getUnknownRoute();
		}
	}
}
