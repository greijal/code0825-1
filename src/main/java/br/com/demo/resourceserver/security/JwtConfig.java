package br.com.demo.resourceserver.security;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtDecoders;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
@Configuration
public class JwtConfig {
  @Value("${app.security.expected-audience:resource-api}")
  String expectedAudience;
  @Value("${spring.security.oauth2.resourceserver.jwt.issuer-uri}")
  String issuer;
  @Bean
  JwtDecoder jwtDecoder(){
    NimbusJwtDecoder decoder = (NimbusJwtDecoder) JwtDecoders.fromIssuerLocation(issuer);
    OAuth2TokenValidator<Jwt> withIssuer = JwtValidators.createDefaultWithIssuer(issuer);
    OAuth2TokenValidator<Jwt> withTs = new JwtTimestampValidator(java.time.Duration.ofSeconds(60));
    OAuth2TokenValidator<Jwt> withAud = new AudienceValidator(expectedAudience);
    decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(withIssuer, withTs, withAud));
    return decoder;
  }
}
