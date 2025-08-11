package br.com.demo.resourceserver.security.config;

import java.time.Duration;
import java.util.Collection;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;

import br.com.demo.resourceserver.security.AudienceValidator;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

@Configuration
public class JwtConfig {

    private static final Duration DEFAULT_CLOCK_SKEW = Duration.ofSeconds(60);

    private final String expectedAudience;
    private final String expectedIssuer;
    private final String jwkSetUri;
    private final Set<String> allowedTypes;
    private final String signatureAlg;

    public JwtConfig(
            @Value("${app.security.expected-audience:resource-api}") String expectedAudience,
            @Value("${app.security.expected-issuer}") String expectedIssuer,
            @Value("${spring.security.oauth2.resourceserver.jwt.jwk-set-uri}") String jwkSetUri,
            @Value("${app.security.jwt.allowed-typ:at+jwt,Bearer,JWT}") Set<String> allowedTypes,
            @Value("${app.security.jwt.signature-alg:RS256}") String signatureAlg
    ) {
        this.expectedAudience = expectedAudience;
        this.expectedIssuer = expectedIssuer;
        this.jwkSetUri = jwkSetUri;
        this.allowedTypes = allowedTypes;
        this.signatureAlg = signatureAlg;
    }

    @Bean
    JwtDecoder jwtDecoder() {
        NimbusJwtDecoder decoder = buildJwtDecoder();
        decoder.setJwtValidator(buildJwtValidatorChain());
        return decoder;
    }

    private NimbusJwtDecoder buildJwtDecoder() {
        return NimbusJwtDecoder.withJwkSetUri(jwkSetUri)
                .jwsAlgorithm(SignatureAlgorithm.from(signatureAlg))
                .build();
    }

    private OAuth2TokenValidator<Jwt> buildJwtValidatorChain() {
        OAuth2TokenValidator<Jwt> issuerValidator = JwtValidators.createDefaultWithIssuer(expectedIssuer);
        OAuth2TokenValidator<Jwt> timestampValidator = new JwtTimestampValidator(DEFAULT_CLOCK_SKEW);
        OAuth2TokenValidator<Jwt> audienceValidator = new AudienceValidator(expectedAudience);
        OAuth2TokenValidator<Jwt> typHeaderValidator = new TypHeaderValidator(allowedTypes);

        return new DelegatingOAuth2TokenValidator<>(issuerValidator, timestampValidator, audienceValidator, typHeaderValidator);
    }

    private static final class TypHeaderValidator implements OAuth2TokenValidator<Jwt> {
        private final Set<String> allowedTypesNormalized;

        TypHeaderValidator(Collection<String> allowedTypes) {
            this.allowedTypesNormalized = allowedTypes.stream()
                    .filter(s -> s != null && !s.isBlank())
                    .map(s -> s.toLowerCase(Locale.ROOT))
                    .collect(Collectors.toUnmodifiableSet());
        }

        @Override
        public OAuth2TokenValidatorResult validate(Jwt token) {
            Object typObj = token.getHeaders().get("typ");

      // Alguns provedores omitem "typ"; aceitar se as demais validações passarem
      if (typObj == null) {
                return OAuth2TokenValidatorResult.success();
            }

            String typ = String.valueOf(typObj).toLowerCase(Locale.ROOT);
            if (allowedTypesNormalized.contains(typ)) {
                return OAuth2TokenValidatorResult.success();
            }

            return OAuth2TokenValidatorResult.failure(
                    new OAuth2Error("invalid_token", "Invalid JWT typ: " + typObj, null)
            );
        }
    }
}