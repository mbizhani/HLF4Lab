package org.devocative.hlf.chaincode.config.shim;

import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.filter.AnnotationTypeFilter;

import java.lang.annotation.Annotation;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

public class ClassUtil {

	public static List<String> findBasePackages(ApplicationContext context) {
		final Map<String, Object> beansWithAnnotation = context.getBeansWithAnnotation(SpringBootApplication.class);
		final String basePackage = beansWithAnnotation.values().stream()
			.map(o -> o.getClass().getPackageName())
			.findFirst()
			.orElseThrow();
		return List.of(basePackage);
	}

	public static void scanPackagesForAnnotatedClasses(Class<? extends Annotation> annotationClass, List<String> basePackages, Consumer<BeanDefinition> consumer) {
		final ClassPathScanningCandidateComponentProvider provider = new ClassPathScanningCandidateComponentProvider(false);
		provider.addIncludeFilter(new AnnotationTypeFilter(annotationClass));

		for (String basePackage : basePackages) {
			for (BeanDefinition beanDefinition : provider.findCandidateComponents(basePackage)) {
				consumer.accept(beanDefinition);
			}
		}
	}
}
