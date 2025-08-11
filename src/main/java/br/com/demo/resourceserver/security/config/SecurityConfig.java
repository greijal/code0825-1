package br.com.demo.resourceserver.security.config;

import br.com.demo.resourceserver.security.KeycloakAuthoritiesConverter;
import java.time.Duration;
import java.util.Arrays;
import java.util.Collection;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.annotation.web.configurers.HeadersConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.web.BearerTokenAuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    private static final String[] ACTUATOR_HEALTH_PATHS = {"/api/actuator/health", "/api/actuator/health/**"};
    private static final String[] CORS_ALLOWED_METHODS = {"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"};
    private static final String[] CORS_ALLOWED_HEADERS = {"Authorization", "Content-Type", "Accept", "Origin", "X-Requested-With"};
    private static final String CSP_POLICY = "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none';";
    private static final long HSTS_MAX_AGE_SECONDS = Duration.ofDays(180).toSeconds();

    private final List<String> corsAllowedOrigins;
    private final boolean requireSsl;

    public SecurityConfig(
            @Value("${app.security.cors.allowed-origins:}") List<String> corsAllowedOrigins,
            @Value("${app.security.require-ssl:false}") boolean requireSsl
    ) {
        this.corsAllowedOrigins = corsAllowedOrigins;
        this.requireSsl = requireSsl;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http,
                                                   Converter<Jwt, Collection<GrantedAuthority>> authoritiesConverter) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable) // API stateless
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .headers(headers -> headers
                        .xssProtection(HeadersConfigurer.XXssConfig::disable) // deprecated; mantido por compatibilidade; CSP já cobre XSS
                        .contentSecurityPolicy(csp -> csp.policyDirectives(CSP_POLICY))
                        .referrerPolicy(rp -> rp.policy(org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER))
                        .frameOptions(HeadersConfigurer.FrameOptionsConfig::deny)
                        .httpStrictTransportSecurity(hsts -> {
                            if (requireSsl) {
                                hsts.includeSubDomains(true).preload(true).maxAgeInSeconds(HSTS_MAX_AGE_SECONDS);
                            }
                        })
                        .contentTypeOptions(cto -> {
                        })
                )
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(ACTUATOR_HEALTH_PATHS).permitAll()
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/api/**").authenticated()
                        .anyRequest().denyAll()
                )
                .requiresChannel(channel -> {
                    if (requireSsl) {
                        channel.anyRequest().requiresSecure();
                    }
                })
                .oauth2ResourceServer(oauth2 -> oauth2
                        .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter(authoritiesConverter)))
                        .authenticationEntryPoint(new BearerTokenAuthenticationEntryPoint())
                )
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable);

        return http.build();
    }

    @Bean
    public Converter<Jwt, Collection<GrantedAuthority>> keycloakAuthoritiesConverter() {
        return new KeycloakAuthoritiesConverter();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter(Converter<Jwt, Collection<GrantedAuthority>> authoritiesConverter) {
        var converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authoritiesConverter);
        return converter;
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration cfg = new CorsConfiguration();
        if (corsAllowedOrigins != null && !corsAllowedOrigins.isEmpty()) {
            cfg.setAllowedOrigins(corsAllowedOrigins);
        }
        // Restrito para uso típico de API; ajustar via configuração se necessário
        cfg.setAllowedMethods(Arrays.asList(CORS_ALLOWED_METHODS));
        cfg.setAllowedHeaders(Arrays.asList(CORS_ALLOWED_HEADERS));
        cfg.setExposedHeaders(List.of());
        cfg.setAllowCredentials(false);
        cfg.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", cfg);
        return source;
    }
}
