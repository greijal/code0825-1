package br.com.demo.resourceserver;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class ApiController {

    @GetMapping("/healthz")
    public Map<String, String> health() {
        return Map.of("status","ok");
    }

    @PostMapping("/echo")
    public ResponseEntity<Map<String,Object>> echo(@RequestBody Map<String,Object> body) {
        return ResponseEntity.ok(Map.of("received", body));
    }
}
