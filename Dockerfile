FROM maven:3.9.3-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests
FROM tomcat:9.0
COPY --from=build /app/target/*.war /usr/local/tomcat/webapps/
