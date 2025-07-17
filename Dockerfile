# Stage 1: Clone the Git repo
FROM alpine/git AS clone
LABEL maintainer="sreekanth <sreekanthk110@gmail.com>"

WORKDIR /app
RUN git clone https://github.com/sreekanth45k/etoe.git

# Stage 2: Build the Maven project
FROM maven:3.5-jdk-8-alpine AS build

WORKDIR /app
COPY --from=clone /app/etoe /app
RUN mvn clean package

# Stage 3: Deploy to Tomcat
FROM tomcat:7-jre7

# Optional: Configure Tomcat users
COPY tomcat-users.xml /usr/local/tomcat/conf/

# Deploy the WAR file to Tomcat
COPY --from=build /app/target/Ecomm.war /usr/local/tomcat/webapps/
