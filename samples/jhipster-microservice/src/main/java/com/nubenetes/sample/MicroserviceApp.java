package com.nubenetes.sample;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.Map;

/**
 * Clean JHipster Microservice Entry Point.
 * Notice: This repository contains NO Jenkinsfile or CI/CD infrastructure scripts.
 * CI/CD is centrally provisioned and injected by Jenkins Seed Job (Pattern B).
 */
@SpringBootApplication
@RestController
public class MicroserviceApp {

    private static final Logger log = LoggerFactory.getLogger(MicroserviceApp.class);

    public static void main(String[] args) {
        SpringApplication app = new SpringApplication(MicroserviceApp.class);
        Environment env = app.run(args).getEnvironment();
        logApplicationStartup(env);
    }

    @GetMapping("/api/v1/info")
    public Map<String, String> getServiceInfo() {
        return Map.of(
            "service", "sample-jhipster-microservice",
            "architecture", "Pattern B (Centralized Seed Job Injection)",
            "status", "UP"
        );
    }

    private static void logApplicationStartup(Environment env) {
        String protocol = "http";
        String serverPort = env.getProperty("server.port", "8080");
        String contextPath = env.getProperty("server.servlet.context-path", "/");
        String hostAddress = "localhost";
        try {
            hostAddress = InetAddress.getLocalHost().getHostAddress();
        } catch (UnknownHostException e) {
            log.warn("The host name could not be determined, using `localhost` as fallback");
        }
        log.info(
            "\n----------------------------------------------------------\n\t" +
            "Application '{}' is running!\n\t" +
            "Access URLs:\n\t" +
            "Local: \t\t{}://localhost:{}{}\n\t" +
            "External: \t{}://{}:{}{}\n\t" +
            "Profile(s): \t{}\n----------------------------------------------------------",
            env.getProperty("spring.application.name", "jhipster-microservice"),
            protocol,
            serverPort,
            contextPath,
            protocol,
            hostAddress,
            serverPort,
            contextPath,
            env.getActiveProfiles().length == 0 ? "default" : env.getActiveProfiles()
        );
    }
}
