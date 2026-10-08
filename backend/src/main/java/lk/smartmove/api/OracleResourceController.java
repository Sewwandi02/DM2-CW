package lk.smartmove.api;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Clob;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.security.SecureRandom;
import java.io.StringReader;
import java.util.Base64;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@RestController
@RequestMapping("/api")
public class OracleResourceController {
    private record Resource(String table, String id, List<String> fields, Set<String> timestamps,
                            Set<String> dates, Set<String> numbers) {}

    private static final Map<String, Resource> RESOURCES = Map.ofEntries(
            Map.entry("roles", resource("Role", "role_id", "role_name")),
            Map.entry("user-roles", resource("User_Role", "user_id", "user_id", "role_id")),
            Map.entry("app-users", resource("App_User", "user_id", "f_name", "l_name", "email", "phone", "password")),
            Map.entry("passengers", resource("Passenger", "user_id", "user_id")),
            Map.entry("drivers", resource("Driver", "user_id", "user_id", "license", "status")),
            Map.entry("admins", resource("Admin", "user_id", "user_id")),
            Map.entry("vehicles", numbers("Vehicle", "vehicle_id", Set.of("capacity", "admin_id"),
                    "reg_no", "vehicle_type", "capacity", "status", "admin_id")),
            Map.entry("routes", numbers("Route", "route_id", Set.of("distance"),
                    "origin", "destination", "distance", "est_du")),
            Map.entry("trips", rich("Trip", "trip_id", Set.of("departure_time", "arrival_time"),
                    Set.of(), Set.of("fare", "route_id", "vehicle_id", "driver_id", "passenger_id"),
                    "departure_time", "arrival_time", "fare", "status", "route_id", "vehicle_id", "driver_id", "passenger_id")),
            Map.entry("bookings", rich("Booking", "booking_id", Set.of("b_date"), Set.of(),
                    Set.of("passenger_id", "trip_id", "tot_am"),
                    "b_date", "seat_no", "tot_am", "status", "passenger_id", "trip_id")),
            Map.entry("payments", rich("Payment", "payment_id", Set.of("pay_date"), Set.of(),
                    Set.of("amount", "booking_id"), "amount", "pay_date", "pay_method", "pay_status", "booking_id")),
            Map.entry("feedback", rich("Feedback", "feedback_id", Set.of("feedback_date"), Set.of(),
                    Set.of("rating", "passenger_id", "trip_id"),
                    "rating", "comments", "feedback_date", "passenger_id", "trip_id")),
            Map.entry("maintenance", rich("Maintenance", "maintenance_id", Set.of(), Set.of("maintenance_date"),
                    Set.of("cost", "vehicle_id"), "maintenance_date", "description", "cost", "status", "vehicle_id"))
    );

    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    public OracleResourceController(JdbcTemplate jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
    }

    @GetMapping("/{name}")
    public List<Map<String, Object>> list(@PathVariable String name) {
        getResource(name);
        return readReportCursor(
                "{call smartmove_api.list_records(?, ?)}",
                2,
                statement -> {
                    statement.setString(1, name.toLowerCase(Locale.ROOT));
                    statement.registerOutParameter(2, Types.REF_CURSOR);
                });
    }

    @PostMapping("/{name}")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> create(@PathVariable String name, @RequestBody Map<String, Object> body) {
        Resource resource = getResource(name);
        if ("Passenger".equals(resource.table()) || "Driver".equals(resource.table())) {
            return createAccountRole(resource, body);
        }
        Map<String, Object> values = cleanValues(resource, body, false);
        if (values.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "At least one editable field is required");
        }
        Number generatedId = jdbc.execute((ConnectionCallback<Number>) connection -> {
            try (CallableStatement statement =
                         connection.prepareCall("{call smartmove_api.create_record(?, ?, ?)}")) {
                statement.setString(1, name.toLowerCase(Locale.ROOT));
                setJsonClob(statement, 2, values);
                statement.registerOutParameter(3, Types.NUMERIC);
                statement.execute();
                return statement.getBigDecimal(3);
            }
        });
        if (generatedId != null) {
            return Map.of("created", true, resource.id(), generatedId.longValue());
        }
        return Map.of("created", true);
    }

    private Map<String, Object> createAccountRole(Resource resource, Map<String, Object> body) {
        boolean driver = "Driver".equals(resource.table());
        String firstName = requiredText(body, "f_name");
        String lastName = requiredText(body, "l_name");
        String email = requiredText(body, "email");
        String password = requiredText(body, "password");
        if (password.length() < 10) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "password must contain at least 10 characters");
        }

        if (driver) requiredText(body, "license");
        Set<String> allowed = driver
                ? Set.of("f_name", "l_name", "email", "phone", "password", "license", "status")
                : Set.of("f_name", "l_name", "email", "phone", "password");
        Set<String> unknown = new HashSet<>(body.keySet());
        unknown.removeAll(allowed);
        if (!unknown.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported fields: " + unknown);
        }

        Map<String, Object> values = new LinkedHashMap<>();
        values.put("f_name", firstName);
        values.put("l_name", lastName);
        values.put("email", email);
        values.put("phone", optionalText(body, "phone"));
        values.put("password", hashPassword(password));
        if (driver) {
            values.put("license", requiredText(body, "license"));
            values.put("status", Optional.ofNullable(optionalText(body, "status")).orElse("Active"));
        }
        Number generatedId = jdbc.execute((ConnectionCallback<Number>) connection -> {
            try (CallableStatement statement =
                         connection.prepareCall("{call smartmove_api.create_passenger_or_driver(?, ?, ?)}")) {
                statement.setInt(1, driver ? 1 : 0);
                setJsonClob(statement, 2, values);
                statement.registerOutParameter(3, Types.NUMERIC);
                statement.execute();
                return statement.getBigDecimal(3);
            }
        });
        if (generatedId == null) {
            throw new IllegalStateException("PL/SQL did not return the generated user ID");
        }
        return Map.of("created", true, "user_id", generatedId.longValue());
    }

    private static String requiredText(Map<String, Object> body, String field) {
        Object value = body.get(field);
        if (value == null || value.toString().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " is required");
        }
        return value.toString().trim();
    }

    private static String optionalText(Map<String, Object> body, String field) {
        Object value = body.get(field);
        if (value == null || value.toString().isBlank()) {
            return null;
        }
        return value.toString().trim();
    }

    @PutMapping("/{name}/{id}")
    public Map<String, Object> update(@PathVariable String name, @PathVariable long id,
                                      @RequestBody Map<String, Object> body) {
        Resource resource = getResource(name);
        if ("User_Role".equals(resource.table())) {
            throw new ResponseStatusException(HttpStatus.METHOD_NOT_ALLOWED,
                    "User-role links are keyed by both user_id and role_id");
        }
        Map<String, Object> values = cleanValues(resource, body, true);
        if (values.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "At least one editable field is required");
        }
        jdbc.execute((ConnectionCallback<Void>) connection -> {
            try (CallableStatement statement =
                         connection.prepareCall("{call smartmove_api.update_record(?, ?, ?)}")) {
                statement.setString(1, name.toLowerCase(Locale.ROOT));
                statement.setLong(2, id);
                setJsonClob(statement, 3, values);
                statement.execute();
            }
            return null;
        });
        return Map.of("updated", true);
    }

    @DeleteMapping("/{name}/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable String name, @PathVariable long id) {
        Resource resource = getResource(name);
        if ("User_Role".equals(resource.table())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Delete a user-role link using /api/user-roles/{userId}/{roleId}");
        }
        callDelete(name, id, null);
    }

    @DeleteMapping("/user-roles/{userId}/{roleId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteUserRole(@PathVariable long userId, @PathVariable long roleId) {
        callDelete("user-roles", userId, roleId);
    }

    private void callDelete(String resource, long id, Long secondaryId) {
        jdbc.execute((ConnectionCallback<Void>) connection -> {
            try (CallableStatement statement =
                         connection.prepareCall("{call smartmove_api.delete_record(?, ?, ?)}")) {
                statement.setString(1, resource.toLowerCase(Locale.ROOT));
                statement.setLong(2, id);
                if (secondaryId == null) {
                    statement.setNull(3, Types.NUMERIC);
                } else {
                    statement.setLong(3, secondaryId);
                }
                statement.execute();
            }
            return null;
        });
    }

    private void setJsonClob(CallableStatement statement, int parameter, Map<String, Object> values)
            throws SQLException {
        Map<String, Object> jsonValues = new LinkedHashMap<>();
        values.forEach((field, value) -> {
            Object encoded = value;
            if (value instanceof Timestamp timestamp) {
                encoded = timestamp.toLocalDateTime()
                        .format(DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss"));
            } else if (value instanceof java.sql.Date date) {
                encoded = date.toLocalDate().toString();
            } else if (value instanceof BigDecimal decimal) {
                encoded = decimal;
            }
            jsonValues.put(field, encoded);
        });
        try {
            String json = objectMapper.writeValueAsString(jsonValues);
            statement.setClob(parameter, new StringReader(json), json.length());
        } catch (JsonProcessingException exception) {
            throw new IllegalArgumentException("Unable to encode Oracle request as JSON", exception);
        }
    }

    @GetMapping("/dashboard")
    public Map<String, Object> dashboard() {
        List<Map<String, Object>> rows = readReportCursor(
                "{call smartmove_api.dashboard(?)}",
                1,
                statement -> statement.registerOutParameter(1, Types.REF_CURSOR));
        if (rows.isEmpty()) throw new IllegalStateException("PL/SQL dashboard returned no result row");
        return rows.getFirst();
    }

    @GetMapping("/reports/frequent-routes")
    public List<Map<String, Object>> frequentRoutes(
            @RequestParam(defaultValue = "10") int limit) {
        if (limit < 1 || limit > 100) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "limit must be between 1 and 100");
        }
        return readReportCursor(
                "{call smartmove_reports.frequent_routes(?)}",
                1,
                statement -> statement.registerOutParameter(1, Types.REF_CURSOR))
                .stream()
                .limit(limit)
                .toList();
    }

    @GetMapping("/reports/revenue")
    public Map<String, Object> revenue(@RequestParam LocalDate from, @RequestParam LocalDate to) {
        if (to.isBefore(from)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "'to' must not be before 'from'");
        }
        BigDecimal total = jdbc.execute((ConnectionCallback<BigDecimal>) connection -> {
            try (CallableStatement statement =
                         connection.prepareCall("{? = call smartmove_reports.total_revenue(?, ?)}")) {
                statement.registerOutParameter(1, Types.NUMERIC);
                statement.setDate(2, java.sql.Date.valueOf(from));
                statement.setDate(3, java.sql.Date.valueOf(to));
                statement.execute();
                BigDecimal value = statement.getBigDecimal(1);
                return value == null ? BigDecimal.ZERO : value;
            }
        });
        List<Map<String, Object>> daily = readReportCursor(
                "{call smartmove_reports.revenue_by_period(?, ?, ?)}",
                3,
                statement -> {
                    statement.setDate(1, java.sql.Date.valueOf(from));
                    statement.setDate(2, java.sql.Date.valueOf(to));
                    statement.registerOutParameter(3, Types.REF_CURSOR);
                });
        return Map.of("from", from, "to", to, "revenue", total, "daily", daily);
    }

    @GetMapping("/reports/passenger-history/{passengerId}")
    public List<Map<String, Object>> passengerHistory(@PathVariable long passengerId) {
        return readReportCursor(
                "{call smartmove_reports.passenger_travel_history(?, ?)}",
                2,
                statement -> {
                    statement.setLong(1, passengerId);
                    statement.registerOutParameter(2, Types.REF_CURSOR);
                });
    }

    @GetMapping("/reports/maintenance-summary")
    public List<Map<String, Object>> maintenanceSummary() {
        return readReportCursor(
                "{call smartmove_reports.maintenance_summary(?)}",
                1,
                statement -> statement.registerOutParameter(1, Types.REF_CURSOR));
    }

    private List<Map<String, Object>> readReportCursor(
            String call, int cursorParameter, ReportCallBinder binder) {
        return jdbc.execute((ConnectionCallback<List<Map<String, Object>>>) connection -> {
            try (CallableStatement statement = connection.prepareCall(call)) {
                binder.bind(statement);
                statement.execute();
                try (ResultSet result = (ResultSet) statement.getObject(cursorParameter)) {
                    List<Map<String, Object>> rows = new ArrayList<>();
                    while (result.next()) {
                        rows.add(row(result));
                    }
                    return rows;
                }
            }
        });
    }

    @FunctionalInterface
    private interface ReportCallBinder {
        void bind(CallableStatement statement) throws SQLException;
    }

    private static Resource resource(String table, String id, String... fields) {
        return new Resource(table, id, List.of(fields), Set.of(), Set.of(), Set.of());
    }

    private static Resource numbers(String table, String id, Set<String> numbers, String... fields) {
        return new Resource(table, id, List.of(fields), Set.of(), Set.of(), numbers);
    }

    private static Resource rich(String table, String id, Set<String> timestamps, Set<String> dates,
                                 Set<String> numbers, String... fields) {
        return new Resource(table, id, List.of(fields), timestamps, dates, numbers);
    }

    private static Resource getResource(String name) {
        Resource resource = RESOURCES.get(name.toLowerCase(Locale.ROOT));
        if (resource == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Unknown Oracle resource");
        }
        return resource;
    }

    private Map<String, Object> cleanValues(Resource resource, Map<String, Object> body, boolean allowId) {
        Map<String, Object> values = new LinkedHashMap<>();
        for (String field : resource.fields()) {
            if (field.equals(resource.id()) && allowId) {
                continue;
            }
            if (body.containsKey(field)) {
                values.put(field, convert(body.get(field), field, resource));
            }
        }
        Set<String> unknown = new HashSet<>(body.keySet());
        unknown.removeAll(resource.fields());
        if (!allowId) {
            unknown.remove(resource.id());
        }
        if (!unknown.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported fields: " + unknown);
        }
        return values;
    }

    private Object convert(Object value, String field, Resource resource) {
        if (value == null || value instanceof Number) {
            return value;
        }
        if (resource.numbers().contains(field)) {
            try {
                return new BigDecimal(value.toString());
            } catch (NumberFormatException exception) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " must be numeric");
            }
        }
        if (resource.timestamps().contains(field)) {
            try {
                String text = value.toString();
                return Timestamp.valueOf(LocalDateTime.parse(text.length() == 16 ? text + ":00" : text));
            } catch (RuntimeException exception) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " must be an ISO date-time");
            }
        }
        if (resource.dates().contains(field)) {
            try {
                return java.sql.Date.valueOf(LocalDate.parse(value.toString()));
            } catch (RuntimeException exception) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " must be an ISO date");
            }
        }
        if ("password".equals(field)) {
            String password = value.toString();
            if (password.length() < 10) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "password must contain at least 10 characters");
            }
            return hashPassword(password);
        }
        return value.toString();
    }

    private static String hashPassword(String password) {
        byte[] salt = new byte[16];
        new SecureRandom().nextBytes(salt);
        PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, 120_000, 256);
        try {
            byte[] hash = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
            return "pbkdf2_sha256$120000$" + Base64.getEncoder().encodeToString(salt)
                    + "$" + Base64.getEncoder().encodeToString(hash);
        } catch (java.security.GeneralSecurityException exception) {
            throw new IllegalStateException("Password hashing is unavailable", exception);
        } finally {
            spec.clearPassword();
        }
    }

    private static Map<String, Object> row(ResultSet rs) throws SQLException {
        Map<String, Object> data = new LinkedHashMap<>();
        for (int i = 1; i <= rs.getMetaData().getColumnCount(); i++) {
            Object value = rs.getObject(i);
            if (value instanceof Clob clob) {
                value = clob.getSubString(1, Math.toIntExact(clob.length()));
            }
            data.put(rs.getMetaData().getColumnLabel(i).toLowerCase(Locale.ROOT), value);
        }
        return data;
    }
}
