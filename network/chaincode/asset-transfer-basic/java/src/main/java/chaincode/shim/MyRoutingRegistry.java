package chaincode.shim;

import lombok.extern.slf4j.Slf4j;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.ContractRuntimeException;
import org.hyperledger.fabric.contract.annotation.Transaction;
import org.hyperledger.fabric.contract.execution.InvocationRequest;
import org.hyperledger.fabric.contract.routing.ContractDefinition;
import org.hyperledger.fabric.contract.routing.RoutingRegistry;
import org.hyperledger.fabric.contract.routing.TxFunction;
import org.hyperledger.fabric.contract.routing.TypeRegistry;

import java.lang.reflect.Method;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;

@Slf4j
public class MyRoutingRegistry implements RoutingRegistry {
	private final Map<String, ContractDefinition> contracts = new HashMap<>();

	@Override
	public ContractDefinition addNewContract(Class<ContractInterface> clz) {
		log.info("Adding new Contract Class " + clz.getCanonicalName());

		// TIP: find bean with class clz
		final ContractDefinition contractDefinition = new MyContractDefinition(create(clz));

		contracts.put(contractDefinition.getName(), contractDefinition);

		if (contractDefinition.isDefault()) {
			contracts.put(InvocationRequest.DEFAULT_NAMESPACE, contractDefinition);
		}

		for (final Method m : clz.getMethods()) {
			if (m.getAnnotation(Transaction.class) != null) {
				contractDefinition.addTxFunction(m);
				log.info("Contract Method Added: [{}.{}]", contractDefinition.getName(), m.getName());
			}
		}

		return contractDefinition;
	}

	@Override
	public boolean containsRoute(InvocationRequest request) {
		if (contracts.containsKey(request.getNamespace())) {
			final ContractDefinition cd = contracts.get(request.getNamespace());
			return cd.hasTxFunction(request.getMethod());
		}
		return false;
	}

	@Override
	public TxFunction.Routing getRoute(InvocationRequest request) {
		final TxFunction txFunction = contracts.get(request.getNamespace()).getTxFunction(request.getMethod());
		return txFunction.getRouting();
	}

	@Override
	public TxFunction getTxFn(InvocationRequest request) {
		return contracts.get(request.getNamespace()).getTxFunction(request.getMethod());
	}

	@Override
	public ContractDefinition getContract(String namespace) {
		final ContractDefinition contract = contracts.get(namespace);

		if (contract == null) {
			throw new ContractRuntimeException("Undefined contract called");
		}

		return contract;
	}

	@Override
	public Collection<ContractDefinition> getAllDefinitions() {
		return contracts.values();
	}

	@Override
	public void findAndSetContracts(TypeRegistry typeRegistry) {
		throw new RuntimeException("MyRoutingRegistry.findAndSetContracts Not Impl");
	}

	// ------------------------------

	public ContractInterface create(Class<? extends ContractInterface> cls) {
		try {
			return cls.getDeclaredConstructor().newInstance();
		} catch (Exception e) {
			throw new ContractRuntimeException(e);
		}
	}
}
