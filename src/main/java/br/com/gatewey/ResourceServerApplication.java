package br.com.gatewey;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;

@SpringBootApplication
@EnableWebMvc
public class ResourceServerApplication {
  public static void main(final String[] args) {
    SpringApplication.run(ResourceServerApplication.class, args);
  }
}
