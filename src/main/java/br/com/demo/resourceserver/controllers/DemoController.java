package br.com.demo.resourceserver.controllers;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.List;
import java.util.Map;
@RestController
public class DemoController {
  @GetMapping("/api/hello")
  public Map<String,Object> hello(Authentication auth){
    List<String> roles = auth.getAuthorities().stream().map(GrantedAuthority::getAuthority).toList();
    return Map.of("message","hello, bearer","principal", auth.getName(), "roles", roles);
  }
  @GetMapping("/admin/secret")
  public Map<String,Object> admin(Authentication auth){
    return Map.of("secret","area 51","user",auth.getName());
  }
}
