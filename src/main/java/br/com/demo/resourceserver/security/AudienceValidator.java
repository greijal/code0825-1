package br.com.demo.resourceserver.security;

import java.util.List;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;

class AudienceValidator implements OAuth2TokenValidator<Jwt> {
  private final String expected;

  AudienceValidator(String expected) {
    this.expected = expected;
  }

  @Override
  public OAuth2TokenValidatorResult validate(Jwt jwt) {
    List<String> aud = jwt.getAudience();
    if (aud != null && aud.contains(expected)) {
      return OAuth2TokenValidatorResult.success();
    }
    return OAuth2TokenValidatorResult.failure(
        new OAuth2Error("invalid_token", "audience inválida; esperado: " + expected, null));
  }
}
