package org.devocative.hlf.chaincode.config.shim;

import lombok.extern.slf4j.Slf4j;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.ContractRuntimeException;
import org.hyperledger.fabric.contract.annotation.Serializer;
import org.hyperledger.fabric.contract.execution.ExecutionFactory;
import org.hyperledger.fabric.contract.execution.ExecutionService;
import org.hyperledger.fabric.contract.execution.InvocationRequest;
import org.hyperledger.fabric.contract.execution.SerializerInterface;
import org.hyperledger.fabric.contract.metadata.MetadataBuilder;
import org.hyperledger.fabric.contract.routing.ContractDefinition;
import org.hyperledger.fabric.contract.routing.RoutingRegistry;
import org.hyperledger.fabric.contract.routing.TxFunction;
import org.hyperledger.fabric.contract.routing.TypeRegistry;
import org.hyperledger.fabric.metrics.Metrics;
import org.hyperledger.fabric.shim.ChaincodeBase;
import org.hyperledger.fabric.shim.ChaincodeStub;
import org.hyperledger.fabric.shim.ResponseUtils;
import org.hyperledger.fabric.traces.Traces;
import org.springframework.context.ApplicationContext;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;
import java.util.Map;
import java.util.Properties;

@Slf4j
@Component
public class MyChaincodeBase extends ChaincodeBase {
	private final RoutingRegistry registry;
	private final MySerializerRegistry serializers;
	private final ApplicationContext context;

	private final String chaincodeId;

	// ------------------------------

	public MyChaincodeBase(RoutingRegistry registry, MySerializerRegistry serializers, ApplicationContext context) {
		this.registry = registry;
		this.context = context;
		this.serializers = serializers;

		chaincodeId = System.getenv("CHAINCODE_ID");
		if (chaincodeId == null || chaincodeId.isEmpty()) {
			throw new RuntimeException("Chaincode ID Not Found: 'CHAINCODE_ID' as env var");
		}
		log.info("--- MyChaincodeBase - chaincodeId={}", chaincodeId);
	}

	// ------------------------------

	@PostConstruct
	public void init() {
		super.initializeLogging();
		super.processEnvironmentOptions();
		super.processCommandLineOptions(new String[]{"-i", chaincodeId});
		super.validateOptions();

		final Properties props = super.getChaincodeConfig();
		Metrics.initialize(props);
		Traces.initialize(props);

		final Map<String, ContractInterface> contracts = context.getBeansOfType(ContractInterface.class);
		contracts.values().forEach(contractInterface -> {
			final Class<? extends ContractInterface> cls = contractInterface.getClass();
			log.info("--- MyChaincodeBase.ContractInterface Bean: {}", cls.getName());
			registry.addNewContract((Class<ContractInterface>) cls);
		});

		try {
			serializers.findAndSetContents();
		} catch (InstantiationException | IllegalAccessException e) {
			log.error("MyChaincodeBase", e);
			throw new ContractRuntimeException("Unable to locate Serializers", e);
		}

		final TypeRegistry typeRegistry = TypeRegistry.getRegistry();
		registry.findAndSetContracts(typeRegistry);
		MetadataBuilder.initialize(registry, typeRegistry);
		log.info("Metadata follows: {}", MetadataBuilder.debugString());
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
				log.info("Got the Invoke Request: func = {}({})", stub.getFunction(), stub.getParameters());
				final InvocationRequest request = ExecutionFactory.getInstance().createRequest(stub);
				final TxFunction txFn = getRouting(request);

				final SerializerInterface si = serializers.getSerializer(txFn.getRouting().getSerializerName(),
					Serializer.TARGET.TRANSACTION);
				final ExecutionService executor = ExecutionFactory.getInstance().createExecutionService(si);

				log.info("Got Routing: {}", txFn.getRouting());
				return executor.executeRequest(txFn, request, stub);
			} else {
				return ResponseUtils.newSuccessResponse();
			}
		} catch (final Throwable throwable) {
			return ResponseUtils.newErrorResponse(throwable);
		}
	}

	private TxFunction getRouting(final InvocationRequest request) {
		if (registry.containsRoute(request)) {
			return registry.getTxFn(request);
		} else {
			log.info("Namespace: {}", request.getNamespace());
			final ContractDefinition contract = registry.getContract(request.getNamespace());
			return contract.getUnknownRoute();
		}
	}
}
