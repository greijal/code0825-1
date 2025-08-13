package br.com.demo.resourceserver.security.config;

import java.time.Duration;
import java.util.Collection;
import java.util.List;
import java.util.Set;
import java.util.function.Predicate;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimNames;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

@Configuration
public class JwtConfig {

  private final List<String> expectedAudiences;
  private final Long duration;
  private final String expectedIssuer;
  private final String jwkSetUri;
  private final List<String> signatures;

  public JwtConfig(
      @Value("${app.security.jwt.expected-audience}") final List<String> expectedAudiences,
      @Value("${app.security.jwt.duration}") final Long duration,
      @Value("${app.security.jwt.expected-issuer}") final String expectedIssuer,
      @Value("${spring.security.oauth2.resourceserver.jwt.jwk-set-uri}") final String jwkSetUri,
      @Value("${app.security.jwt.signature-alg.list}") final List<String> signatures
  ) {
    this.expectedAudiences = expectedAudiences;
    this.duration = duration;
    this.expectedIssuer = expectedIssuer;
    this.jwkSetUri = jwkSetUri;
    this.signatures = signatures;
  }

  @Bean
  public JwtDecoder jwtDecoder() {
    NimbusJwtDecoder decoder = buildJwtDecoder();
    decoder.setJwtValidator(buildJwtValidatorChain());
    return decoder;
  }

  private NimbusJwtDecoder buildJwtDecoder() {
    var builder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri);
    signatures.stream().map(SignatureAlgorithm::from).forEach(builder::jwsAlgorithm);
    return builder.build();
  }

  private OAuth2TokenValidator<Jwt> buildJwtValidatorChain() {
    OAuth2TokenValidator<Jwt> issuerValidator =
        JwtValidators.createDefaultWithIssuer(expectedIssuer);
    OAuth2TokenValidator<Jwt> timestampValidator =
        new JwtTimestampValidator(Duration.ofSeconds(duration));
    OAuth2TokenValidator<Jwt> audienceValidator = new AudienceValidator(expectedAudiences);

    return new DelegatingOAuth2TokenValidator<>(issuerValidator, timestampValidator,
        audienceValidator);
  }


  private static final class AudienceValidator implements OAuth2TokenValidator<Jwt> {
    private final Set<String> expectedAudienceNormalized;
    private final JwtClaimValidator<Collection<String>> validator;

    private AudienceValidator(final Collection<String> allowedTypes) {
      this.expectedAudienceNormalized = allowedTypes.stream()
          .filter(s -> s != null && !s.isBlank())
          .map(String::toLowerCase)
          .collect(Collectors.toUnmodifiableSet());
      Predicate<Collection<String>> audiencePredicate = aud -> aud != null && !aud.isEmpty() &&
          aud.stream().anyMatch(expectedAudienceNormalized::contains);
      this.validator = new JwtClaimValidator<>(JwtClaimNames.AUD, audiencePredicate);

    }

    @Override
    public OAuth2TokenValidatorResult validate(final Jwt jwt) {
      return validator.validate(jwt);
    }
  }


}