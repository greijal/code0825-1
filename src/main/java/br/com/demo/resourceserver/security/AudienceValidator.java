package br.com.demo.resourceserver.security;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtValidationException;
import org.springframework.util.CollectionUtils;
import java.util.List;
public class AudienceValidator implements OAuth2TokenValidator<Jwt> {
  private final String expectedAud;
  public AudienceValidator(String expectedAud){ this.expectedAud = expectedAud; }
  @Override
  public org.springframework.security.oauth2.core.OAuth2TokenValidatorResult validate(Jwt token) {
    List<String> aud = token.getAudience();
    if(CollectionUtils.isEmpty(aud) || !aud.contains(expectedAud)){
      OAuth2Error err = new OAuth2Error("invalid_token","missing/invalid audience","");
      return org.springframework.security.oauth2.core.OAuth2TokenValidatorResult.failure(err);
    }
    return org.springframework.security.oauth2.core.OAuth2TokenValidatorResult.success();
  }
}
