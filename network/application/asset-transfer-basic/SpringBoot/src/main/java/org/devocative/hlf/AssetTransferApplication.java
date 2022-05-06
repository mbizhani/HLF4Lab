package org.devocative.hlf;

import org.devocative.thallo.fabric.gateway.EnableFabricGateway;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@EnableFabricGateway
@SpringBootApplication
public class AssetTransferApplication {
	public static void main(String[] args) {
		SpringApplication.run(AssetTransferApplication.class, args);
	}
}
