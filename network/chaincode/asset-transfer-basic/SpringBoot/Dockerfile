FROM openjdk:11.0.15-jdk-slim-bullseye

ENV JAVA_OPTS=""

COPY target/*.jar /app/chaincode.jar

ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -Djava.security.egd=file:/dev/urandom -jar /app/chaincode.jar"]