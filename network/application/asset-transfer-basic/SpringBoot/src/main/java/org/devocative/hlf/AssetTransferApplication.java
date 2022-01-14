package org.devocative.hlf;

import org.devocative.thallo.hlf.EnableHlfClients;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@EnableHlfClients
@SpringBootApplication
public class AssetTransferApplication {
	public static void main(String[] args) {
		SpringApplication.run(AssetTransferApplication.class, args);
	}
}
