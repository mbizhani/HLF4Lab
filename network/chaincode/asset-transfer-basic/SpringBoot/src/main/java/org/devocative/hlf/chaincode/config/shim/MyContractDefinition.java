package org.devocative.hlf.chaincode.config.shim;

import lombok.extern.slf4j.Slf4j;
import org.hyperledger.fabric.contract.Context;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.ContractRuntimeException;
import org.hyperledger.fabric.contract.annotation.Contract;
import org.hyperledger.fabric.contract.annotation.Default;
import org.hyperledger.fabric.contract.routing.ContractDefinition;
import org.hyperledger.fabric.contract.routing.TxFunction;

import java.lang.reflect.Method;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;

@Slf4j
public class MyContractDefinition implements ContractDefinition {
	private final ContractInterface contract;
	private final Map<String, TxFunction> txFunctions = new HashMap<>();
	private final boolean isDefault;
	private final Contract contractAnnotation;
	private final String name;
	private final TxFunction unknownTx;

	public MyContractDefinition(ContractInterface contract) {
		this.contract = contract;
		final Class<? extends ContractInterface> contractClass = contract.getClass();
		final Contract annotation = contractClass.getAnnotation(Contract.class);

		final String annotationName = annotation.name();

		if (annotationName == null || annotationName.isEmpty()) {
			this.name = contractClass.getSimpleName();
		} else {
			this.name = annotationName;
		}

		isDefault = contractClass.isAnnotationPresent(Default.class);
		contractAnnotation = contractClass.getAnnotation(Contract.class);

		try {
			final Method m = contractClass.getMethod("unknownTransaction", Context.class);
			unknownTx = new MyTxFunction(m, contract);
			unknownTx.setUnknownTx(true);
		} catch (NoSuchMethodException | SecurityException e) {
			throw new ContractRuntimeException("Failure to find unknownTransaction method", e);
		}
	}

	@Override
	public String getName() {
		return name;
	}

	@Override
	public Collection<TxFunction> getTxFunctions() {
		return txFunctions.values();
	}

	@Override
	public Class<? extends ContractInterface> getContractImpl() {
		return contract.getClass();
	}

	@Override
	public TxFunction addTxFunction(Method m) {
		final TxFunction txFn = new MyTxFunction(m, contract);
		final TxFunction previousTxnFn = txFunctions.put(txFn.getName(), txFn);
		if (previousTxnFn != null) {
			final String message = String.format("Duplicate transaction method %s", previousTxnFn.getName());
			throw new ContractRuntimeException(message);
		}
		return txFn;
	}

	@Override
	public boolean isDefault() {
		return isDefault;
	}

	@Override
	public TxFunction getTxFunction(String method) {
		return txFunctions.get(method);
	}

	@Override
	public boolean hasTxFunction(String method) {
		return txFunctions.containsKey(method);
	}

	@Override
	public TxFunction getUnknownRoute() {
		return unknownTx;
	}

	@Override
	public Contract getAnnotation() {
		return contractAnnotation;
	}
}
