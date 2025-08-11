package br.com.demo.resourceserver;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
public class DemoController {
  @GetMapping("/api/hello")
  public Map<String,Object> hello() {
    return Map.of("message","hello, bearer");
  }
}