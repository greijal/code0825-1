package br.com.gatewey.security.config;

import java.util.Collection;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.annotation.web.configurers.AuthorizeHttpRequestsConfigurer;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.web.BearerTokenAuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;


@Configuration
@EnableMethodSecurity
@ConfigurationPropertiesScan
@EnableWebFluxSecurity
public class SecurityConfig {

  private final SecurityRulesProperties rulesProps;

  public SecurityConfig(final SecurityRulesProperties rulesProps) {
    this.rulesProps = rulesProps;
  }

  @Bean
  public SecurityFilterChain securityFilterChain(
      final HttpSecurity http,
      final Converter<Jwt, Collection<GrantedAuthority>> authoritiesConverter) throws Exception {

    http.sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .httpBasic(AbstractHttpConfigurer::disable)
        .formLogin(AbstractHttpConfigurer::disable)
        .logout(AbstractHttpConfigurer::disable)
        .requiresChannel(channel -> channel.anyRequest().requiresSecure());

    http.oauth2ResourceServer(
        oauth2 ->
            oauth2.jwt(jwt -> jwt.jwtAuthenticationConverter(
                    jwtAuthenticationConverter(authoritiesConverter)))
                .authenticationEntryPoint(new BearerTokenAuthenticationEntryPoint()));

    for (SecurityRulesProperties.Rule rule : rulesProps.getRules()) {
      http.authorizeHttpRequests(reg -> {
        var registry = (rule.getMethods() == null || rule.getMethods().isEmpty())
            ? List.of(reg.requestMatchers(rule.getPattern()))
            : rule.getMethods().stream()
            .map(method -> reg.requestMatchers(method, rule.getPattern()))
            .toList();

        String decision = rule.getDecision() == null ? "" : rule.getDecision().trim().toUpperCase();
        switch (decision) {
          case "PERMIT_ALL" ->
              registry.forEach(AuthorizeHttpRequestsConfigurer.AuthorizedUrl::permitAll);
          case "AUTHENTICATED" ->
              registry.forEach(AuthorizeHttpRequestsConfigurer.AuthorizedUrl::authenticated);
          case "HAS_ANY_ROLE" ->
              registry.forEach(r -> r.hasAnyRole(rule.getAuthorities().toArray(String[]::new)));
          case "HAS_ANY_AUTHORITY" -> registry.forEach(
              r -> r.hasAnyAuthority(rule.getAuthorities().toArray(String[]::new)));
          case "DENY_ALL" ->
              registry.forEach(AuthorizeHttpRequestsConfigurer.AuthorizedUrl::denyAll);
          default -> registry.forEach(AuthorizeHttpRequestsConfigurer.AuthorizedUrl::denyAll);
        }
      });
    }

    return http.build();
  }

  @Bean
  public Converter<Jwt, Collection<GrantedAuthority>> keycloakAuthoritiesConverter() {
    return new KeycloakAuthoritiesConverter();
  }

  @Bean
  public JwtAuthenticationConverter jwtAuthenticationConverter(
      final Converter<Jwt, Collection<GrantedAuthority>> authoritiesConverter) {

    var converter = new JwtAuthenticationConverter();
    converter.setJwtGrantedAuthoritiesConverter(authoritiesConverter);
    return converter;
  }
}
