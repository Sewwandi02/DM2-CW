package lk.smartmove.api;

import org.springframework.stereotype.Component;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class AdminSessionRegistry {
    private static final long SESSION_LIFETIME_SECONDS = 8 * 60 * 60;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private final ConcurrentHashMap<String, AdminSession> sessions = new ConcurrentHashMap<>();

    public String create(String email) {
        byte[] tokenBytes = new byte[32];
        SECURE_RANDOM.nextBytes(tokenBytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(tokenBytes);
        sessions.put(token, new AdminSession(email, Instant.now().plusSeconds(SESSION_LIFETIME_SECONDS)));
        return token;
    }

    public boolean isValid(String token) {
        if (token == null || token.isBlank()) {
            return false;
        }
        AdminSession session = sessions.get(token);
        if (session == null) {
            return false;
        }
        if (Instant.now().isAfter(session.expiresAt())) {
            sessions.remove(token, session);
            return false;
        }
        return true;
    }

    public void revoke(String token) {
        if (token != null) {
            sessions.remove(token);
        }
    }

    private record AdminSession(String email, Instant expiresAt) {}
}
