package lk.smartmove.api;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.http.converter.json.Jackson2ObjectMapperBuilder;
import org.springframework.web.filter.OncePerRequestFilter;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;
import java.util.regex.Pattern;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
public class ApiKeyAuthenticationFilter extends OncePerRequestFilter {
    private static final int MINIMUM_KEY_LENGTH = 32;
    private static final Pattern LOCAL_ORIGIN =
            Pattern.compile("^https?://(localhost|127\\.0\\.0\\.1)(:\\d+)?$");
    private final String configuredKey;
    private final ObjectMapper objectMapper;
    private final AdminSessionRegistry sessions;

    public ApiKeyAuthenticationFilter(
            @Value("${smartmove.security.api-key:}") String configuredKey,
            Jackson2ObjectMapperBuilder objectMapperBuilder,
            AdminSessionRegistry sessions) {
        this.configuredKey = configuredKey;
        this.objectMapper = objectMapperBuilder.build();
        this.sessions = sessions;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !request.getRequestURI().startsWith("/api/")
                || "OPTIONS".equalsIgnoreCase(request.getMethod());
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        addLocalCorsHeaders(request, response);
        if (configuredKey.length() < MINIMUM_KEY_LENGTH) {
            writeError(response, HttpServletResponse.SC_SERVICE_UNAVAILABLE,
                    "API access is not configured. Set a random API key of at least 32 characters.");
            return;
        }

        String suppliedKey = request.getHeader("X-SmartMove-API-Key");
        if (suppliedKey == null || !MessageDigest.isEqual(
                configuredKey.getBytes(StandardCharsets.UTF_8),
                suppliedKey.getBytes(StandardCharsets.UTF_8))) {
            writeError(response, HttpServletResponse.SC_UNAUTHORIZED,
                    "A valid SmartMove API key is required.");
            return;
        }

        boolean adminLogin = "POST".equalsIgnoreCase(request.getMethod())
                && "/api/auth/login".equals(request.getRequestURI());
        if (!adminLogin && !sessions.isValid(bearerToken(request.getHeader("Authorization")))) {
            writeError(response, HttpServletResponse.SC_UNAUTHORIZED,
                    "Administrator sign-in is required or has expired.");
            return;
        }

        filterChain.doFilter(request, response);
    }

    private static void addLocalCorsHeaders(HttpServletRequest request, HttpServletResponse response) {
        String origin = request.getHeader("Origin");
        if (origin != null && LOCAL_ORIGIN.matcher(origin).matches()) {
            response.setHeader("Access-Control-Allow-Origin", origin);
            response.setHeader("Vary", "Origin");
            response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS");
            response.setHeader("Access-Control-Allow-Headers",
                    "Content-Type, X-SmartMove-API-Key, Authorization");
        }
    }

    private static String bearerToken(String authorization) {
        if (authorization == null || !authorization.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return null;
        }
        return authorization.substring(7).trim();
    }

    private void writeError(HttpServletResponse response, int status, String message)
            throws IOException {
        response.setStatus(status);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setContentType("application/json");
        response.getWriter().write(objectMapper.writeValueAsString(Map.of("error", message)));
    }
}
