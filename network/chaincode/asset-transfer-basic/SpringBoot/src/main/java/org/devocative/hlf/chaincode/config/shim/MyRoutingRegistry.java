package org.devocative.hlf.chaincode.config.shim;

import lombok.RequiredArgsConstructor;
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
import org.springframework.context.ApplicationContext;
import org.springframework.stereotype.Component;

import java.lang.reflect.Method;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@RequiredArgsConstructor
@Component
public class MyRoutingRegistry implements RoutingRegistry {
	private final Map<String, ContractDefinition> contracts = new HashMap<>();

	private final ApplicationContext context;

	// ------------------------------

	@Override
	public ContractDefinition addNewContract(Class<ContractInterface> clz) {
		log.info("Adding new Contract Class " + clz.getCanonicalName());

		final ContractInterface contractInterface = context.getBean(clz);
		final ContractDefinition contractDefinition = new MyContractDefinition(contractInterface);

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
		final List<String> basePackages = ClassUtil.findBasePackages(context);

		log.info("Scan for @DataType: basePackage = {}", basePackages);

		ClassUtil.scanPackagesForAnnotatedClasses(DataType.class, basePackages, beanDefinition -> {
			try {
				final Class<?> beanClass = Class.forName(beanDefinition.getBeanClassName());
				typeRegistry.addDataType(beanClass);
				log.info("Register @DataType: {}", beanClass.getName());
			} catch (ClassNotFoundException e) {
				log.warn("@DataType Class Not Found: {}", beanDefinition.getBeanClassName(), e);
			}
		});
	}
}
