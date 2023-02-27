FROM openjdk:11.0.15-jdk-slim-bullseye

COPY target/*.jar /app/chaincode.jar

ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/urandom", "-jar", "/app/chaincode.jar"]