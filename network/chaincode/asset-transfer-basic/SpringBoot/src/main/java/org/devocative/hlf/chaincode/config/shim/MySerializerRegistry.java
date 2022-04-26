package org.devocative.hlf.chaincode.config.shim;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.hyperledger.fabric.contract.annotation.Serializer;
import org.hyperledger.fabric.contract.execution.SerializerInterface;
import org.springframework.context.ApplicationContext;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@RequiredArgsConstructor
@Component
public class MySerializerRegistry {
	private final Map<String, SerializerInterface> contents = new HashMap<>();
	private final Class<Serializer> annotationClass = Serializer.class;

	private final ApplicationContext context;

	// ------------------------------

	public SerializerInterface getSerializer(final String name, final Serializer.TARGET target) {
		final String key = name + ":" + target;
		return contents.get(key);
	}

	public void findAndSetContents() throws InstantiationException, IllegalAccessException {

		final List<String> basePackages = ClassUtil.findBasePackages(context);
		basePackages.add("org.hyperledger.fabric.contract");

		log.info("Scan for @{}: basePackage = {}", annotationClass.getSimpleName(), basePackages);

		ClassUtil.scanPackagesForAnnotatedClasses(annotationClass, basePackages, beanDefinition -> {
			try {
				final Class<? extends SerializerInterface> cls = (Class<? extends SerializerInterface>) Class.forName(beanDefinition.getBeanClassName());
				log.info("MySerializerRegistry - SerializerInterface = {}", cls.getName());
				add(cls.getName(), Serializer.TARGET.TRANSACTION, cls);
			} catch (ClassNotFoundException e) {
				log.warn("@{} Class Not Found: {}",
					annotationClass.getSimpleName(), beanDefinition.getBeanClassName(), e);
			}
		});
	}

	// ------------------------------

	private void add(final String name, final Serializer.TARGET target, final Class<? extends SerializerInterface> clazz) {
		log.debug("Adding new Class [{}] for [{}]", clazz.getName(), target);

		try {
			final String key = name + ":" + target;
			final SerializerInterface newObj = clazz.getDeclaredConstructor().newInstance();
			contents.put(key, newObj);
		} catch (Exception e) {
			throw new RuntimeException(e);
		}
	}
}
