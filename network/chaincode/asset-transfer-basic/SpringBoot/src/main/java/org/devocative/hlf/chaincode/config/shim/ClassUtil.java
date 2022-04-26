package org.devocative.hlf.chaincode.config.shim;

import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.filter.AnnotationTypeFilter;

import java.lang.annotation.Annotation;
import java.util.*;
import java.util.function.Consumer;

public class ClassUtil {

	public static List<String> findBasePackages(ApplicationContext context) {
		final List<String> result = new ArrayList<>();

		final Map<String, Object> beansWithAnnotation = context.getBeansWithAnnotation(SpringBootApplication.class);
		final String basePackage = beansWithAnnotation.values().stream()
			.map(o -> o.getClass().getPackageName())
			.findFirst()
			.orElseThrow();

		result.add(basePackage);

		return result;
	}

	public static void scanPackagesForAnnotatedClasses(Class<? extends Annotation> annotationClass, List<String> basePackages, Consumer<BeanDefinition> consumer) {
		final ClassPathScanningCandidateComponentProvider provider = new ClassPathScanningCandidateComponentProvider(false);
		provider.addIncludeFilter(new AnnotationTypeFilter(annotationClass));

		final Set<String> seenBeans = new HashSet<>();

		for (String basePackage : basePackages) {
			for (BeanDefinition beanDefinition : provider.findCandidateComponents(basePackage)) {
				final String beanClassName = beanDefinition.getBeanClassName();
				if (!seenBeans.contains(beanClassName)) {
					consumer.accept(beanDefinition);
					seenBeans.add(beanClassName);
				}
			}
		}
	}
}
