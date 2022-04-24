package chaincode.shim;

import org.hyperledger.fabric.contract.Context;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.ContractRuntimeException;
import org.hyperledger.fabric.contract.annotation.Contract;
import org.hyperledger.fabric.contract.annotation.Property;
import org.hyperledger.fabric.contract.annotation.Transaction;
import org.hyperledger.fabric.contract.metadata.TypeSchema;
import org.hyperledger.fabric.contract.routing.ParameterDefinition;
import org.hyperledger.fabric.contract.routing.TransactionType;
import org.hyperledger.fabric.contract.routing.TxFunction;
import org.hyperledger.fabric.contract.routing.impl.ParameterDefinitionImpl;

import java.lang.reflect.Method;
import java.lang.reflect.Parameter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class MyTxFunction implements TxFunction {
	private final String name;
	private final Method method;
	private final Routing routing;

	private TransactionType type;
	private TypeSchema returnSchema;
	private List<ParameterDefinition> paramsList;
	private boolean isUnknownTx = false;

	public MyTxFunction(Method method, ContractInterface contract) {
		this.method = method;

		String name = null;
		if (method.getAnnotation(Transaction.class) != null) {
			if (method.getAnnotation(Transaction.class).intent() == Transaction.TYPE.SUBMIT) {
				this.type = TransactionType.SUBMIT;
			} else {
				this.type = TransactionType.EVALUATE;
			}

			final String txnName = method.getAnnotation(Transaction.class).name();
			if (!txnName.isEmpty()) {
				name = txnName;
			}
		}

		this.name = name != null ? name : method.getName();
		this.routing = new MyRouting(method, contract);
		this.returnSchema = TypeSchema.typeConvert(method.getReturnType());

		populateParams();
	}

	@Override
	public boolean isUnknownTx() {
		return isUnknownTx;
	}

	@Override
	public void setUnknownTx(boolean unknown) {
		isUnknownTx = unknown;
	}

	@Override
	public String getName() {
		return name;
	}

	@Override
	public Routing getRouting() {
		return routing;
	}

	@Override
	public Class<?> getReturnType() {
		return method.getReturnType();
	}

	@Override
	public Parameter[] getParameters() {
		return method.getParameters();
	}

	@Override
	public TransactionType getType() {
		return type;
	}

	@Override
	public void setReturnSchema(TypeSchema returnSchema) {
		this.returnSchema = returnSchema;
	}

	@Override
	public TypeSchema getReturnSchema() {
		return returnSchema;
	}

	@Override
	public void setParameterDefinitions(List<ParameterDefinition> list) {
		paramsList = list;
	}

	@Override
	public List<ParameterDefinition> getParamsList() {
		return paramsList;
	}

	// ------------------------------

	private void populateParams() {
		paramsList = new ArrayList<>();

		final List<java.lang.reflect.Parameter> params = new ArrayList<>(Arrays.asList(method.getParameters()));

		// validate the first one is a context object
		if (params.size() == 0) {
			throw new ContractRuntimeException("First argument should be of type Context");
		} else if (!Context.class.isAssignableFrom(params.get(0).getType())) {
			throw new ContractRuntimeException(
				"First argument should be of type Context " + method.getName() + " " + params.get(0).getType());
		} else {

			params.remove(0);
		}

		for (final java.lang.reflect.Parameter parameter : params) {
			final TypeSchema paramMap = new TypeSchema();
			final TypeSchema schema = TypeSchema.typeConvert(parameter.getType());

			final Property annotation = parameter.getAnnotation(org.hyperledger.fabric.contract.annotation.Property.class);
			if (annotation != null) {
				final String[] userSupplied = annotation.schema();
				for (int i = 0; i < userSupplied.length; i += 2) {
					schema.put(userSupplied[i], userSupplied[i + 1]);
				}
			}

			paramMap.put("name", parameter.getName());
			paramMap.put("schema", schema);
			final ParameterDefinition pd = new ParameterDefinitionImpl(parameter.getName(), parameter.getClass(), paramMap,
				parameter);
			paramsList.add(pd);
		}
	}

	// ------------------------------

	public static class MyRouting implements Routing {
		private final Method method;
		private final ContractInterface contract;
		private final String serializerName;

		public MyRouting(final Method method, final ContractInterface contract) {
			this.method = method;
			this.contract = contract;
			this.serializerName = contract.getClass()
				.getAnnotation(Contract.class)
				.transactionSerializer();
		}

		@Override
		public Method getMethod() {
			return method;
		}

		@Override
		public Class<? extends ContractInterface> getContractClass() {
			return contract.getClass();
		}

		@Override
		public ContractInterface getContractInstance() {
			return contract;
		}

		@Override
		public String toString() {
			return method.getName() + ":" + getContractClass().getCanonicalName();
		}

		@Override
		public String getSerializerName() {
			return serializerName;
		}
	}
}
