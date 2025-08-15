package br.com.gatewey.security.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SecurityController {

  private final JwtDecoder jwtDecoder;

  public SecurityController(final JwtDecoder jwtDecoder) {
    this.jwtDecoder = jwtDecoder;
  }

  @GetMapping("/echo")
  public ResponseEntity me(@RequestHeader("Authorization") final String authHeader) {
    var jwt = jwtDecoder.decode(authHeader.replace("Bearer", "").trim());
    return ResponseEntity.ok().body(jwt);
  }
}
