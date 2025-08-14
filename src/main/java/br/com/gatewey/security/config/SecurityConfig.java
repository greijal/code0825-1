package br.com.gatewey.security.config;

import java.util.Arrays;
import java.util.Collection;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.web.BearerTokenAuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;


@Configuration
@EnableMethodSecurity
public class SecurityConfig {

  private final List<PublicPath> publicPaths;

  public SecurityConfig(final List<PublicPath> publicPaths) {
    this.publicPaths = publicPaths;
  }

  private static void addPrivateRequestRule(final HttpSecurity http) throws Exception {
    http.authorizeHttpRequests(
        auth ->
            auth.requestMatchers("/api/**")
                .authenticated()
                .anyRequest()
                .denyAll());
  }

  private static void addPublicRequestRule(final List<PublicPath> publicPaths,
                                           final HttpSecurity http) throws Exception {

    http.authorizeHttpRequests(auth -> auth.requestMatchers(HttpMethod.OPTIONS, "/**")
        .permitAll());

    publicPaths.forEach(p -> {
      Arrays.stream(p.methods).forEach(m -> {
        try {
          http.authorizeHttpRequests(auth -> auth.requestMatchers(m, p.path));
        } catch (Exception e) {
          throw new RuntimeException(e);
        }
      });
    });

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

    addPublicRequestRule(publicPaths, http);
    addPrivateRequestRule(http);

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

  @ConfigurationPropertiesScan("app.security.public")
  public record PublicPath(String path, HttpMethod[] methods) {
  }
}
