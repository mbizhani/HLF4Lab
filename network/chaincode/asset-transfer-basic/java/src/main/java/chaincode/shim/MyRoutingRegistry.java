package chaincode.shim;

import io.github.classgraph.ClassGraph;
import io.github.classgraph.ClassInfo;
import io.github.classgraph.ScanResult;
import lombok.extern.slf4j.Slf4j;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.ContractRuntimeException;
import org.hyperledger.fabric.contract.annotation.DataType;
import org.hyperledger.fabric.contract.annotation.Transaction;
import org.hyperledger.fabric.contract.execution.InvocationRequest;
import org.hyperledger.fabric.contract.routing.ContractDefinition;
import org.hyperledger.fabric.contract.routing.RoutingRegistry;
import org.hyperledger.fabric.contract.routing.TxFunction;
import org.hyperledger.fabric.contract.routing.TypeRegistry;

import java.lang.reflect.Method;
import java.util.*;

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
		final ClassGraph classGraph = new ClassGraph()
			.enableClassInfo()
			.enableAnnotationInfo();

		final List<Class<?>> dataTypeClasses = new ArrayList<>();
		try (ScanResult scanResult = classGraph.scan()) {
			for (final ClassInfo classInfo : scanResult.getClassesWithAnnotation(DataType.class.getCanonicalName())) {
				log.debug("Found class with @DataType: {}", classInfo.getName());
				try {
					final Class<?> dataTypeClass = classInfo.loadClass();
					final DataType annotation = dataTypeClass.getAnnotation(DataType.class);
					if (annotation != null) {
						dataTypeClasses.add(dataTypeClass);
					}
				} catch (final IllegalArgumentException e) {
					log.warn("Failed to load @DataType class: {}", classInfo.getName(), e);
				}
			}
		}

		dataTypeClasses.forEach(typeRegistry::addDataType);
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
