FROM eclipse-temurin:21-jre-alpine
WORKDIR /
COPY target/app.jar /app.jar
EXPOSE 8443
ENTRYPOINT ["java","-jar","/app.jar"]