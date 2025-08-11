package br.com.demo.resourceserver.controllers;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;
@RestController
public class HealthController {
  @GetMapping({"/api/healthz","/healthz"})
  public Map<String,String> health(){ return Map.of("status","ok"); }
  @GetMapping("/public/ping")
  public Map<String,String> ping(){ return Map.of("pong","ok"); }
}
