package br.com.demo.resourceserver;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
public class HealthController {
  @GetMapping("/api/healthz")
  public Map<String,Object> health() {
    return Map.of("status","ok");
  }
}