package br.com.demo.resourceserver.security;

import java.util.*;
import java.util.stream.Collectors;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

public class KeycloakAuthoritiesConverter implements Converter<Jwt, Collection<GrantedAuthority>> {

  @Override
  public Collection<GrantedAuthority> convert(Jwt jwt) {
    Set<String> authorities = new HashSet<>();

    Object scp = jwt.getClaims().get("scp");
    if (scp instanceof Collection<?> col) {
      col.stream().map(Object::toString).forEach(s -> authorities.add("SCOPE_" + s));
    }

    Object scope = jwt.getClaims().get("scope");
    if (scope instanceof String s && !s.isBlank()) {
      Arrays.stream(s.split("\\s+")).forEach(v -> authorities.add("SCOPE_" + v));
    }

    Map<String, Object> realmAccess = jwt.getClaim("realm_access");
    if (realmAccess != null) {
      Object roles = realmAccess.get("roles");
      if (roles instanceof Collection<?> col) {
        col.stream().map(Object::toString).forEach(r -> authorities.add("ROLE_" + normalize(r)));
      }
    }

    Map<String, Object> resourceAccess = jwt.getClaim("resource_access");
    if (resourceAccess != null) {
      for (Object v : resourceAccess.values()) {
        if (v instanceof Map<?, ?> m) {
          Object rs = m.get("roles");
          if (rs instanceof Collection<?> col) {
            col.stream()
                .map(Object::toString)
                .forEach(r -> authorities.add("ROLE_" + normalize(r)));
          }
        }
      }
    }

    return authorities.stream()
        .map(a -> (GrantedAuthority) () -> a)
        .collect(Collectors.toUnmodifiableSet());
  }

  private String normalize(String role) {
    return role.trim().replace('-', '_').toUpperCase(Locale.ROOT);
  }
}
