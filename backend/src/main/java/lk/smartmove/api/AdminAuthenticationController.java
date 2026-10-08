package lk.smartmove.api;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.security.MessageDigest;
import java.sql.CallableStatement;
import java.sql.Types;
import java.util.Base64;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AdminAuthenticationController {
    private static final int MAXIMUM_ITERATIONS = 1_000_000;

    private final JdbcTemplate jdbc;
    private final AdminSessionRegistry sessions;

    public AdminAuthenticationController(JdbcTemplate jdbc, AdminSessionRegistry sessions) {
        this.jdbc = jdbc;
        this.sessions = sessions;
    }

    @PostMapping("/login")
    public Map<String, Object> login(@RequestBody Map<String, Object> credentials) {
        Object emailValue = credentials.get("email");
        Object passwordValue = credentials.get("password");
        if (emailValue == null || passwordValue == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Email and password are required.");
        }

        String email = emailValue.toString().trim();
        String password = passwordValue.toString();
        if (email.isEmpty() || email.length() > 254 || password.isEmpty() || password.length() > 1024) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter a valid email and password.");
        }

        String storedHash = jdbc.execute((ConnectionCallback<String>) connection -> {
            try (CallableStatement statement =
                         connection.prepareCall("{call smartmove_api.admin_password_hash(?, ?)}")) {
                statement.setString(1, email);
                statement.registerOutParameter(2, Types.VARCHAR);
                statement.execute();
                return statement.getString(2);
            }
        });
        if (!verifyPassword(password, storedHash)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid administrator email or password.");
        }

        String token = sessions.create(email);
        return Map.of("token", token, "email", email);
    }

    @PostMapping("/logout")
    public void logout(@RequestHeader(value = "Authorization", required = false) String authorization) {
        sessions.revoke(bearerToken(authorization));
    }

    private static String bearerToken(String authorization) {
        if (authorization == null || !authorization.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return null;
        }
        return authorization.substring(7).trim();
    }

    private static boolean verifyPassword(String password, String encodedHash) {
        if (encodedHash == null) {
            return false;
        }
        String[] parts = encodedHash.split("\\$", -1);
        if (parts.length != 4 || !"pbkdf2_sha256".equals(parts[0])) {
            return false;
        }
        try {
            int iterations = Integer.parseInt(parts[1]);
            if (iterations < 100_000 || iterations > MAXIMUM_ITERATIONS) {
                return false;
            }
            byte[] salt = Base64.getDecoder().decode(parts[2]);
            byte[] expectedHash = Base64.getDecoder().decode(parts[3]);
            if (salt.length < 16 || expectedHash.length != 32) {
                return false;
            }
            PBEKeySpec specification = new PBEKeySpec(
                    password.toCharArray(), salt, iterations, expectedHash.length * Byte.SIZE);
            try {
                byte[] actualHash = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
                        .generateSecret(specification)
                        .getEncoded();
                return MessageDigest.isEqual(expectedHash, actualHash);
            } finally {
                specification.clearPassword();
            }
        } catch (IllegalArgumentException exception) {
            return false;
        } catch (java.security.GeneralSecurityException exception) {
            throw new IllegalStateException("Password verification is unavailable.", exception);
        }
    }
}
