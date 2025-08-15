package br.com.gatewey.security.config;

import java.util.List;
import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.http.HttpMethod;

@Data
@ConfigurationProperties(prefix = "app.security")
public class SecurityRulesProperties {

  private List<Rule> rules;

  @Data
  public static class Rule {
    private String pattern;
    private List<HttpMethod> methods;
    private String decision;
    private List<String> roles = List.of();
    private List<String> authorities = List.of();
  }


}
